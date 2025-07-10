const std = @import("std");
const fs = std.fs;

pub const TempFile = struct {
    fd: fs.File,
    tmp_name: std.BoundedArray(u8, fs.max_path_bytes),
    tmp_path: std.BoundedArray(u8, fs.max_path_bytes),

    pub fn close(self: *TempFile) !void {
        self.fd.close();
        try fs.cwd().deleteFile(self.tmp_path.slice());
    }

    pub fn savePermanent(self: TempFile, sub_path: []const u8, options: fs.Dir.CopyFileOptions) !void {
        if (sub_path.len <= 0) {
            return error.EmptyName;
        }

        var source_buffer: [fs.max_path_bytes]u8 = undefined;
        const source_absolute_path = try fs.cwd().realpath(self.tmp_path.slice(), &source_buffer);

        var buffer: [fs.max_path_bytes]u8 = undefined;
        const absolute_curr_path = try fs.cwd().realpath(".", &buffer);

        var dest_buffer: [fs.max_path_bytes]u8 = undefined;
        var fba = std.heap.FixedBufferAllocator.init(&dest_buffer);
        const allocator = fba.allocator();
        const dest = try fs.path.join(allocator, &[_][]const u8{ absolute_curr_path, sub_path });
        std.log.warn("{s}", .{dest});

        try fs.copyFileAbsolute(source_absolute_path, dest, options);
    }
};

fn random_numbers(allocator: std.mem.Allocator, len: usize) ![]const u8 {
    const time_stamp = std.time.milliTimestamp();
    const time_stamp_name = try std.fmt.allocPrint(allocator, "{d}", .{time_stamp});
    const time_stamp_ending = time_stamp_name[time_stamp_name.len - len ..];

    return time_stamp_ending;
}

pub fn createTempFile(config: struct {
    tmp_name: []const u8 = "",
    prefix: ?[]const u8 = null,
    flags: fs.File.CreateFlags = .{},
}) !TempFile {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const tmp_prefix = config.prefix orelse try random_numbers(allocator, 5);
    const tmp_name = try std.fmt.allocPrint(allocator, "{s}{s}", .{ tmp_prefix, config.tmp_name });

    var buffer: [fs.max_path_bytes]u8 = undefined;
    const real_path = try fs.cwd().realpath(".", &buffer);

    const joined = try fs.path.join(allocator, &[_][]const u8{ real_path, tmp_name });
    if (joined.len >= fs.max_path_bytes) {
        return error.Overflow;
    }

    const final_joined = try fs.path.join(allocator, &[_][]const u8{ ".", tmp_name });
    var final_path = try std.BoundedArray(u8, fs.max_path_bytes).init(final_joined.len);
    @memcpy(final_path.buffer[0..final_path.len], final_joined);

    const file = try fs.cwd().createFile(final_path.slice(), config.flags);
    var name = std.BoundedArray(u8, fs.max_path_bytes).init(0) catch unreachable;
    try name.appendSlice(config.tmp_name);

    return .{ .fd = file, .tmp_name = name, .tmp_path = final_path };
}

const expect = std.testing.expect;

test "create a temp file" {
    var buffer: [1000]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const allocator = fba.allocator();

    const random = try random_numbers(allocator, 5);
    var file = try createTempFile(.{ .prefix = random });
    defer file.close() catch @panic("Could not close the file");

    fs.cwd().access(random, .{}) catch {
        @panic("File should exist");
    };

    var crashed = false;
    file.savePermanent("", .{}) catch {
        crashed = true;
    };
    if (!crashed) {
        @panic("This should have failed!");
    }
}
