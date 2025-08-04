//! Temper - A Zig library for creating and managing temporary files
//! 
//! This module provides a simple and safe API for working with temporary files.
//! Temporary files are automatically cleaned up when closed, and can optionally
//! be saved to permanent locations.
//! 
//! Main exports:
//! - `TempFile`: A struct representing a temporary file with cleanup capabilities
//! - `createTempFile`: Function to create new temporary files with various options

const tmpf = @import("temp_file.zig");

/// Temporary file structure with automatic cleanup capabilities.
/// See temp_file.zig for full documentation.
pub const TempFile = tmpf.TempFile;

/// Creates a new temporary file with configurable options.
/// See temp_file.zig for full documentation and usage examples.
pub const createTempFile = tmpf.createTempFile;

const std = @import("std");
const testing = std.testing;

test "Running tests across all folders" {
    _ = @import("temp_file.zig");
}
