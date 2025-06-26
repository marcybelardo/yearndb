const std = @import("std");
const net = std.net;
const posix = std.posix;

const YearnServer = @This();

fd: posix.socket_t,

pub fn init() !YearnServer {
    const addr = net.Address.initIp4([4]u8{ 127, 0, 0, 1}, 6379);
    const fd = try posix.socket(addr.any.family, posix.SOCK.STREAM, posix.IPPROTO.TCP);
    try posix.setsockopt(fd, posix.SOL.SOCKET, posix.SO.REUSEADDR, &std.mem.toBytes(@as(c_int, 1)));
    try posix.bind(fd, &addr.any, net.Address.getOsSockLen(addr));
    try posix.listen(fd, 128);

    return .{ .fd = fd };
}

pub fn deinit(self: *YearnServer) void {
    posix.close(self.fd);
}

