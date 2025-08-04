const std = @import("std");
const fs = std.fs;

var mutex = std.Thread.Mutex{};
const CounterT = u16;
var counter: CounterT = 0;

/// A temporary file that is automatically cleaned up when closed.
/// Provides functionality to create, manage, and optionally save temporary files permanently.
pub const TempFile = struct {
    /// The file descriptor for the temporary file
    fd: fs.File,
    /// The base name of the temporary file (without path)
    tmp_name: std.BoundedArray(u8, fs.max_path_bytes),
    /// The full path to the temporary file
    tmp_path: std.BoundedArray(u8, fs.max_path_bytes),

    /// Closes the temporary file and deletes it from the filesystem.
    /// This should be called when the temporary file is no longer needed
    /// to ensure proper cleanup and prevent file system clutter.
    ///
    /// Returns:
    ///   - `void` on success
    ///   - Error if the file cannot be deleted
    pub fn close(self: *TempFile) !void {
        self.fd.close();
        try fs.cwd().deleteFile(self.tmp_path.slice());
    }

    /// Saves the temporary file to a permanent location by copying it.
    /// The original temporary file remains unchanged and should still be closed separately.
    ///
    /// Parameters:
    ///   - `sub_path`: The destination path relative to the current working directory
    ///   - `options`: Copy options such as whether to override existing files
    ///
    /// Returns:
    ///   - `void` on success
    ///   - `error.EmptyName` if sub_path is empty
    ///   - File system errors if the copy operation fails
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

/// Generates a random string for use in temporary file names.
/// Uses a combination of current timestamp and an incrementing counter to ensure uniqueness.
/// This function is thread-safe through the use of a mutex.
///
/// Parameters:
///   - `allocator`: Memory allocator for the generated string
///   - `len`: Length of the timestamp suffix to use
///
/// Returns:
///   - A formatted string containing timestamp suffix and counter
///   - Allocation errors if memory allocation fails
fn random_numbers(allocator: std.mem.Allocator, len: usize) ![]const u8 {
    mutex.lock();
    defer {
        counter = (counter + 1) % std.math.maxInt(CounterT);
        mutex.unlock();
    }

    const time_stamp = std.time.milliTimestamp();
    const time_stamp_name = try std.fmt.allocPrint(allocator, "{d}", .{time_stamp});
    const time_stamp_ending = time_stamp_name[time_stamp_name.len - len ..];

    const prefix = std.fmt.allocPrint(allocator, "{s}-{d}", .{ time_stamp_ending, counter });

    return prefix;
}

/// Creates a new temporary file in the current working directory.
/// The file is created with a unique name and can be configured with custom prefix and flags.
/// The returned TempFile should be closed when no longer needed to clean up the file.
///
/// Configuration options:
///   - `tmp_name`: Suffix to append to the generated temporary filename (default: "")
///   - `prefix`: Custom prefix for the filename (default: "")
///   - `allow_random_prefix`: Whether to prepend a random timestamp-counter prefix for uniqueness (default: true)
///   - `flags`: File creation flags such as read/write permissions (default: {})
///
/// The final filename format is: `{random_prefix}{prefix}{tmp_name}`
/// Where `random_prefix` is only included if `allow_random_prefix` is true.
///
/// Returns:
///   - `TempFile` structure containing the file descriptor and path information
///   - `error.Overflow` if the generated path exceeds the maximum path length
///   - File system errors if the file cannot be created
///
/// Example:
/// ```zig
/// // Create temp file with random prefix and custom suffix
/// var temp_file = try createTempFile(.{ .tmp_name = "data.json" });
/// defer temp_file.close() catch unreachable;
///
/// // Create temp file with custom prefix and no random prefix
/// var temp_file2 = try createTempFile(.{
///     .prefix = "myapp_",
///     .tmp_name = "cache.tmp",
///     .allow_random_prefix = false
/// });
/// defer temp_file2.close() catch unreachable;
///
/// // Create temp file with specific permissions
/// var temp_file3 = try createTempFile(.{
///     .tmp_name = "secure.dat",
///     .flags = .{ .read = true, .write = true, .exclusive = true }
/// });
/// defer temp_file3.close() catch unreachable;
/// ```
pub fn createTempFile(config: struct {
    tmp_name: []const u8 = "",
    prefix: []const u8 = "",
    allow_random_prefix: bool = true,
    flags: fs.File.CreateFlags = .{},
}) !TempFile {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const random_num = blk: {
        var ran_num: []const u8 = "";
        if (config.allow_random_prefix)
            ran_num = try random_numbers(allocator, 5);
        break :blk ran_num;
    };

    const tmp_name = try std.fmt.allocPrint(
        allocator,
        "{s}{s}{s}",
        .{ random_num, config.prefix, config.tmp_name },
    );

    var buffer: [fs.max_path_bytes]u8 = undefined;
    const real_path = try fs.cwd().realpath(".", &buffer);

    const joined = try fs.path.join(allocator, &[_][]const u8{ real_path, tmp_name });
    if (joined.len >= fs.max_path_bytes) {
        return error.Overflow;
    }

    const final_joined = try fs.path.join(allocator, &[_][]const u8{ ".", tmp_name });
    var final_path = std.BoundedArray(u8, fs.max_path_bytes).init(final_joined.len) catch unreachable;
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
    var file = try createTempFile(.{ .prefix = random, .allow_random_prefix = false });
    defer file.close() catch @panic("Could not close the file");

    fs.cwd().access(random, .{}) catch {
        std.debug.print("Found file: {}\n", .{file.tmp_path.slice()});
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
