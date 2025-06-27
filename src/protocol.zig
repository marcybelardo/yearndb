const std = @import("std");

// simple protocol
// RESP-like, without arrays/bulks yet
// PING\r\n\r\n -> PONG\r\n\r\n
// SET\r\nKEY\r\nVALUE\r\n\r\n -> OK\r\n
// GET\r\nKEY\r\n\r\n -> OK\r\n
// DEL\r\nKEY\r\n\r\n -> OK\r\n

fn parse(buf: []const u8) !void {
    var tokens = readToTokenSequence(buf);

}

fn readToTokenSequence(buf: []const u8) std.mem.TokenIterator(u8, .sequence) {
    const delim: []const u8 = "\r\n";
    return std.mem.tokenizeSequence(u8, buf, delim);
}

test "gets a line" {
    const ping: []const u8 = "PING\r\n";
    var seq = readToTokenSequence(ping);
    try expect(std.mem.eql(u8, seq.next().?, "PING"));
    try expect(seq.next() == null);
}

const expect = std.testing.expect;
