const Header = @import("Header.zig");
const Bytes = @import("Bytes.zig");
const messages = @import("messages.zig");
const WordList = @import("WordList.zig");
const MessageWords = @import("MessageWords.zig");
const InputDictionary = @import("InputDictionary.zig");
const io = @import("js.zig");

pub const WordType = union(enum) {
    Literal: u8,
    Match: *List,
};

pub const List = struct {
    size: u16 = 0,
    data: [50]u16 = undefined,

    pub fn append(self: *List, value: u16) void {
        self.data[self.size] = value;
        self.size += 1;
    }

    pub fn get(self: *List) []u16 {
        return self.data[0..self.size];
    }
};

pub fn init(header: Header) void {
    InputDictionary.init();
    const dict = header.dictionary;
    build(dict);
}

var input_matches: [0xF80]List = undefined;

fn build(data: []u8) void {
    for (&input_matches) |*list| {
       list.size = 0;
    }
    WordList.init(data);
    buildMatches();
    for (WordList.word_list, 0..) |word, pos| {
        if (input_matches[pos].size > 0) {
            InputDictionary.append(word, @truncate(pos));
        }
    }
}

fn buildMatches() void {
    for (messages.message_table[0..messages.num_messages], 0..) |message, message_no| {
        var message_words = MessageWords.init(message);
        while (message_words.next()) |word_data| {
            if ((word_data.word < 0xF80 and word_data.flags > 0)) {
                input_matches[word_data.word].append((@as(u16, word_data.flags) << 13) | @as(u12, @truncate(message_no)));
            }
        }
    }
}

pub fn lookup(word: []u8) WordType {
    if (word.len == 1 and (word[0] == '.' or word[0] == ',')) {
        return WordType{.Literal = word[0]};
    }
    if (InputDictionary.find(word)) |value| {
        return WordType{.Match = &input_matches[value]};
    }
    return if (toInt(word)) |value| WordType{.Literal = value}
    else WordType{.Literal = 0x80};
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
