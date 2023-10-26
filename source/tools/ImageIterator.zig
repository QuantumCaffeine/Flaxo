const std = @import("std");
const stdout = std.io.getStdOut().writer();
const Image = @import("Image.zig");
const Self = @This();

allocator: std.mem.Allocator,
data: []const u8,
pic_size: usize = 6462,
pos: usize = 0,
decodeFn: *const fn([]const u8, u32, u32, std.mem.Allocator) anyerror!Image,

pub fn next(self: *Self) !?Image {
    if (self.pos + self.pic_size > self.data.len) return null;
    const image = try self.decodeFn(self.data[self.pos..self.pos + self.pic_size], 320, 136, self.allocator);
    self.pos += self.pic_size;
    return image;
}
