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
    for (buf) |c| {
        switch (c) {
            '+' => {
                step(buf);
                try elems.append(Msg{ .simple = try readLine(buf) });
            },
            '-' => {
                step(buf);
                try elems.append(Msg{ .err = try readLine(buf) });
            },
            ':' => {
                step(buf);
                const n = try fmt.parseInt(i64, try readLine(buf), 10);
                try elems.append(Msg{ .int = n });
            },
            '$' => {
                step(buf);
                const len = try fmt.parseInt(usize, try readLine(buf), 10);
                const crlf_idx = std.mem.indexOf(u8, buf, "\r\n")
                    orelse return ProtocolError.SyntaxError;
                const start_pos = crlf_idx + 2;
                try elems.append(Msg{ .bulk = buf[start_pos..len] });
            },
            '*' => {
                step(buf);
                const elem_num = try fmt.parseInt(usize, try readLine(buf), 10);
                const crlf_idx = std.mem.indexOf(u8, buf, "\r\n")
                    orelse return ProtocolError.SyntaxError;
                const start_pos = crlf_idx + 2;

                for (0..elem_num) |_| {
                    try parse(buf[start_pos..], elems);
                }
            },
            else => return ProtocolError.SyntaxError,
        }
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

fn step(buf: []const u8) void {
    buf += 1;
}

test "simple string" {
    const ping: []const u8 = "+PING\r\n";
    var elems = std.ArrayList(Msg).init(test_allocator);
    const tokens = try parse(ping, &elems);
    try expect(tokens[0], Msg{ .simple = "PING" });
}

const expect = std.testing.expect;
const test_allocator = std.testing.allocator;
