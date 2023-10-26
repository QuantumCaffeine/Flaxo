const std = @import("std");
const stdout = std.io.getStdOut().writer();
const writer = @import("bmp_writer.zig");
const Image = @import("Image.zig");
const Decoder = @import("Decoder.zig");
const builtin = @import("builtin");

const Amstrad = @import("Amstrad.zig");
const decoders = [_]Decoder{
    @import("Amiga.zig").decoder, //
    Amstrad.decoder,
    Amstrad.libraryDecoder,
    @import("AtariST.zig").decoder,
    @import("Mac.zig").decoder,
};

var call_name: []const u8 = undefined;
var memory: [3 * 1024 * 1024]u8 = undefined;

fn fail(file_name: []const u8, error_string: []const u8) !void {
    try stdout.print("{s}: {s}\n", .{ file_name, error_string });
    try usage();
}

fn usage() !void {
    try stdout.print("Usage: {s} [format] [picture file]\n", .{call_name});
}

fn getFilename(path: []const u8) []const u8 {
    switch (builtin.os.tag) {
        .windows => {
            var iter = std.mem.splitBackwards(u8, path, "\\");
            return iter.next().?;
        },
        else => {
            var iter = std.mem.splitBackwards(u8, path, "/");
            return iter.next().?;
        },
    }
}

var Allocator: std.heap.FixedBufferAllocator = undefined;

pub fn main() !void {
    //var Allocator = std.heap.FixedBufferAllocator.init(&memory);
    //const allocator = Allocator.allocator();
    Allocator = std.heap.FixedBufferAllocator.init(&memory);
    //const backing_allocator = Allocator.allocator();
    //var LoggingAllocator = std.heap.LoggingAllocator(.info, .warn){.parent_allocator = backing_allocator};
    //const allocator = LoggingAllocator.allocator();
    const allocator = Allocator.allocator();

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    call_name = args.next() orelse "";

    while (args.next()) |pic_path| {
        const pic_file = std.fs.path.basename(pic_path);
        var file = std.fs.cwd().openFile(pic_path, .{}) catch |err| {
            if (err == error.FileNotFound) return fail(pic_path, "File not found.") else return fail(pic_file, "Error opening file.");
        };
        defer file.close();

        const file_size = (try file.metadata()).size();
        if ((file_size < 100) or (file_size > 200000)) continue;

        const data = file.readToEndAlloc(allocator, 200000) catch |err| {
            if (err == error.IsDir) continue else return fail(pic_path, "Error reading file.");
        };
        defer allocator.free(data);

        try decode(pic_file, data, allocator);
        //try stdout.print("Fixed size: {d}\n", .{Allocator.end_index});
    }
    try stdout.print("Done.\n", .{});
}

fn decode(file_name: []const u8, data: []const u8, allocator: std.mem.Allocator) !void {
    const lower_file_name = try std.ascii.allocLowerString(allocator, file_name);
    defer allocator.free(lower_file_name);
    //try stdout.print("Fixed size: {d}\n", .{Allocator.end_index});
    for (decoders) |format| {
        switch (format.decoder) {
            .Single => |decodeFn| {
                if (try decodeFn(lower_file_name, data, allocator)) |image| {
                    defer image.deinit();
                    const image_no = toNumber(lower_file_name);
                    //try stdout.print("Fixed size: {d}\n", .{Allocator.end_index});
                    try stdout.print("{s}: {s} bitmap,", .{ file_name, format.format });
                    try writeImage(file_name, image, image_no, allocator);
                    break;
                }
            },
            .Library => |decodeFn| {
                var image_set = try decodeFn(lower_file_name, data, allocator);
                if (image_set) |*images| {
                    try stdout.print("{s}: {s} bitmap set.\n", .{ file_name, format.format });
                    var image_no: usize = 2;
                    while (try images.next()) |image| : (image_no += 1) {
                        defer image.deinit();
                        try stdout.print("    Image {d}", .{image_no});
                        try writeImage(file_name, image, image_no, allocator);
                    }
                }
            },
        }
    }
    //try stdout.print("Fixed size: {d}\n", .{Allocator.end_index});
}

fn toNumber(file_name: []const u8) usize {
    if (std.mem.indexOf(u8, file_name, "title")) |_| {
        return 30;
    }
    var result: usize = 0;
    for (file_name) |char| {
        if (std.ascii.isDigit(char)) {
            result = 10 * result + (char - '0');
        }
    }
    return result;
}

fn writeImage(file_name: []const u8, image: Image, image_no: usize, allocator: std.mem.Allocator) !void {
    writeFile(image, image_no, allocator) catch |err| {
        defer image.deinit();
        try fail(file_name, "Error! Could not write output file.");
        return err;
    };
}

fn writeFile(image: Image, image_no: usize, allocator: std.mem.Allocator) !void {
    const bmp = try writer.write(image, allocator);
    defer allocator.free(bmp);

    var filename_buffer: [10]u8 = undefined;
    const out_file = try std.fmt.bufPrint(&filename_buffer, "{d}.bmp", .{image_no});
    try stdout.print(" written to {s}.\n", .{out_file});
    var outfile = try std.fs.cwd().createFile(out_file, .{});
    defer outfile.close();

    try outfile.writeAll(bmp);
}
