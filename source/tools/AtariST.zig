const std = @import("std");
const Image = @import("Image.zig");
const stdout = std.io.getStdOut().writer();
const Decoder = @import("Decoder.zig");

pub const decoder = Decoder{.decoder = .{.Single = decode}, .format = "Atari ST"};

fn getBig(data: []const u8, pos: usize) u16 {
    return (@as(u16, data[pos << 1]) << 8) | data[(pos << 1) + 1];
}

fn decode(file_name: []const u8, data: []const u8, allocator: std.mem.Allocator) !?Image {
    _ = file_name;
    const expected_file_size: usize = @as(usize, getBig(data, 0)) + 1;
    //try stdout.print("{d} {d}\n", .{expected_file_size, data.len});
    //if (!std.mem.endsWith(u8, file_name, "squ")) return null;
    if (expected_file_size != data.len) return null;
    return try decode_file(data, allocator);
}

fn BitStream(comptime reader_type: type) type {
    return struct {
        reader: reader_type,
        buffer: usize = 0,
        bits: u5 = 0,

        const Self = @This();

        fn ensureBits(self: *Self, num_bits: u5) !void {
            while (self.bits < num_bits) {
                const byte = try self.reader.readByte();
                self.buffer |= (@as(usize, byte) << self.bits);
                self.bits += 8;
            }
        }

        pub fn peekBits(self: *Self, num_bits: u5) !u8 {
            try self.ensureBits(num_bits);
            const result = @truncate(u8, self.buffer & ((@as(usize, 1) << num_bits) - 1));
            return result;
        }

        //Assumes buffer size is at least num_bits
        pub fn skipBits(self: *Self, num_bits: u5) void {
            self.buffer >>= num_bits;
            self.bits -= num_bits;
        }

        pub fn readBits(self: *Self, num_bits: u5) !u8 {
            const result = try self.peekBits(num_bits);
            self.skipBits(num_bits);
            return result;
        }


    };
}

const STColour = packed struct(u16) {
    red: u4,
    padding: u4,
    blue: u4,
    green: u4
};

const Header = extern struct {
    data_length: u16,       //Length of file - 1 (big-endian)
    flags: u16,             //Flags? Not used here
    palette: [16]STColour,
    width: u16,
    height: u16,            //Image height in pixel rows
    seed: u8,
    padding: u8,
    pixel_table: [0x100]u8,
    bit_skip_table: [0x10]u8,
    pixel_index_table: [0x100]u8,

    pub fn getSkipBits(self: Header, pixelIndex: u8) u5 {
        return @truncate(u5, self.bit_skip_table[pixelIndex]);
    }

    pub fn getPixel(self: Header, pixel: u8, pixelIndex: u8) u8 {
        return self.pixel_table[(pixel << 4) + pixelIndex];
    }
};

fn stToRGB(colour: u8) u8 {
    return @truncate(u8, (@as(usize, colour) * 0x49) >> 1);
}

fn convertPalette(atari_palette: [16]STColour, rgb_palette: []Image.RGBColour) void {
    for (atari_palette, 0..) |colour, pos| {
        rgb_palette[pos] = Image.RGBColour{.red = stToRGB(colour.red), .green = stToRGB(colour.green), .blue = stToRGB(colour.blue)};
    }
}

fn decode_file(data: []const u8, allocator: std.mem.Allocator) !Image {
    var stream = std.io.FixedBufferStream([]const u8){.buffer = data, .pos = 0};
    var reader = stream.reader();
    var header = try reader.readStruct(Header);
    const height = @byteSwap(header.height);
    const width = @byteSwap(header.width);
    var bitStream = BitStream(@TypeOf(reader)){.reader = reader};
    var image = try Image.init(width, height, 16, allocator);
   
    var pixel = header.seed;
    for (0..width*height) |pos| {
        var pixelIndex: u8 = 0;
        const pixelData = try bitStream.peekBits(8);
        if (pixelData == 0xFF) {
            bitStream.skipBits(8);
            pixelIndex = try bitStream.readBits(4);
        } else {
            pixelIndex = header.pixel_index_table[pixelData];
            bitStream.skipBits(header.getSkipBits(pixelIndex));
        }
        pixel = header.getPixel(pixel, pixelIndex);
        image.data[pos] = pixel;
    }

    convertPalette(header.palette, image.palette);
    return image;
}