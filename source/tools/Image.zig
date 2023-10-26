const std = @import("std");
const stdout = std.io.getStdOut().writer();

width: usize,
height: usize,
palette: [] RGBColour,
data: [] u8,
allocator: std.mem.Allocator,

pub const RGBColour = extern struct {
    blue: u8 align(1),
    green: u8 align(1),
    red: u8 align(1),
    transparency: u8 align(1) = 0
};

const Self = @This();

pub fn init(width: usize, height: usize, palette_size: u8, allocator: std.mem.Allocator) !Self {
    var data = try allocator.alloc(u8, width*height);
    var palette = try allocator.alloc(RGBColour, palette_size);
    return Self{.width = width, .height = height, .palette = palette, .data = data, .allocator = allocator};
}

pub fn deinit(self: Self) void {
    self.allocator.free(self.palette);
    self.allocator.free(self.data);
}
