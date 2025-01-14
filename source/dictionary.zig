const Header = @import("Header.zig");
const Bytes = @import("Bytes.zig");
const messages = @import("messages.zig");
const WordList = @import("WordList.zig");
const MessageWords = @import("MessageWords.zig");
const InputDictionary = @import("InputDictionary.zig");
var version: u8 = 0;

pub const WordType = union(enum) {
    LiteralV3: u8,
    MatchV3: *List,
    MatchV1: u8,
};

pub const List = struct {
    size: u16 = 0,
    data: [30]u16 = undefined,

    pub fn append(self: *List, value: u16) void {
        self.data[self.size] = value;
        self.size += 1;
    }

    pub fn get(self: *List) []u16 {
        return self.data[0..self.size];
    }
};

pub fn init(header: Header) void {
    version = header.version;
    InputDictionary.init();
    if (header.version <= 2) buildV1(header.dictionary)
     else buildV3(header.dictionary);
}

//// V1

fn buildV1(data: []u8) void {
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

//// V3

var input_matches: [0xF80]List = undefined;

fn buildV3(data: []u8) void {
    for (input_matches) |*list| {
        list.size = 0;
    }
    buildMatches();
    WordList.init(data);
    for (WordList.word_list, 0..) |word, pos| {
        if (input_matches[pos].size > 0) {
            InputDictionary.append(word, @truncate(pos));
        }
    }
}

fn buildMatches() void {
    for (messages.message_table, 0..) |message, message_no| {
        var message_words = MessageWords.init(message);
        while (message_words.next()) |word_data| {
            const flags = word_data >> 12;
            const word = word_data & 0xFFF;
            if ((word < 0xF80 and flags > 0)) {
                input_matches[word].append((flags << 13) | @as(u12, @truncate(message_no)));
            }
        }
    }
}

fn toInt(word: []u8) ?u8 {
    if (word.len > 3) return null;
    var number: u16 = 0;
    for (word) |char| {
        if (char < '0' or char > '9') return null;
        number = 10*number + (char - '0');
    }
    if (number > 255) return null;
    return @truncate(number);
}

//// Utility

pub fn lookup(word: []u8) WordType {
    if (word.len == 1 and (word[0] == '.' or word[0] == ',')) {
        return WordType{.LiteralV3 = word[0]};
    }
    if (InputDictionary.find(word)) |value| {
        if (version > 2) return WordType{.MatchV3 = &input_matches[value]}
        else return WordType{.MatchV1 = @truncate(value)};
    }
    const as_number = toInt(word);
    return if (as_number) |value| WordType{.LiteralV3 = value}
    else WordType{.LiteralV3 = 0x80};
}
