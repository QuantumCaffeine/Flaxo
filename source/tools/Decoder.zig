const std = @import("std");
const Image = @import("Image.zig");
const ImageIterator = @import("ImageIterator.zig");

decoder: Decoder,
format: []const u8,

const Decoder = union(enum) {
    Single: *const fn ([]const u8, []const u8, std.mem.Allocator) anyerror!?Image,
    Library: *const fn ([]const u8, []const u8, std.mem.Allocator) anyerror!?ImageIterator,
};