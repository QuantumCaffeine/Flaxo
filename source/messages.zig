const Bytes = @import("Bytes.zig");
const BufferedWriter = @import("BufferedWriter.zig");
const Header = @import("Header.zig");
const io = @import("io.zig");
const dictionary = @import("dictionary.zig");
const BufferOf = @import("BufferOf.zig").BufferOf;
const WordList = @import("WordList.zig");
const MessageWords = @import("MessageWords.zig");

pub var message_table: [9000][]u8 = undefined;
pub var num_messages: u16 = 0;
var num_abbreviations: u16 = 0;

pub var print: *const fn (u16, *BufferedWriter) void = undefined;

pub fn init(header: Header) void {
     if (header.version <= 2) initV1(header) else initV3(header);
}

//// V1

fn initV1(header: Header) void {
    var buildTable = if (header.version == 1) &buildTableV1 else &buildTableV2;
    num_abbreviations = buildTable(0, header.abbr_table);
    num_messages = buildTable(num_abbreviations, header.message_table);
    print = if (header.version == 1) &printV1 else &printV2;
}

fn buildTableV1(table_start: u16, data: []u8) u16 {
    var table = Bytes.init(data);
    var table_entry = table_start;
    while (table.peek(u8) != 2) : (table_entry += 1) {
        const start = table.pos;
        while (table.read(u8) > 2) {}
        message_table[table_entry] = table.data[start..table.pos];
    }
    return table_entry;
}

fn buildTableV2(table_start: u16, data: []u8) u16 {
    var table = Bytes.init(data);
    var table_entry = table_start;
    while (true) : (table_entry += 1) {
        const length = readLength(u8, &table);
        message_table[table_entry] = table.data[table.pos..table.pos+length];
        if (length > 0) {
            table.pos += length - 1;
            if (table.read(u8) == 2) break;
        }
    }
    return table_entry;
}

fn printMessageV1(message: u16, writer: *BufferedWriter) void {
    for (message_table[message]) |c| {
        switch (c) {
            0...2 => break,
            8 => writer.writeChar('\n'),
            0x42 => writer.writeChar(' '),
            0x5E...0xFF => printMessageV1(c - 0x5E, writer),
            else => writer.writeChar(c + 0x1D),
        }
    }
}

pub fn printV1(n: u16, writer: *BufferedWriter) void {
    printMessageV1(n + num_abbreviations, writer);
}

pub fn printV2(n: u16, writer: *BufferedWriter) void {
    if (n > 0) printMessageV1(n + num_abbreviations - 1, writer);
}

//// V3

fn initV3(header: Header) void {
    num_messages = buildTableV3(header.message_table);
    MessageWords.setup(header);
    //io.log.write(num_messages);
    print = printMessageV3;
}

fn buildTableV3(data: []u8) u16 {
    var table = Bytes.init(data);
    var table_entry: u16 = 0;
    while (!table.eof()) : (table_entry += 1) {
        if (table.peek(u8) >= 0x80) {
            table_entry += table.read(u7);
            continue;
        }
        const length = readLength(u6, &table);        
        message_table[table_entry] = table.readSlice(length);
    }
    return table_entry;
}

var in_word = false;

pub fn printMessageV3(message: u16, writer: *BufferedWriter) void {
    var words = MessageWords.init(message_table[message]);
    while (words.next()) |word_data| {
        if (word_data.flags >= 6) {
            //if (word_data.word >= 0xF80) {
            //    io.log.write(299);
            //}
            //if (word_data.word < 0xF80) {
            //    io.log.writeString(WordList.word_list[word_data.word]);
            //    io.log.write(word_data.flags);
            //}
        }
        if (word_data.word == 0xF80) break;
        if (word_data.word < 0xF80) {
            if (in_word) writer.writeChar(' ');
            in_word = true;
            writer.writeString(WordList.word_list[word_data.word]);
        } else {
            in_word = false;
            var char = @truncate(u7, word_data.word);
            if (char == 13) char = 10;
            if (word_data.flags&0x04 != 0) {
                io.log.write(399);
            }
            if ((word_data.flags&0x02) != 0) writer.writeChar(' ');
            writer.writeChar(char);
            if ((word_data.flags&0x01) != 0) writer.writeChar(' ');
        }
    }
}

//// Utility

fn readLength(comptime T: type, table: *Bytes) u16 {
    const max_T = @as(T, 0) -% 1;
    var length: u16 = 0;
    while (table.peek(T) == 0) : (table.seekBy(1)) 
        length += max_T;
    length += table.read(T) - 1;
    return length;
}
