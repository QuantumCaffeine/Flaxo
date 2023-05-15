const Header = @import("Header.zig");
const Bytes = @import("Bytes.zig");
const dictionary = @import("dictionaryV1.zig");
const FixedArrayBufferOf = @import("FixedArrayBufferOf.zig").FixedArrayBufferOf;

var buffer: Bytes = undefined;

pub fn init(header: Header) void {
    dictionary.init(header);
}

pub fn parseWords(input: [] u8) []const u16 {
    buffer = Bytes.init(input);
    var words = FixedArrayBufferOf(u16, 3){};
    while (!words.full()) {
        if (getWord()) |word| {
            if (dictionary.lookup(word)) |value| {
                words.append(value);
            }
        } else break;
    }
    return words.get();
}

fn getWord() ?[]u8 {
    const begin = skipSpace();
    if (buffer.eof()) return null;
    const end = skipWord();
    const word = buffer.getSlice(begin, end);
    return word;
}

fn skipSpace() usize {
    while (!buffer.eof() and buffer.peek(u8) == ' ') buffer.seekBy(1);
    return buffer.pos;
}

fn skipWord() usize {
    while (!buffer.eof() and buffer.peek(u8) != ' ') buffer.seekBy(1);
    return buffer.pos;
}

