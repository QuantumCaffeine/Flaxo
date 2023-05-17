const io = @import("js.zig");

const Word = struct {
    word: []const u8,
    value: u16
};

var words: [2200]Word = undefined;
var word_buffer: [20]u8 = undefined;
var pos: u16 = 0;

pub fn init() void {
    pos = 0;
}

pub fn append(word: []const u8, value: u16) void {
    words[pos] = Word{.word = word, .value = value};
    // io.log.writeString(word);
    // io.log.write(value);
    pos += 1;
    //io.log.write(pos);
}

pub fn find(word: []const u8) ?u16 {
    for (word, 0..) |char, i| {
        word_buffer[i] = char;
    }
    var upper_word = word_buffer[0..word.len];
    toUpper(upper_word);
    for (words) |entry| {
        if (equal(upper_word, entry.word)) return entry.value;
    }
    return null;
}

fn equal(first: []const u8, second: []const u8) bool {
    if (first.len > second.len) return false;
    for (first, 0..) |char, i| {
        if (toUpperChar(second[i]) != char) return false;
    }
    return true;
}

fn toUpper(word: []u8) void {
    for (word) |*char| {
        if ((char.* >= 'a') and (char.* <= 'z')) char.* &= 0xDF;
    }
}

fn toUpperChar(char: u8) u8 {
    if ((char >= 'a') and (char <= 'z')) { 
        return char & 0xDF; 
    } else {
        return char;
    }
}
