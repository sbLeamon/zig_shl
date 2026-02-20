const std = @import("std");

const INITIAL_PROMPT = "$";

pub const Shell = struct {
    value: u8 = 10,
    pub fn init(self: *Shell) void {
        _ = self;
    }

    pub fn parse(self: *Shell, stdin: *std.Io.Reader, stdout: *std.Io.Writer) !void {
        _ = self;

        try stdout.writeAll("$ ");
        try stdout.flush();
        var line = try stdin.takeDelimiter('\n') orelse unreachable;
        var trimmed_line = std.mem.trim(u8, line, "\r");

        try stdout.print("{s}: is not a command\n", .{trimmed_line});
        try stdout.flush();

        @memset(line, 0);
        // @memset(trimmed_line, 0);

        try stdout.writeAll("$ ");
        try stdout.flush();
        line = try stdin.takeDelimiter('\n') orelse unreachable;
        trimmed_line = std.mem.trim(u8, line, "\r");

        try stdout.print("{s}: is not a command\n", .{trimmed_line});
        try stdout.writeAll("This is the end\n");
        try stdout.flush();
    }

    pub fn deinit(self: *Shell) void {
        _ = self;
    }
};
