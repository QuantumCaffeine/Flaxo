const Header = @import("Header.zig");
const Bytes = @import("Bytes.zig");
const dictionary = @import("dictionaryV3.zig");
const WordType = dictionary.WordType;

var buffer: Bytes = undefined;
pub var empty: bool = true;
pub var current_word: []u8 = undefined;

pub fn init(header: Header) void {
    dictionary.init(header);
}

pub fn start(input: []u8) void {
    buffer = Bytes.init(input);
    empty = false;
}

pub fn readWord() ?WordType {
    if (getWord()) |word| {
        current_word = word;
        return dictionary.lookup(word);
    } else {
        empty = true;
        return null;
    }
}

fn skipSpace() usize {
    while (!buffer.eof() and buffer.peek(u8) == ' ') buffer.seekBy(1);
    return buffer.pos;
}

fn is_punctuation(char: u8) bool {
    return char == '.' or char == ',' or char == ' ';
}

fn skipWord() usize {
    if (!buffer.eof() and is_punctuation(buffer.peek(u8))) {
        buffer.seekBy(1);
    } else {
        while (!buffer.eof() and !is_punctuation(buffer.peek(u8))) buffer.seekBy(1);
    }
    return buffer.pos;
}

fn getWord() ?[]u8 {
    const begin = skipSpace();
    if (buffer.eof()) return null;
    const end = skipWord();
    const word = buffer.getSlice(begin, end);
    return word;
}