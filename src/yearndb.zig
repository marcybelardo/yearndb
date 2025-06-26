const std = @import("std");
const net = std.net;
const posix = std.posix;

const YearnServer = struct {
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
};

pub fn main() !u8 {
    std.debug.print("It's time to yearn\n", .{});

    var server = YearnServer.init() catch |err| {
        std.debug.print("error initializing server: {}\n", .{err});
        return 1;
    };
    defer server.deinit();

    while (true) {
        var client_addr: net.Address = undefined;
        var client_addrlen: posix.socklen_t = @sizeOf(net.Address);
        const client = posix.accept(server.fd, &client_addr.any, &client_addrlen, posix.SOCK.NONBLOCK) catch |err| {
            std.debug.print("error accepting client: {}\n", .{err});
            continue;
        };
        defer posix.close(client);

        std.debug.print("{} connected\n", .{client_addr});

        const greeting = "Hi! Time to yearn!\n";
        const written = posix.write(client, greeting) catch |err| {
            std.debug.print("error writing to client: {}\n", .{err});
            continue;
        };

        if (written == greeting.len) break;
    }

    return 0;
}
