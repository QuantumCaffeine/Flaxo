const std = @import("std");
const stdout = std.io.getStdOut().writer();
const MFSVolume = @import("MFSVolume.zig");

var call_name: []const u8 = undefined;
var memory: [2 * 1024 * 1024]u8 = undefined;

fn fail(file_name: []const u8, error_string: []const u8) !void {
    try stdout.print("{s}: {s}\n", .{ file_name, error_string });
    try usage();
}

fn usage() !void {
    try stdout.print("Usage: {s} [dsk archive]\n", .{call_name});
}

var Allocator: std.heap.FixedBufferAllocator = undefined;

pub fn main() !void {
    Allocator = std.heap.FixedBufferAllocator.init(&memory);
    const backing_allocator = Allocator.allocator();
    var LoggingAllocator = std.heap.LoggingAllocator(.info, .warn){.parent_allocator = backing_allocator};
    const allocator = LoggingAllocator.allocator();

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    call_name = args.next().?;

    while (args.next()) |dsk_path| {
        const dsk_file = std.fs.path.basename(dsk_path);
        var file = std.fs.cwd().openFile(dsk_path, .{}) catch |err| {
            if (err == error.FileNotFound) return fail(dsk_path, "File not found.") else return fail(dsk_file, "Error opening file.");
        };
        defer file.close();

        const file_size = (try file.metadata()).size();
        if ((file_size < 100) or (file_size > 500000)) continue;

        var data = file.readToEndAlloc(allocator, 500000) catch |err| {
            if (err == error.IsDir) continue else return fail(dsk_path, "Error reading file.");
        };
        defer allocator.free(data);

        try extract(data, allocator);
    }
    try stdout.print("Done.\n", .{});
}

fn extract(data: []u8, allocator: std.mem.Allocator) !void {
    var volume = try MFSVolume.init(data);
    var iter = volume.readDirectory();
    while (try iter.next()) |file| {
        const file_data = try volume.readFile(file, allocator);
        if (file_data) |bytes| {
            defer allocator.free(bytes);
            try writeFile(file.name, bytes[0..file.size]);
        }
        try stdout.print("Fixed size: {d}\n", .{Allocator.end_index});
    }
}

fn writeFile(file_name: []const u8, bytes: []const u8) !void {
    try stdout.print("Writing {s} ({d} bytes)\n", .{file_name, bytes.len});
    var outfile = try std.fs.cwd().createFile(file_name, .{});
    defer outfile.close();

    try outfile.writeAll(bytes);
}
