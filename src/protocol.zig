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

const Msg = union(MsgType) {
    simple: []const u8,
    err: []const u8,
    int: i64,
    bulk: []const u8,
    arr: []Msg,
};

const ProtocolError = error{
    SyntaxError,
};

fn parse(buf: []const u8) !Msg {
    for (buf) |c| {
        switch (c) {
            '+' => {
                step(buf);
                return Msg{ .simple = try readLine(buf) };
            },
            '-' => {
                step(buf);
                return Msg{ .err = try readLine(buf) };
            },
            ':' => {
                step(buf);
                return Msg{ .int = fmt.parseInt(i64, try readLine(buf)) };
            },
            '$' => {
                step(buf);
                const len = fmt.parseInt(usize, try readLine(buf));
                const start_pos = std.mem.indexOf(u8, buf, "\r\n") + 2;
                return Msg{ .bulk = buf[start_pos..len] };
            },
            '*' => {
                step(buf);
                const elems = fmt.parseInt(usize, try readLine(buf));
                const start_pos = std.mem.indexOf(u8, buf, "\r\n") + 2;
                var arr: [elems]Msg = undefined;

                for (elems) |e| {
                    arr[e] = parse(buf[start_pos..]);
                }

                return Msg{ .arr = arr };
            },
            else => return ProtocolError.SyntaxError,
        }
    }
}

fn readLine(buf: []const u8) ![]const u8 {
    const delim: []const u8 = "\r\n";
    const delim_pos = try std.mem.indexOf(u8, buf, delim);

    if (delim_pos) |pos| {
        return buf[0..pos];
    } else {
        return ProtocolError.SyntaxError;
    }
}

fn step(buf: []const u8) void {
    buf += 1;
}

test "gets a line" {
    const ping: []const u8 = "PING\r\n";
    try expect(std.mem.eql(u8, readLine(ping), "PING"));
}

test "simple string" {
    const message: []const u8 = "+PING\r\n";
    try expect(std.mem.eql(Msg, parse(message), Msg{ .simple = "PING" }));
}

const expect = std.testing.expect;
