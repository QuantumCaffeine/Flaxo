const std = @import("std");
const stdout = std.io.getStdOut().writer();
const Image = @import("Image.zig");
const Decoder = @import("Decoder.zig");

fn getBig(data: []const u8, pos: usize) u16 {
    return (@as(u16, data[pos << 1]) << 8) | data[(pos << 1) + 1];
}

const AmigaColour = packed struct(u16) {
    blue: u4,
    green: u4,
    red: u4,
    padding: u4,
};

fn intensity(colour: u4) u8 {
    const float_colour = @intToFloat(f64, colour);
    return @floatToInt(u8, std.math.floor(std.math.pow(f64, float_colour/15, 1.0/0.8) * 0xFF));
}

fn decode_palette(data: []const u8, palette: []Image.RGBColour) void {
    for (palette, 0..) |*entry, i| {
        const col = @bitCast(AmigaColour, getBig(data, i));
        entry.* = Image.RGBColour{.red = intensity(col.red), .green = intensity(col.green), .blue = intensity(col.blue)};
    }
}

pub const decoder = Decoder{.decoder = .{.Single = decode}, .format = "Amiga"};

fn decode(file_name: []const u8, data: []const u8, allocator: std.mem.Allocator) !?Image {
    if (std.mem.indexOf(u8, file_name, ".")) |_| {
        return null;
    }
    if (data.len < 100) return null;
    const width: usize = getBig(data, 33);
    const height: usize = getBig(data, 35);
    const expected_file_size = ((width*height*5) >> 3) + 72;
    if (data.len != expected_file_size) {
        //try stdout.print("{d} {d} {d} {d}\n", .{data.len, expected_file_size, width, height});
        return null;
    }
    return try decode_file(data, width, height, allocator);
}

fn decode_file(data: []const u8, width: usize, height: usize, allocator: std.mem.Allocator) !Image {
    var image = try Image.init(width, height, 32, allocator);
    decode_palette(data, image.palette);

    const plane_size = (width*height) >> 3;
    const image_data = data[72..];
    for (0..height*width) |pixel| {
        var colour: u8 = 0;
        var target_byte = (pixel >> 3) + 5*plane_size;
        const target_bit = @truncate(u3, pixel);
        for (0..5) |_| {
            target_byte -= plane_size;
            const bit = @truncate(u1, (image_data[target_byte] >> (7 - target_bit)));
            colour = 2*colour + bit;
        }
        image.data[pixel] = colour;
    }
    return image;
}