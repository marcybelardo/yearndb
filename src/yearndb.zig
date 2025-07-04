const std = @import("std");
const net = std.net;
const posix = std.posix;

const YearnServer = @import("server.zig");
const YearnProtocol = @import("protocol.zig");

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

        var read_buf: [4096]u8 = undefined;

        const read = posix.read(client, &read_buf) catch |err| {
            std.debug.print("error reading from client: {}\n", .{err});
            continue;
        };

        std.debug.print("{s}\n", .{read_buf});

        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        const allocator = gpa.allocator();
        defer _ = gpa.deinit();

        const msg = try YearnProtocol.parse(&read_buf, allocator);
        var reply: []const u8 = undefined;

        switch (msg) {
            .arr => |a| {
                defer a.deinit();
                for (a.items) |item| {
                    switch (item) {
                        .bulk => |b| {
                            if (std.mem.eql(u8, b, "PING")) {
                                reply = "+PONG\r\n";
                            }
                        },
                        else => reply = "+UNKNOWN COMMAND\r\n",
                    }
                }
            },
            else => reply = "+TIME TO YEARN\r\n",
        }

        const written = posix.write(client, reply) catch |err| {
            std.debug.print("error writing to client: {}\n", .{err});
            continue;
        };

        if (read != 0 and written != 0) break;
    }

    return 0;
}
