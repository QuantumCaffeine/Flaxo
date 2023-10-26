const std = @import("std");
const Image = @import("Image.zig");
const ImageIterator = @import("ImageIterator.zig");
const Decoder = @import("Decoder.zig");

var palette = [_]Image.RGBColour{
    .{.red = 0x00, .green = 0x00, .blue = 0x00},
    .{.red = 0xFF, .green = 0xFF, .blue = 0xFF},
    .{.red = 0x7F, .green = 0x00, .blue = 0x00},
    .{.red = 0x00, .green = 0x7F, .blue = 0x7F},
    .{.red = 0x7F, .green = 0x00, .blue = 0x7F},
    .{.red = 0x00, .green = 0x7F, .blue = 0x00},
    .{.red = 0x00, .green = 0x00, .blue = 0x7F},
    .{.red = 0xFF, .green = 0xFF, .blue = 0x00},
    .{.red = 0x7F, .green = 0x7F, .blue = 0x00},
    .{.red = 0xFF, .green = 0x7F, .blue = 0x00},
    .{.red = 0xFF, .green = 0x00, .blue = 0x00},
    .{.red = 0x7F, .green = 0x7F, .blue = 0x7F},
    .{.red = 0x7F, .green = 0x7F, .blue = 0x7F},
    .{.red = 0x00, .green = 0xFF, .blue = 0x00},
    .{.red = 0x7F, .green = 0x7F, .blue = 0xFF},
    .{.red = 0x7F, .green = 0x7F, .blue = 0x7F},
};

pub const decoder = Decoder{.decoder = .{.Single = decode}, .format = "Amstrad"};
pub const libraryDecoder = Decoder{.decoder = .{.Library = decodeLibrary}, .format = "Amstrad"};

fn decode(file_name: []const u8, data: []const u8, allocator: std.mem.Allocator) !?Image {
    var title_pic_min_len: usize = 0;
    var title_pic_max_len: usize = 0;
    var standard_pic_min_len: usize = 0;
    var standard_pic_max_len: usize = 0;
    var offset: usize = 0;
    if (std.mem.endsWith(u8, file_name, ".pic")) {
        //Amstrad
        //Actual sizes are 10144 (title) and 6589 (regular), but actual files appear to be padded.
        title_pic_min_len = 10240;
        title_pic_max_len = 10624;
        standard_pic_min_len = 6589;
        standard_pic_max_len = 6656;
        offset = 128;
    } else if (std.mem.startsWith(u8, file_name, "p.")) {
        //BBC
        title_pic_min_len = 10048;
        title_pic_max_len = 10048;
        standard_pic_min_len = 6494;
        standard_pic_max_len = 6494;
    } else return null;
    //Check if the size is right to be either a title or first image.
    const width: u32 = 320;
    var height: u32 = 0;
    if ((data.len >= title_pic_min_len) and (data.len <= title_pic_max_len)) {//10624
        height = 200;
    } else if ((data.len >= standard_pic_min_len) and (data.len <= standard_pic_max_len)) {//6589
        height = 136;
    } else return null;
    return try decode_file(data[offset..], width, height, allocator);
}

fn decodeLibrary(file_name: []const u8, data: []const u8, allocator: std.mem.Allocator) !?ImageIterator {
    if (!std.mem.eql(u8, file_name, "allpics.pic")) return null;
    return ImageIterator{.allocator = allocator, .data = data, .pic_size = 6462, .decodeFn = decode_file};
}

const Tables = struct {
    image: []const u8,
    colours1: []const u8,
    colours2: []const u8,
    background: u4,
    compressed: bool,

    pub fn getColours2(self: Tables, pos: usize) u8 {
        if (self.compressed) {
            const byte = self.colours2[pos >> 1];
            if (pos%2 == 0) return byte >> 4
            else return byte & 0x0F;
        } else {
            return self.colours2[pos] & 0x0F;
        }
    }
};

fn getTables(data: []const u8, width: u32, height: u32) Tables {
    const total_blocks = (width * height) >> 6;
    const colours1_offset = 8*total_blocks;
    if (height == 200) { //Title image
        const background_offset = colours1_offset + total_blocks;
        const colours2_offset = background_offset + 16;
        return .{.image = data[0..8*total_blocks], //
                 .colours1 = data[colours1_offset..colours1_offset + total_blocks],
                 .colours2 = data[colours2_offset..colours2_offset + total_blocks],
                 .background = @truncate(u4, data[background_offset]),
                 .compressed = false
             };
    } else {
        const colours2_offset = colours1_offset + total_blocks;
        const background_offset = colours2_offset + (total_blocks >> 1);
        return .{.image = data[0..8*total_blocks], //
                 .colours1 = data[colours1_offset..colours1_offset + total_blocks],
                 .colours2 = data[colours2_offset..colours2_offset + (total_blocks>>1)],
                 .background = @truncate(u4, data[background_offset]),
                 .compressed = true
             };
    }
}

const BlockPos = struct {
    block: usize,
    row: usize,
    column: u2
};

const Pixels = packed struct(u8) {
    byte: u8,

    pub fn get(self: Pixels, pos: u2) u2 {
        return @truncate(u2, self.byte >> (6 - 2*@as(u3, pos)));
    }
};

fn getBlock(x: usize, y: usize) BlockPos {
    const x_block = x >> 3;
    const y_block = y >> 3;
    const block = 40*y_block + x_block; //((x_block + 32)%40);
    const row = y%8;
    const column = @truncate(u2, x >> 1);
    return BlockPos{.block = block, .row = row, .column = column};
}

fn getPixelData(data: []const u8, pos: BlockPos) u2 {
    const pixels = @bitCast(Pixels, data[8*pos.block + pos.row]);
    return pixels.get(pos.column);
}

fn decode_file(data: []const u8, width: u32, height: u32, allocator: std.mem.Allocator) !Image {
    var image = try Image.init(width, height, 16, allocator);
    for (palette, 0..) |value, pos| { 
        image.palette[pos] = value;
    }
    const tables = getTables(data, width, height);
    for (0..height) |y| {
        for (0..width) |x| {
            const pos = getBlock(x, y);
            const pixel = getPixelData(data, pos);

            const colour = switch (pixel) {
                0 => tables.background,
                1 => tables.colours1[pos.block] >> 4,
                2 => tables.colours1[pos.block] & 0x0F,
                3 => tables.getColours2(pos.block),
            };
            image.data[y*width + x] = colour;
        }
    }
    return image;
}
