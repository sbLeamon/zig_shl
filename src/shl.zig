const std = @import("std");
const Shell = @This();

const Colors = struct {
    RED: []const u8,
    GREEN: []const u8,
    BLUE: []const u8,
    RESET: []const u8 = "\x1b[0m",

    pub fn foreground() Colors {
        return .{
            .RED = "\x1b[31m",
            .GREEN = "\x1b[32m",
            .BLUE = "\x1b[34m",
        };
    }

    pub fn background() Colors {
        return .{
            .RED = "\x1b[41m",
            .GREEN = "\x1b[42m",
            .BLUE = "\x1b[44m",
        };
    }
};

const PROMPT: []const u8 = ">";

pub fn loop(stdin: *std.Io.Reader, stdout: *std.Io.Writer) !void {
    var line: []u8 = undefined;

    // display prompt
    var cwd_buffer: [1024]u8 = undefined;
    const cwd = try std.process.getCwd(&cwd_buffer);

    const colors = &Colors.background();
    try Shell.print_prompt(stdout, cwd, colors);

    // read command
    line = try stdin.takeDelimiter('\n') orelse unreachable;

    // parse command
    var command: []const u8 = try Shell.parse_command(line, stdout);

    while (!std.mem.eql(u8, command, "exit")) {
        // display prompt
        try Shell.print_prompt(stdout, cwd, colors);

        // read command
        line = try stdin.takeDelimiter('\n') orelse unreachable;

        // parse command
        command = try Shell.parse_command(line, stdout);

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

fn print_prompt(stdout: *std.Io.Writer, cwd: []const u8, colors: *const Colors) !void {
    try stdout.writeAll(colors.BLUE);
    try stdout.writeAll(cwd);
    try stdout.writeAll(" ");
    try stdout.writeAll(PROMPT);
    try stdout.writeAll(colors.RESET);
    try stdout.writeAll(" ");
    try stdout.flush();
}

fn parse_command(line: []const u8, stdout: *std.Io.Writer) ![]const u8 {
    const trimmed_line = std.mem.trim(u8, line, "\r");

    if (std.mem.eql(u8, trimmed_line, "exit")) {
        return trimmed_line;
    }

    try stdout.print("{s}: is not a command\n", .{trimmed_line});
    try stdout.flush();

    return trimmed_line;
}
