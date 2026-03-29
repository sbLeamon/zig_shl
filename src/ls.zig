const std = @import("std");
const shell = @import("shl.zig");
const ArrayList = std.ArrayList;

const Ls = @This();

const FileData = struct {
    name: [256]u8,
    name_len: usize,
    size: u64,
    kind: std.Io.File.Kind,
    mtime: u64,
};

const Table = struct {
    writer: *std.Io.Writer,
    rows_count: usize,
    gap: u5,
    header: [4]HeaderItems,
    rows: [100][4][]const u8,

    pub fn init(writer: *std.Io.Writer, rows_count: usize, gap: u5, header: [4]HeaderItems, rows: [100][4][]const u8) Table {
        return .{
            .writer = writer,
            .rows_count = rows_count,
            .gap = gap,
            .header = header,
            .rows = rows,
        };
    }

    pub fn print_rows(self: *Table) !void {
        var i: usize = 0;
        while (i < self.rows_count) {
            for (self.rows[i]) |cell| {
                try self.writer.writeAll(cell);

                var j: usize = 0;
                while (j < self.gap) : (j += 1) {
                    try self.writer.writeAll(" ");
                }
            }
            try self.writer.print("\n", .{});
            i += 1;
        }
    }

    pub fn print_header(self: *Table) !void {
        for (self.header) |item| {
            try self.writer.writeAll(item.get());
            var i: u8 = 0;
            while (i < self.gap) : (i += 1) {
                try self.writer.writeAll(" ");
            }
        }
        try self.writer.writeAll("\n");
    }

    // pub fn print(self: Table, writer: *std.Io.Writer) !void {
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

const HeaderItems = enum {
    time_format,
    space,
    header_type,
    header_time,
    header_size,
    header_name,

    pub fn get(self: HeaderItems) []const u8 {
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
        const num_spaces = comptime (HeaderItems.header_type.get().len - 1 + HeaderItems.space.get().len);
        return " " ** num_spaces;
    }

    pub fn getHeader() []const u8 {
        return HeaderItems.header_type.get() ++
            HeaderItems.getTypePadding() ++
            HeaderItems.header_time.get() ++
            HeaderItems.space.get() ++
            HeaderItems.header_size.get() ++
            HeaderItems.space.get() ++
            HeaderItems.header_name.get() ++
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

pub fn display_items(stdout: *std.Io.Writer, io: *const std.Io) !void {
    var dir = try std.Io.Dir.cwd().openDir(io.*, ".", .{ .iterate = true });
    defer dir.close(io.*);

    var it = dir.iterate();

    var longest_size: usize = 0;
    var longest_name: usize = 0;
    var stats: [128]FileData = std.mem.zeroes([128]FileData);

    // Get files data
    var i: usize = 0;
    var rows_count: usize = 0;

    while (try it.next(io.*)) |entry| {
        var file_data: FileData = undefined;

        if (entry.kind == .file) {
            const stat = try dir.statFile(io.*, entry.name, .{ .follow_symlinks = true });
            file_data = .{
                .name = undefined,
                .name_len = entry.name.len,
                .size = @intCast(stat.size),
                .kind = stat.kind,
                .mtime = @intCast(if (stat.mtime.toMilliseconds() == 0) stat.ctime.toMilliseconds() else stat.mtime.toMilliseconds()),
            };
        } else {
            file_data = .{
                .name = undefined,
                .name_len = entry.name.len,
                .size = 0,
                .kind = entry.kind,
                .mtime = 0,
            };
        }

        @memcpy(file_data.name[0..entry.name.len], entry.name[0..entry.name.len]);
        stats[i] = file_data;

        if (entry.name.len > longest_name) longest_name = entry.name.len;
        if (stats[i].size > longest_size) longest_size = stats[i].size;

        i += 1;
        rows_count += 1;
    }

    const header_items = [_]HeaderItems{
        .header_type,
        .header_time,
        .header_size,
        .header_name,
    };
    const gap = HeaderItems.space.get().len;
    var rows: [100][4][]const u8 = undefined;

    // Colors
    // const dir_color = shell.Colors.foreground().BLUE;
    // const reset_color = shell.Colors.foreground().RESET;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var arena: std.heap.ArenaAllocator = .init(gpa.allocator());
    defer arena.deinit();
    const allocator = arena.allocator();

    for (stats[0..i], 0..) |stat, index| {
        const type_str: []const u8 = switch (stat.kind) {
            .directory => "d",
            .file => "f",
            else => "?",
        };

        // format time
        std.debug.print("stat.mtime: {d}\n", .{stat.mtime});
        const date_time: DateTime = .init(@intCast(@divTrunc(stat.mtime, 1000000000)));
        const time_formated = try std.fmt.allocPrint(allocator, "{s} {d} {d}:{:0>2}:{:0>2}", .{ date_time.month, date_time.day, date_time.hour, date_time.minutes, date_time.seconds });
        const name = try allocator.dupe(u8, stat.name[0..stat.name_len]);

        rows[index] = [_][]const u8{ type_str, " " ** 7, time_formated, name };

        // std.debug.print("Iteration: {d}\nrow[0]: {s}{s}{s}{s}\n", .{ index, rows[0][0], rows[0][1], rows[0][2], rows[0][3] });
        // if (index >= 1)
        //     std.debug.print("row[1]: {s}{s}{s}{s}\n", .{ rows[1][0], rows[1][1], rows[1][2], rows[1][3] });
    }

    // print table
    var table: Table = .init(
        stdout,
        rows_count,
        @intCast(gap),
        header_items,
        rows,
    );

    // for(rows) |row| {
    //     std.debug.print("row[{d}]: {s}", .{, row})
    // }

    try table.print_header();
    try table.print_rows();
    try stdout.flush();
}

// test "time format" {
//     var buf: [1024]u8 = undefined;
//     const time: i64 = 1772554416;
//     const date_time: DateTime = .init(time);
//
//     const formated = try std.fmt.bufPrint(buf[0..1024], "{s} {d} {d}:{:0>2}:{:0>2}", .{ date_time.month, date_time.day, date_time.hour, date_time.minutes, date_time.seconds });
//     try std.testing.expect(std.mem.eql(u8, formated, HeaderItems.time_format.get()));
// }

// test "display items" {
//     var stdout_buffer: [1024]u8 = undefined;
//     var stream = std.Io.Writer.fixed(&stdout_buffer);
//
//     try display_items(&stream);
//
//     var dir = try std.Io.Dir.cwd().openDir(".", .{ .iterate = true });
//     var dir_it = dir.iterate();
//
//     const data = stream.buffer[0..stream.end];
//     var it = std.mem.splitAny(u8, data, "\n");
//
//     var gpa = std.heap.GeneralPurposeAllocator(.{}){};
//     const allocator = gpa.allocator();
//     var formated: []u8 = undefined;
//     defer allocator.free(formated);
//
//     const dir_color = shell.Colors.foreground().BLUE;
//     const reset_color = shell.Colors.foreground().RESET;
//
//     while (it.next()) |entry| {
//         if (try dir_it.next()) |dir_entry| {
//             if (dir_entry.kind == .directory) {
//                 formated = try std.fmt.allocPrint(allocator, "{s}{s}/{s}", .{ dir_color, dir_entry.name, reset_color });
//                 try std.testing.expect(std.mem.eql(u8, entry[0 .. entry.len - 1], formated[0 .. formated.len - 1]));
//             } else if (dir_entry.kind == .file) {
//                 try std.testing.expect(std.mem.eql(u8, entry[0 .. entry.len - 1], dir_entry.name[0 .. dir_entry.name.len - 1]));
//             }
//         }
//     }
// }
