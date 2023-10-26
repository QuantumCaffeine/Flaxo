const std = @import("std");
const Image = @import("Image.zig");
const stdout = std.io.getStdOut().writer();

const Header = extern struct {
    //Bitmap file header
    magic: u16 = 0x4D42, //"BM"
    file_size: u32 align(2),
    reserved: u32 align(2) = 0,
    data_offset: u32 align(2) = 14 + 40 + 4*32, //Offset by total size of both headers plus palette
    //BITMAPINFOHEADER
    header_size: u32 align(2) = 40,
    width: u32 align(2),
    height: i32 align(2),
    colour_planes: u16 = 1,
    colour_depth: u16 = 8,
    compression_method: u32 align(2) = 0, //Uncompressed
    data_size: u32 align(2),
    horizontal_resolution: u32 align(2) = 255, //Pixels per metre
    vertical_resolution: u32 align(2) = 255,
    colour_palette_size: u32 align(2) = 32,
    number_of_important_colours: u32 align(2) = 0, //All colours are important

    pub fn init(width: usize, height: usize, data_size: usize, palette_size: u32) Header {
        var header_size = 14 + 40 + 4*palette_size;
        return .{
            .file_size = @truncate(u32, header_size + data_size), //
            .width = @truncate(u32, width),
            .height = -@intCast(i32, height),
            .data_size = @truncate(u32, data_size),
            .data_offset = header_size,
            .colour_palette_size = palette_size
        };
    }
};

pub fn write(image: Image, allocator: std.mem.Allocator) ![]u8 {
    const padding = if (image.width%4 == 0) 0 else 4 - (image.width%4);
    const data_size = (image.width + padding)*image.height;
    const header = Header.init(image.width, image.height, data_size, @truncate(u32, image.palette.len));
    var bmp: []u8 = try allocator.alloc(u8, header.file_size);

    var stream = std.io.FixedBufferStream([]u8){.buffer = bmp, .pos = 0};
    var writer = stream.writer();
    try writer.writeStruct(header);

    for (image.palette) |colour| {
        _ = try writer.write(&@bitCast([4]u8, colour));
    }

    for (0..image.height) |y| {
        const row_start = y*image.width;
        _ = try writer.write(image.data[row_start..row_start + image.width]);
        for (0..padding) |_| {
            try writer.writeByte(0);
        }
    }

    return bmp;
}