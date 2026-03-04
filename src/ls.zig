const std = @import("std");
const shell = @import("shl.zig");

const Ls = @This();

const TableFormating = enum {
    time_format,
    space,
    header_type,
    header_time,
    header_size,
    header_name,

    pub fn get(self: TableFormating) []const u8 {
        return switch (self) {
            .time_format => "Mmm d hh:mm:ss",
            .space => " ",
            .header_type => "Type",
            .header_time => "Last modified",
            .header_size => "Size",
            .header_name => "Name",
        };
    }

    pub fn getTypePadding() []const u8 {
        const num_spaces = comptime (TableFormating.header_type.get().len - 1 + TableFormating.space.get().len);
        return " " ** num_spaces;
    }

    pub fn getHeader() []const u8 {
        return TableFormating.header_type.get() ++
            TableFormating.getTypePadding() ++
            TableFormating.header_time.get() ++
            TableFormating.space.get() ++
            TableFormating.header_size.get() ++
            TableFormating.space.get() ++
            TableFormating.header_name.get() ++
            "\n";
    }
};

const DateTime = struct {
    month: []const u8,
    day: u5,
    hour: u5,
    minutes: u6,
    seconds: u6,

    pub fn init(timestamp: u64) DateTime {
        const epoch: std.time.epoch.EpochSeconds = .{ .secs = timestamp };
        const year_day = epoch.getEpochDay().calculateYearDay();
        const month_day = year_day.calculateMonthDay();
        const month = std.time.epoch.Month.numeric(month_day.month);
        const day = month_day.day_index + 1;
        const hour = epoch.getDaySeconds().getHoursIntoDay();
        const minute = epoch.getDaySeconds().getMinutesIntoHour();
        const second = epoch.getDaySeconds().getSecondsIntoMinute();

        return .{
            .month = switch (month) {
                1 => "Jan",
                2 => "Feb",
                3 => "Mar",
                4 => "Apr",
                5 => "May",
                6 => "Jun",
                7 => "Jul",
                8 => "Aug",
                9 => "Sep",
                10 => "Oct",
                11 => "Nov",
                12 => "Dec",
                else => unreachable,
            },
            .day = day,
            .hour = hour,
            .minutes = minute,
            .seconds = second,
        };
    }
};

pub fn display_items(stdout: *std.io.Writer) !void {
    var dir = try std.fs.cwd().openDir(".", .{ .iterate = true });
    defer dir.close();

    var it = dir.iterate();
    const dir_color = shell.Colors.foreground().BLUE;
    const reset_color = shell.Colors.foreground().RESET;

    try stdout.print(TableFormating.getHeader(), .{});

    while (try it.next()) |entry| {
        if (entry.kind == .directory) {
            const stat = try dir.stat();
            const date_time: DateTime = .init(@intCast(@divTrunc(stat.mtime, 1000000000)));
            var buf: [1024]u8 = undefined;
            const time_formated = try std.fmt.bufPrint(buf[0..1024], "{s} {d} {d}:{:0>2}:{:0>2}", .{ date_time.month, date_time.day, date_time.hour, date_time.minutes, date_time.seconds });
            try stdout.print("{s}d{s}{s}{s}{s}\n", .{ dir_color, " " ** 7, time_formated, entry.name, reset_color });
        } else if (entry.kind == .file) {
            const stat = try dir.statFile(entry.name);
            const date_time: DateTime = .init(@intCast(@divTrunc(stat.mtime, 1000000000)));
            var buf: [1024]u8 = undefined;
            const time_formated = try std.fmt.bufPrint(buf[0..1024], "{s} {d} {d}:{:0>2}:{:0>2}", .{ date_time.month, date_time.day, date_time.hour, date_time.minutes, date_time.seconds });
            try stdout.print("f{s}{s}{s}\n", .{ " " ** 7, time_formated, entry.name });
        }
    }

    try stdout.flush();
}

test "time format" {
    var buf: [1024]u8 = undefined;
    const time: i64 = 1772554416;
    const date_time: DateTime = .init(time);

    const formated = try std.fmt.bufPrint(buf[0..1024], "{s} {d} {d}:{:0>2}:{:0>2}", .{ date_time.month, date_time.day, date_time.hour, date_time.minutes, date_time.seconds });
    try std.testing.expect(std.mem.eql(u8, formated, TableFormating.time_format.get()));
}

test "display items" {
    var stdout_buffer: [1024]u8 = undefined;
    var stream = std.io.Writer.fixed(&stdout_buffer);

    try display_items(&stream);

    var dir = try std.fs.cwd().openDir(".", .{ .iterate = true });
    var dir_it = dir.iterate();

    const data = stream.buffer[0..stream.end];
    var it = std.mem.splitAny(u8, data, "\n");

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var formated: []u8 = undefined;
    defer allocator.free(formated);

    const dir_color = shell.Colors.foreground().BLUE;
    const reset_color = shell.Colors.foreground().RESET;

    while (it.next()) |entry| {
        if (try dir_it.next()) |dir_entry| {
            if (dir_entry.kind == .directory) {
                formated = try std.fmt.allocPrint(allocator, "{s}{s}/{s}", .{ dir_color, dir_entry.name, reset_color });
                try std.testing.expect(std.mem.eql(u8, entry[0 .. entry.len - 1], formated[0 .. formated.len - 1]));
            } else if (dir_entry.kind == .file) {
                try std.testing.expect(std.mem.eql(u8, entry[0 .. entry.len - 1], dir_entry.name[0 .. dir_entry.name.len - 1]));
            }
        }
    }
}
