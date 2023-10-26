const std = @import("std");
const stdout = std.io.getStdOut().writer();

const logical_block_size = 0x200; //Aka sector size
const blocks = 640;
const BlockMap = std.packed_int_array.PackedIntArrayEndian(u12, .Big, blocks);

const Self = @This();

data: []u8,
info: VolumeInfo = undefined,
map: BlockMap = undefined,

const Stream = std.io.FixedBufferStream([]u8);

const VolumeInfo = extern struct {
    magic: u16,     //Always 0xD2D7;
    init_date: u32 align(2),
    backup_date: u32 align(2),
    volume_attr: u16,
    dir_num_files: u16,
    dir_first_block: u16,
    dir_len_in_blocks: u16,
    num_allocation_blocks: u16,
    allocation_block_size: u32 align(2),
    num_bytes_to_allocate: u32 align(2),
    first_alloc_block_in_map: u16,
    next_unused_file_no: u32 align(2),
    num_unused_alloc_blocks: u16,
};

const DirectoryEntry = extern struct {
    version: u8,
    //finder_info: [16]u8,
    finder1: u32 align(1),
    finder2: u32 align(1),
    finder3: u32 align(1),
    finder4: u32 align(1),
    file_number: u32 align(1),
    data_fork_start: u16 align(1),
    data_fork_end_logical: u32 align(1),
    data_fork_end_physical: u32 align(1),
    resource_fork_start: u16 align(1),
    resource_fork_end_logical: u32 align(1),
    resource_fork_end_physical: u32 align(1),
    creation_date: u32 align(1),
    modification_date: u32 align(1),
};

const File = struct {
    name: []const u8,
    size: usize,
    block_size: usize,
    start_block: usize
};

const DirectoryIterator = struct {
    pos: usize = 0,
    volume: Self,
    block: usize,
    stream: Stream,

    pub fn next(self: *DirectoryIterator) !?File {
        if (self.pos >= self.volume.info.dir_num_files) return null;
        if (self.stream.buffer[self.stream.pos] == 0) {
            self.block += 1;
            const block_start = self.block * logical_block_size;
            self.stream = Stream{.buffer = self.volume.data[block_start..block_start + logical_block_size], .pos = 0};
        }
        if (try readDirectoryEntry(&self.stream)) |file| {
            self.pos += 1;
            return file;
        } else {
            return null;
        }
    }

    pub fn init(volume: Self, block: usize) DirectoryIterator {
        const block_start = block * logical_block_size;
        var stream = Stream{.buffer = volume.data[block_start..block_start + logical_block_size], .pos = 0};
        return DirectoryIterator{.volume = volume, .block = block, .stream = stream};
    }
};

fn readString(stream: *Stream) []const u8 {
    const length = stream.buffer[stream.pos];
    stream.pos += 1;
    const string = stream.buffer[stream.pos..stream.pos + length];
    stream.pos += length;
    return string;
}

pub fn readDirectoryEntry(stream: *Stream) !?File {
    var reader = stream.reader();
    const flags = try reader.readByte();
    if (flags == 0) return null;
    const entry = try reader.readStructBig(DirectoryEntry);
    const filename = readString(stream);
    if (stream.pos%2 != 0) stream.pos += 1;
    return File{.name = filename, .size = entry.data_fork_end_logical, .block_size = entry.data_fork_end_physical, .start_block = entry.data_fork_start};
}

pub fn readDirectory(self: Self) DirectoryIterator {
    return DirectoryIterator.init(self, self.info.dir_first_block);
}

pub fn readFile(self: Self, file: File, allocator: std.mem.Allocator) !?[]u8 {
    var current_block = file.start_block;
    if (current_block < 2) return null;
    var buffer = try allocator.alloc(u8, file.block_size);
    var stream = Stream{.buffer = buffer, .pos = 0};
    var writer = stream.writer();
    while (current_block >= 2) {
        const block_data_start = (self.info.first_alloc_block_in_map * logical_block_size) + (current_block - 2)*self.info.allocation_block_size;
        _ = try writer.write(self.data[block_data_start..block_data_start + self.info.allocation_block_size]);
        current_block = self.map.get(current_block - 2);
    }
    return buffer;
}

fn readVolumeInfo(data: []u8) !VolumeInfo {
    const start = 2*logical_block_size;
    var stream = Stream{.buffer = data[start..start + 2*logical_block_size], .pos = 0};
    var reader = stream.reader();
    var info = try reader.readStructBig(VolumeInfo);
    const volume_name = readString(&stream);
    try stdout.print("{s}\n", .{volume_name});
    return info;
}

fn readBlockMap(data: []u8) !BlockMap {
    const block_map_pos = 2*logical_block_size + 64;
    const map_length = (blocks * 3)/2;
    const map_bytes = data[block_map_pos..block_map_pos + map_length];
    return BlockMap{.bytes = map_bytes.*, .len = blocks};
} 

pub fn init(data: []u8) !Self {
    const info = try readVolumeInfo(data);
    const map = try readBlockMap(data);
    const used_blocks = info.num_allocation_blocks - info.num_unused_alloc_blocks;
    try stdout.print("Used blocks: {d}\n", .{used_blocks});
    return Self{.data = data, .info = info, .map = map};
}