const std = @import("std");
const shell = @import("shl.zig");

const Ls = @This();

pub fn display_items(stdout: *std.io.Writer) !void {
    var dir = try std.fs.cwd().openDir(".", .{ .iterate = true });
    defer dir.close();

    var it = dir.iterate();
    const dir_color = shell.Colors.foreground().BLUE;
    const reset_color = shell.Colors.foreground().RESET;

    while (try it.next()) |entry| {
        if (entry.kind == .directory) {
            try stdout.print("{s}{s}/{s}\n", .{ dir_color, entry.name, reset_color });
        } else if (entry.kind == .file) {
            try stdout.print("{s}\n", .{entry.name});
        }
    }

    try stdout.flush();
}
