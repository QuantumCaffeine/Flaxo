const std = @import("std");
const stdout = std.io.getStdOut().writer();
const Image = @import("Image.zig");
const Decoder = @import("Decoder.zig");

fn getBig(data: []const u8, pos: usize) u16 {
    return (@as(u16, (data[pos << 1])) << 8) | data[(pos << 1) + 1];
}

pub const decoder = Decoder{.decoder = .{.Single = decode}, .format = "Macintosh"};

fn decode(file_name: []const u8, data: []const u8, allocator: std.mem.Allocator) !?Image {
    if (std.mem.indexOf(u8, file_name, ".")) |_| {
        return null;
    }
    var width: usize = getBig(data, 1);
    const height: usize = getBig(data, 3);
    if (!(width == 512 or width == 360 or width == 359)) {
        try stdout.print("{d} {d}\n", .{width, height});
        return null;
    }
    if (width == 359) width = 360;
    const expected_file_size = ((width*height) >> 3) + 10;
    //Some files are padded with 0x1A bytes, so be relaxed about length check.
    if (data.len < expected_file_size) return null;
    return try decode_file(data, width, height, allocator);
}

fn decode_file(data: []const u8, width: usize, height: usize, allocator: std.mem.Allocator) !Image {
    var image = try Image.init(width, height, 2, allocator);
    image.palette[0] = Image.RGBColour{.red = 0, .green = 0, .blue = 0};
    image.palette[1] = Image.RGBColour{.red = 0xFF, .green = 0xFF, .blue = 0xFF};
    const image_data = data[10..];
    for (0..height*width) |pixel| {
        const target_byte = (pixel >> 3);
        const target_bit:u3 = @truncate(u3, pixel%8);
        const bit = @truncate(u1, (image_data[target_byte] >> (7 - target_bit)));
        image.data[pixel] = bit;
    }
    return image;
}