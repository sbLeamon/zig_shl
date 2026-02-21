const std = @import("std");

const PROMPT: []const u8 = "$";

comptime {}

pub const Shell = struct {
    value: u8 = 10,
    pub fn init(self: *Shell) void {
        _ = self;
    }

    pub fn loop(self: *Shell, stdin: *std.Io.Reader, stdout: *std.Io.Writer) !void {
        var line: []u8 = undefined;

        // display prompt
        try stdout.writeAll(PROMPT);
        try stdout.writeAll(" ");
        try stdout.flush();

        // read command
        line = try stdin.takeDelimiter('\n') orelse unreachable;
        std.debug.print("line: {s} with len {d}\n", .{ line[0 .. line.len - 1], line.len });

        // parse command
        var command: []const u8 = try self.parse_command(line, stdout);

        std.debug.print("Is command exit: {any}\n", .{std.mem.eql(u8, command, "exit")});

        while (!std.mem.eql(u8, command, "exit")) {
            // display prompt
            try stdout.writeAll(PROMPT);
            try stdout.writeAll(" ");
            try stdout.flush();

            // read command
            line = try stdin.takeDelimiter('\n') orelse unreachable;

            // parse command
            command = try self.parse_command(line, stdout);
            std.debug.print("Is command NOT exit: {any}\n", .{!std.mem.eql(u8, command, "exit")});

            // TODO: you need to wipe out the buffer if u have SENSETIVE DATA
            // Here is a visual example of what happens in the background without @memset:
            // You type: hello Buffer in memory: [h, e, l, l, o, ?, ?] (length: 5) line slice points to the first 5 characters.
            // You type: ls Buffer in memory: [l, s, l, l, o, ?, ?]
            // Notice that l, l, o are still sitting in memory from the previous word.
            // hacker can dump the program's RAM and steal sensetive data

            // @memset(line, 0);
            // std.debug.print("Command after memset: {s}\n", .{command});
        }
    }

    fn parse_command(self: *Shell, line: []const u8, stdout: *std.Io.Writer) ![]const u8 {
        _ = self;

        const trimmed_line = std.mem.trim(u8, line, "\r");
        std.debug.print("Command: {s} with len {d}\n", .{ trimmed_line, trimmed_line.len });

        if (!std.mem.eql(u8, trimmed_line, "exit")) {
            try stdout.print("{s}: is not a command\n", .{trimmed_line});
            try stdout.flush();
            return trimmed_line;
        }

        return trimmed_line;
    }

    pub fn deinit(self: *Shell) void {
        _ = self;
    }
};
