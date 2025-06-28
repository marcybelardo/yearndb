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
};

const Msg = union(MsgType) {
    simple: []const u8,
    err: []const u8,
    int: i64,
    bulk: []const u8,
};

const ProtocolError = error{
    SyntaxError,
};

fn parse(buf: []const u8, elems: *std.ArrayList(Msg)) !void {
    switch (buf[0]) {
        '+' => {
            try elems.append(Msg{ .simple = try readLine(buf[1..]) });
        },
        '-' => {
            try elems.append(Msg{ .err = try readLine(buf[1..]) });
        },
        ':' => {
            const n = try fmt.parseInt(i64, try readLine(buf[1..]), 10);
            try elems.append(Msg{ .int = n });
        },
        '$' => {
            const len = try fmt.parseInt(usize, try readLine(buf[1..]), 10);
            const start_pos = try findDataStart(buf);
            try elems.append(Msg{ .bulk = buf[start_pos..len] });
        },
        '*' => {
            const elem_num = try fmt.parseInt(usize, try readLine(buf[1..]), 10);
            const start_pos = try findDataStart(buf);

            for (0..elem_num) |_| {
                const line = try readLine(buf[start_pos..]);
                try parse(line, elems);
            }
        },
        else => return ProtocolError.SyntaxError,
    }
}

fn readLine(buf: []const u8) ![]const u8 {
    const delim: []const u8 = "\r\n";
    const delim_pos = std.mem.indexOf(u8, buf, delim);

    if (delim_pos) |pos| {
        return buf[0..pos];
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

test "simple string" {
    const ping: []const u8 = "+PING\r\n";
    var elems = std.ArrayList(Msg).init(test_allocator);
    defer elems.deinit();
    try parse(ping, &elems);

    switch (elems.items[0]) {
        .simple => |str| try expect(std.mem.eql(u8, str, "PING")),
        else => unreachable,
    }
}

test "error message" {
    const err: []const u8 = "-ERR message\r\n";
    var elems = std.ArrayList(Msg).init(test_allocator);
    defer elems.deinit();
    try parse(err, &elems);

    switch (elems.items[0]) {
        .err => |str| try expect(std.mem.eql(u8, str, "ERR message")),
        else => unreachable,
    }
}

test "integer" {
    const n: []const u8 = ":128\r\n";
    var elems = std.ArrayList(Msg).init(test_allocator);
    defer elems.deinit();
    try parse(n, &elems);

    switch (elems.items[0]) {
        .int => |num| try expect(num == 128),
        else => unreachable,
    }
}

test "bulk string" {
    const bulk: []const u8 = "$20\r\nhello!\r\nhow are you?\r\n";
    var elems = std.ArrayList(Msg).init(test_allocator);
    defer elems.deinit();
    try parse(bulk, &elems);

    switch (elems.items[0]) {
        .bulk => |str| {
            std.debug.print("[{s}]\nLEN: {}\n", .{str, str.len});
            try expect(std.mem.eql(u8, str, "hello!\r\nhow are you?"));
        },
        else => unreachable,
    }
}

// make an array type again
// test "array message" {
//     const arr: []const u8 = "*2\r\n+OK\r\n:10\r\n";
//     var elems = std.ArrayList(Msg).init(test_allocator);
//     defer elems.deinit();
//     try parse(arr, &elems);
//
// }

const expect = std.testing.expect;
const test_allocator = std.testing.allocator;
