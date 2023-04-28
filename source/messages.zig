const Bytes = @import("Bytes.zig");
const BufferedWriter = @import("BufferedWriter.zig");
const Header = @import("Header.zig");

var message_table: [9000][]u8 = undefined;
var num_messages: u16 = 0;
var num_abbreviations: u16 = 0;

pub var print: fn (u16, *BufferedWriter) void = undefined;

pub fn init(header: Header) void {
    var buildTable = if (header.version == 1) buildTableV1 else buildTableV2;
    num_abbreviations = buildTable(0, header.abbr_table);
    num_messages = buildTable(num_abbreviations, header.message_table);
    print = if (header.version == 1) printV1 else printV2;
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

fn readLength(table: *Bytes) u16 {
    var length: u16 = 0;
    while (table.peek(u8) == 0) : (table.seekBy(1)) length += 255;
    length += table.read(u8) - 1;
    return length;
}

fn buildTableV2(table_start: u16, data: []u8) u16 {
    var table = Bytes.init(data);
    var table_entry = table_start;
    while (true) : (table_entry += 1) {
        const length = readLength(&table);
        message_table[table_entry] = table.data[table.pos..table.pos+length];
        if (length > 0) {
            table.pos += length - 1;
            if (table.read(u8) == 2) break;
        }
    }
    return table_entry;
}

fn printMessage(message: u16, writer: *BufferedWriter) void {
    for (message_table[message]) |c| {
        switch (c) {
            0...2 => break,
            8 => writer.writeChar('\n'),
            0x42 => writer.writeChar(' '),
            0x5E...0xFF => printMessage(c - 0x5E, writer),
            else => writer.writeChar(c + 0x1D),
        }
    }
}

pub fn printV1(n: u16, writer: *BufferedWriter) void {
    printMessage(n + num_abbreviations, writer);
}

pub fn printV2(n: u16, writer: *BufferedWriter) void {
    if (n > 0) printMessage(n + num_abbreviations - 1, writer);
}
