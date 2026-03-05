const std = @import("std");
const shell = @import("shl.zig");
const ArrayList = std.ArrayList;

const Ls = @This();

const FileData = struct {
    name: []const u8,
    size: u64,
    kind: std.fs.Dir.Entry.Kind,
    mtime: u64,
};

const Table = struct {
    gap: u5,
    header: [4]TableFormating,
    rows: [100][4][]const u8,

    pub fn init(gap: u5, header: [4]TableFormating, rows: [100][4][]const u8) Table {
        return .{
            .gap = gap,
            .header = header,
            .rows = rows,
        };
    }

    pub fn print_rows(self: *Table, writer: *std.io.Writer) !void {
        for (self.rows) |row| {
            for (row) |cell| {
                try writer.print("{s}", .{cell});
                var i: u8 = 0;
                while (i < self.gap) : (i += 1) {
                    try writer.print("{s}", .{" "});
                }
            }
            try writer.print("\n", .{});
        }
    }

    pub fn print_header(self: *Table, writer: *std.io.Writer) !void {
        for (self.header) |item| {
            try writer.print("{s}", .{item.get()});
            var i: u8 = 0;
            while (i < self.gap) : (i += 1) {
                try writer.print("{s}", .{" "});
            }
        }
    }

    // pub fn print(self: Table, writer: *std.io.Writer) !void {
    //     for (self.header) |header| {
    //         try writer.print("{s}{s}", .{ header, " " ** self.gap });
    //     }
    //     try writer.print("\n", .{});
    //     for (self.rows) |row| {
    //         for (row) |cell| {
    //             try writer.print("{s}{s}", .{ cell, " " ** self.gap });
    //         }
    //         try writer.print("\n", .{});
    //     }
    // }
};

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

    var longest_size: usize = 0;
    var longest_name: usize = 0;
    var stats: [100]FileData = undefined;

    // Get files data
    var i: usize = 0;
    while (try it.next()) |entry| {
        const stat = try dir.statFile(entry.name);

        stats[i] = FileData{
            .name = entry.name,
            .size = @intCast(stat.size),
            .kind = stat.kind,
            .mtime = @intCast(stat.mtime),
        };

        if (entry.name.len > longest_name) longest_name = entry.name.len;
        if (stats[i].size > longest_size) longest_size = stats[i].size;
        i += 1;
    }

    const header_items = [_]TableFormating{
        .header_type,
        .header_time,
        .header_size,
        .header_name,
    };
    const gap = TableFormating.space.get().len;
    var rows: [100][4][]const u8 = undefined;

    // Colors
    // const dir_color = shell.Colors.foreground().BLUE;
    // const reset_color = shell.Colors.foreground().RESET;

    for (stats[0..i]) |stat| {
        const type_str: []const u8 = switch (stat.kind) {
            .directory => "d",
            .file => "f",
            else => "?",
        };

        // format time
        const date_time: DateTime = .init(@intCast(@divTrunc(stat.mtime, 1000000000)));
        var buf: [1024]u8 = undefined;
        const time_formated = try std.fmt.bufPrint(buf[0..1024], "{s} {d} {d}:{:0>2}:{:0>2}", .{ date_time.month, date_time.day, date_time.hour, date_time.minutes, date_time.seconds });

        rows[i] = [_][]const u8{ type_str, " " ** 7, time_formated, stat.name };
    }

    // print table
    var table: Table = .init(
        @intCast(gap),
        header_items,
        rows,
    );
    try table.print_header(stdout);
    try table.print_rows(stdout);
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
