const Header = @import("Header.zig");
const Bytes = @import("Bytes.zig");
const InputDictionary = @import("InputDictionary.zig");

pub fn init(header: Header) void {
    InputDictionary.init();
    build(header.dictionary);
}

fn build(data: []u8) void {
    var reader = Bytes.init(data);
    while (reader.peek(u8) < 0xF0) {
        const start = reader.pos;
        while (reader.read(u8) & 0x80 == 0) {}
        reader.data[reader.pos-1] &= 0x7F;
        const word = reader.data[start..reader.pos];
        const value = reader.read(u8);
        InputDictionary.append(word, value);
    }
}

pub fn lookup(word: []u8) ?u16 {
    return InputDictionary.find(word);
}