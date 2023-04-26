const Header = @import("Header.zig");
const Bytes = @import("Bytes.zig");
const io = @import("io.zig");
const dictionary = @import("dictionary.zig");
var buffer: Bytes = undefined;
var empty: bool = true;

pub fn init(header: Header) void {
    dictionary.init(header);
}

pub fn readWord() ?u8 {
    while (empty) {
        const data = await async io.input.read();
        buffer = Bytes.init(data);
        if (!buffer.eof()) empty = false;
    }
    while (true) {
        if (getWord()) |word| {
            if (dictionary.lookup(word)) |value|
                return value;
        } else {
            empty = true;
            return null;
        }
    }
}

fn skipSpace() usize {
    while (!buffer.eof() and buffer.peek(u8) == ' ') buffer.seekBy(1);
    return buffer.pos;
}

fn skipWord() usize {
    while (!buffer.eof() and buffer.peek(u8) != ' ') buffer.seekBy(1);
    return buffer.pos;
}

fn getWord() ?[]u8 {
    const start = skipSpace();
    if (buffer.eof()) return null;
    const end = skipWord();
    const word = buffer.getSlice(start, end);
    return word;
}