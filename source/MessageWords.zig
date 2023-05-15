const Bytes = @import("Bytes.zig");
const messages = @import("messages.zig");
const Header = @import("Header.zig");
const Self = @This();

const OutputWord = packed struct {
    word: u12,
    flags: u3,
    padding: u1
};

bytes: Bytes = undefined,
var word_table: Bytes = undefined;

pub fn setup(header: Header) void {
    word_table = Bytes.init(header.word_table);
}

pub fn init(message: []u8) Self {
    return Self{.bytes = Bytes.init(message)};
}

pub fn next(self: *Self) ?OutputWord {
    if (self.bytes.eof()) return null;
    const word = if (self.bytes.peek(u8) >= 0x80) @truncate(u15, self.bytes.readBig(u16))
    else word_table.getBig(u16, self.bytes.read(u8)<<1);
    return @bitCast(OutputWord, word);
}