const std = @import("std");

pub fn build(b: *std.Build) void {
    const exe = b.addExecutable(.{
        .name = "yearndb",
        .root_source_file = b.path("src/yearndb.zig"),
        .target = b.graph.host,
    });

    b.installArtifact(exe);
}
