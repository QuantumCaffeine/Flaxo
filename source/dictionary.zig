const Header = @import("Header.zig");
const Bytes = @import("Bytes.zig");

const Word = struct {
    word: []u8,
    value: u8
};

var words: [1000]Word = undefined;

pub fn init(header: Header) void {
    build(header.dictionary);
}

fn build(data: []u8) void {
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