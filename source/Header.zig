const Bytes = @import("Bytes.zig");
const Header = @This();
const js = @import("js.zig");

version: u8,
data: []u8,
exit_table: []u8,
code: []u8,
list_table: [9]u16,
abbr_table: []u8 = undefined,
message_table: []u8,
word_table: []u8 = undefined,
dictionary: []u8 = undefined,

//Size: 0x20
const HeaderV1 = packed struct {
    message_table: u16, //0x0D7D
    abbr_table: u16, //0x470E
    exit_table: u16, //0x0020
    dictionary_start: u16, //0x02D4
    lists: [9]u16, // First one seems to be 0x50 below end of dictionary table
    code_start: u16, //0x491C
    file_length: u16, //0x5EB9
    checksum: u16, //0xA9DA Seems to be an 11-bit checksum
};

//44-byte header
const HeaderV3 = packed struct {
    file_length: u16,
    message_table: u16,
    message_table_length: u16,
    dictionary_start: u16,
    dictionary_length: u16,
    padding1: u32, //Guessing this is table for manual protection
    word_table: u16,
    padding2: u16, //Seems to be 0
    exit_table: u16,
    padding3: u16, //Seems to be 0
    lists: [9]u16,
    code_start: u16,
    padding4: u16, //Seems to be 0
};

pub fn init(version: u8, data: []u8) Header {
    var bytes = Bytes.init(data);
    if (version <= 2) {
        var header_data = bytes.get(HeaderV1, 0);
        var abbr_table_start = header_data.abbr_table;
        if (version == 2) abbr_table_start -= 1;
        return Header{
            .version = version, //
            .data = data,
            .list_table = bytes.get([9]u16, 0x08),
            .abbr_table = data[abbr_table_start..],
            .message_table = data[header_data.message_table..],
            .exit_table = data[header_data.exit_table..],
            .code = data[header_data.code_start..],
            .dictionary = data[header_data.dictionary_start..],
        };
    } else {
        var header_data = bytes.get(HeaderV3, 0);
        return Header{
            .version = version, //
            .data = data,
            .list_table = bytes.get([9]u16, 0x16),
            .message_table = data[header_data.message_table..header_data.message_table + header_data.message_table_length],
            .word_table = data[header_data.word_table..],
            .exit_table = data[header_data.exit_table..],
            .code = data[header_data.code_start..],
            .dictionary = data[header_data.dictionary_start..header_data.dictionary_start + header_data.dictionary_length],
        };
    }
}
