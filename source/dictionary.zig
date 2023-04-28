const Header = @import("Header.zig");
const Bytes = @import("Bytes.zig");
const io = @import("io.zig");
const std = @import("std");

const Word = struct {
    word: []u8,
    value: u8
};

var words: [1000]Word = undefined;

pub fn init(header: Header) void {
    if (header.version <= 2) buildV1(header.dictionary) else buildV3(header.dictionary);
}

fn buildV1(data: []u8) void {
    var reader = Bytes.init(data);
    var word_no:u16 = 0;
    while (reader.peek(u8) < 0xF0) : (word_no += 1) {
        const start = reader.pos;
        while (reader.read(u8) & 0x80 == 0) {}
        reader.data[reader.pos-1] &= 0x7F;
        const word = reader.data[start..reader.pos];
        const value = reader.read(u8);
        words[word_no] = .{.word = word, .value = value};
    }
}

fn toUpper(word: []u8) void {
    for (word) |*char| {
        if ((char.* >= 'a') and (char.* <= 'z')) char.* &= 0xDF;
    }
}

fn equal(first: []u8, second: []u8) bool {
    if (first.len > second.len) return false;
    for (first) |char, pos| {
        if (second[pos] != char) return false;
    }
    return true;
}

pub fn lookup(word: []u8) ?u8 {
    toUpper(word);
    for (words) |entry| {
        if (equal(word, entry.word)) return entry.value;
    }
    return null;
}

const CharReader = struct {
    data: Bytes,
    buffer: u32 = 0,
    bits: u8 = 0,

    fn read(self: *CharReader, comptime T: type) T {
        const bits_needed = @bitSizeOf(T);
        while (self.bits < bits_needed) {
            self.buffer = (self.buffer << 8) | self.data.read(u8);
            self.bits += 8;
        }
        const shifted = self.buffer >> @truncate(u5, self.bits - bits_needed);
        const value = @truncate(T, shifted);
        self.bits -= bits_needed;
        return value;
    }

    fn eof(self: *CharReader) bool {
        return (self.bits < 5) and self.data.eof();
    }

    fn clear(self: *CharReader) void {
        self.buffer = 0;
        self.bits = 0;
    }
};

pub var word_list: [0xF80][]u8 = undefined;
var word_buffer: [100000]u8 = undefined;

fn buildV3(data: []u8) void {
    var word_buffer_pos: u16 = 0;
    var word_no: u16 = 0;
    var word: [20]u8 = [_]u8{' '} ** 20;
    var word_pos:u8 = 0;
    var reader = CharReader{.data = Bytes.init(data)};
    while (!reader.eof()) {
        var char: u8 = reader.read(u5);
        if (char > 0x1A and word_pos > 0) {
            std.mem.copy(u8, word_buffer[word_buffer_pos..], word[0..word_pos]);
            word_list[word_no] = word_buffer[word_buffer_pos..word_buffer_pos+word_pos];
            word_no += 1;
            word_buffer_pos += word_pos;
        }
        switch (char) {
            0...0x19 => {
            word[word_pos] = (char + 0x61) & 0xFF;
            word_pos += 1;
            },
            0x1A => {
                const big_char = reader.read(u10);
                if (big_char >= 0x80) {
                    io.log.write(119);
                }
                char = @truncate(u7, big_char);
                word[word_pos] = char;
                word_pos += 1;
            },
            0x1B => {
                word_pos = 0;
                reader.clear();
            },
            else => word_pos = char & 0x03
        }
    }
    io.log.write(word_no);
    io.log.write(word_buffer_pos);
}