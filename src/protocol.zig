const std = @import("std");
const fmt = std.fmt;

// Simple string "+PING\r\n"
// Error "-ERR message\r\n"
// Int ":128\r\n"
// Bulk "$<length>\r\n<data>\r\n" with empty "$0\r\n\r\n"
// Array "*<num of elems>\r\n<elem 1>...<elem n>

const MsgType = enum {
    simple,
    err,
    int,
    bulk,
    arr,
};

pub const Msg = union(MsgType) {
    simple: []const u8,
    err: []const u8,
    int: i64,
    bulk: []const u8,
    arr: std.ArrayList(Msg),
};

pub const ProtocolError = error{
    SyntaxError,
    IncorrectNumberOfElements,
};

pub fn parse(buf: []const u8, allocator: std.mem.Allocator) !Msg {
    switch (buf[0]) {
        '+' => {
            const str = try readLine(buf[1..]);
            return Msg{ .simple = stripCRLF(str) };
        },
        '-' => {
            const err = try readLine(buf[1..]);
            return Msg{ .err = stripCRLF(err) };
        },
        ':' => {
            const n_str = try readLine(buf[1..]);
            const n = try fmt.parseInt(i64, stripCRLF(n_str), 10);
            return Msg{ .int = n };
        },
        // *1\r\n$4\r\nPONG\r\n
        '$' => {
            const len_str = try readLine(buf[1..]);
            const len = try fmt.parseInt(usize, stripCRLF(len_str), 10);
            const start_pos = try findDataStart(buf);
            return Msg{ .bulk = buf[start_pos .. start_pos + len] };
        },
        '*' => {
            // IMPT! free this allocated memory in the function calling the parser
            var elems = std.ArrayList(Msg).init(allocator);

            const elem_count_str = try readLine(buf[1..]);
            const elem_count = try fmt.parseInt(usize, stripCRLF(elem_count_str), 10);
            var start_pos = try findDataStart(buf);

            for (0..elem_count) |_| {
                const line = try readLine(buf[start_pos..]);
                try elems.append(try parse(line, allocator));
                start_pos += line.len;
            }

            return Msg{ .arr = elems };
        },
        else => return ProtocolError.SyntaxError,
    }
}

fn readLine(buf: []const u8) ![]const u8 {
    const delim: []const u8 = "\r\n";
    const delim_pos = std.mem.indexOf(u8, buf, delim);

    if (delim_pos) |pos| {
        // include CRLF in returned slice
        return buf[0 .. pos + 2];
    } else {
        return ProtocolError.SyntaxError;
    }
}

fn findDataStart(buf: []const u8) !usize {
    const delim: []const u8 = "\r\n";
    const delim_pos = std.mem.indexOf(u8, buf, delim);

    if (delim_pos) |pos| {
        return pos + 2;
    } else {
        return ProtocolError.SyntaxError;
    }
}

fn stripCRLF(buf: []const u8) []const u8 {
    return std.mem.trimRight(u8, buf, "\r\n");
}

test "simple string" {
    const ping: []const u8 = "+PING\r\n";
    const msg = try parse(ping, test_allocator);

    switch (msg) {
        .simple => |str| try expect(std.mem.eql(u8, str, "PING")),
        else => unreachable,
    }
}

test "error message" {
    const err: []const u8 = "-ERR message\r\n";
    const msg = try parse(err, test_allocator);

    switch (msg) {
        .err => |str| try expect(std.mem.eql(u8, str, "ERR message")),
        else => unreachable,
    }
}

test "integer" {
    const n: []const u8 = ":128\r\n";
    const msg = try parse(n, test_allocator);

    switch (msg) {
        .int => |num| try expect(num == 128),
        else => unreachable,
    }
}

test "bulk string" {
    const bulk: []const u8 = "$20\r\nhello!\r\nhow are you?\r\n";
    const msg = try parse(bulk, test_allocator);

    switch (msg) {
        .bulk => |str| {
            try expect(std.mem.eql(u8, str, "hello!\r\nhow are you?"));
        },
        else => unreachable,
    }
}

test "array message" {
    const arr: []const u8 = "*2\r\n+OK\r\n:10\r\n";
    const msg = try parse(arr, test_allocator);

    switch (msg) {
        .arr => |a| {
            defer a.deinit();
            for (a.items) |item| {
                switch (item) {
                    .simple => |str| try expect(std.mem.eql(u8, str, "OK")),
                    .int => |n| try expect(n == 10),
                    else => unreachable,
                }
            }
        },
        else => unreachable,
    }
}

test "two bulk strings" {
    const arr: []const u8 = "*2\r\n$2\r\nHI\r\n$5\r\nHELLO\r\n";
    const msg = try parse(arr, test_allocator);

    try expect(@as(MsgType, msg) == MsgType.arr);
    try expect(std.mem.eql(u8, msg.arr.items[0].bulk, "HI"));
    try expect(std.mem.eql(u8, msg.arr.items[1].bulk, "HELLO"));
}

const expect = std.testing.expect;
const test_allocator = std.testing.allocator;
