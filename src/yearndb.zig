const std = @import("std");
const net = std.net;
const posix = std.posix;

const YearnServer = @import("server.zig");

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
