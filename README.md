# Temper

A Zig library for creating and managing temporary files with automatic cleanup capabilities.

## Features

- 🧹 **Automatic cleanup**: Temporary files are automatically deleted when closed
- 🔒 **Thread-safe**: Uses mutex protection for safe concurrent file creation
- ⚙️ **Configurable**: Support for custom prefixes, suffixes, and file creation flags
- 💾 **Save permanently**: Option to save temporary files to permanent locations
- 🛡️ **Error handling**: Comprehensive error handling throughout the API
- ✅ **Well-tested**: Includes unit tests for reliability

## Installation

Add Temper as a dependency in your `build.zig.zon`:

```bash
zig fetch --save git+https://github.com/DayVil/temper#main
```

Then in your `build.zig`:

```zig
const temper = b.dependency("temper", .{});
exe.root_module.addImport("temper", temper.module("temper"));
```

## Usage

### Basic Example

```zig
const std = @import("std");
const temper = @import("temper");

pub fn main() !void {
    // Create a temporary file with a .txt extension
    var temp_file = try temper.createTempFile(.{ 
        .tmp_name = "hello.txt",
    });
    defer temp_file.close() catch unreachable;

    // Write to the temporary file
    try temp_file.fd.writeAll("Hello, temporary world!");

    // The file will be automatically cleaned up when closed
}
```

### Advanced Configuration

```zig
const std = @import("std");
const temper = @import("temper");

pub fn main() !void {
    // Create a temporary file with custom configuration
    var temp_file = try temper.createTempFile(.{
        .tmp_name = ".log",                    // File extension/suffix
        .prefix = "debug_",                    // Custom prefix 
        .allow_random_prefix = true,           // Include random prefix for uniqueness
        .flags = .{ .read = true, .write = true }, // File creation flags
    });
    defer temp_file.close() catch unreachable;

    // Perform file operations
    try temp_file.fd.writeAll("Debug information...");

    // Save to permanent location if needed
    try temp_file.savePermanent("logs/debug.log", .{});
    
    // Original temp file still needs to be closed for cleanup
}
```

## API Reference

### `TempFile`

The main structure representing a temporary file.

#### Fields

- `fd: fs.File` - The file descriptor for the temporary file
- `tmp_name: std.BoundedArray(u8, fs.max_path_bytes)` - The base name of the temporary file
- `tmp_path: std.BoundedArray(u8, fs.max_path_bytes)` - The full path to the temporary file

#### Methods

##### `close() !void`

Closes the temporary file and deletes it from the filesystem. This should be called when the temporary file is no longer needed.

```zig
try temp_file.close();
```

##### `savePermanent(sub_path: []const u8, options: fs.Dir.CopyFileOptions) !void`

Saves the temporary file to a permanent location by copying it. The original temporary file remains unchanged.

- `sub_path`: Destination path relative to the current working directory
- `options`: Copy options such as whether to override existing files

```zig
try temp_file.savePermanent("output/result.txt", .{ .override_mode = true });
```

### `createTempFile(config) !TempFile`

Creates a new temporary file with configurable options.

#### Configuration Options

- `tmp_name: []const u8` - Suffix to append to the filename (default: `""`)
- `prefix: []const u8` - Custom prefix for the filename (default: `""`)
- `allow_random_prefix: bool` - Whether to prepend a random timestamp-counter prefix for uniqueness (default: `true`)
- `flags: fs.File.CreateFlags` - File creation flags (default: `{}`)

#### Examples

```zig
// Basic usage with random prefix
var temp_file = try temper.createTempFile(.{
    .tmp_name = "data.json"
});

// Custom prefix with random prefix disabled
var temp_file2 = try temper.createTempFile(.{
    .prefix = "myapp_",
    .tmp_name = "cache.tmp", 
    .allow_random_prefix = false
});

// With specific file permissions
var temp_file3 = try temper.createTempFile(.{
    .tmp_name = "secure.dat",
    .flags = .{ .read = true, .write = true, .exclusive = true }
});
```

## Building

```bash
# Run tests
zig build test

# Build the library
zig build
```

## How It Works

Temper generates unique temporary file names using the format: `{random_prefix}{prefix}{tmp_name}`

**Components:**
1. **Random prefix** (optional): Timestamp suffix + thread-safe counter for uniqueness
2. **Custom prefix**: User-provided string prefix 
3. **Suffix/name**: User-provided file extension or name

**Filename generation:**
- When `allow_random_prefix = true` (default): Uses timestamp + counter for uniqueness
- When `allow_random_prefix = false`: Uses only custom prefix + suffix
- Thread-safe counter prevents collisions across concurrent operations

**Example filenames:**
- With random prefix: `67890-42debug_.log` 
- Without random prefix: `debug_.log`
- Random only: `67890-42data.json`

## Error Handling

The library provides comprehensive error handling:

- `error.Overflow` - Generated path exceeds maximum path length
- `error.EmptyName` - Empty sub_path provided to `savePermanent`
- File system errors - Various errors from underlying file operations

## Thread Safety

Temper is thread-safe. Multiple threads can create temporary files concurrently without filename collisions, thanks to the mutex-protected global counter.

## License

[Add your license here]

## Contributing

[Add contribution guidelines here]