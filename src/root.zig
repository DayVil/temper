const tmpf = @import("temp_file.zig");
pub const TempFile = tmpf.TempFile;
pub const createTempFile = tmpf.createTempFile;

const std = @import("std");
const testing = std.testing;

test "Running tests across all folders" {
    std.testing.refAllDeclsRecursive(@This());
}
