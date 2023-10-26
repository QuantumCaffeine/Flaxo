const Bytes = @import("Bytes.zig");
const io = @import("io.zig");
const StringBuffer = @import("StringBuffer.zig");
const BufferOf = @import("BufferOf.zig").BufferOf;

const CharReader = struct {
    data: Bytes,
    buffer: u32 = 0,
    bits: u5 = 0,

    fn read(self: *CharReader, comptime T: type) T {
        const bits_needed = @bitSizeOf(T);
        while (self.bits < bits_needed) {
            self.buffer = (self.buffer << 8) | self.data.read(u8);
            self.bits += 8;
        }
        self.bits -= bits_needed;
        return @truncate(self.buffer >> self.bits);
    }

    fn eof(self: *CharReader) bool {
        return (self.bits < 5) and self.data.eof();
    }

    fn clear(self: *CharReader) void {
        self.buffer = 0;
        self.bits = 0;
    }
};

var word_buffer: [100000]u8 = undefined;
pub var word_list: [0xF80][]u8 = undefined;

pub fn init(data: []u8) void {
    var buffer = StringBuffer.init(&word_buffer);
    var word_list_buffer = BufferOf([]u8).init(&word_list);
    var reader = CharReader{.data = Bytes.init(data)};
    while (!reader.eof()) {
        const char: u8 = reader.read(u5);
        if (char > 0x1A and !buffer.empty()) {
            word_list_buffer.append(buffer.end());
            buffer.begin();
        }
        switch (char) {
            0...0x19 => buffer.append(char +% 0x61),
            0x1A => {
                //If first 5-bit char is 0x10, apply wordcase then read a new char?
                const big_char = reader.read(u10);
                if (big_char >= 0x80) io.log.write(119);
                buffer.append(big_char);
            },
            0x1B => reader.clear(),
            0x1D...0x1F => {
                const kept_chars = char & 0x03;
                buffer.appendSlice(word_list_buffer.tail()[0..kept_chars]);
            },
            else => {}
        }
    }
}
