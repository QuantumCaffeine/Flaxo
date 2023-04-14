const game = @import("game.zig");
const messages = @import("messages.zig");
const static_memory = @import("static_memory.zig");
const io = @import("io.zig");
const state = @import("state.zig");
extern fn console_log(value: usize) void;

fn StackOf(comptime T: type) type {
    return struct {
        const Self = @This();
        stack: [*]T,
        pos: u16 = 0,

        fn init(data: [*]T) Self {
            return Self{ .stack = data };
        }

        fn push(self: *Self, value: T) void {
            self.stack[self.pos] = value;
            self.pos += 1;
        }

        fn pop(self: *Self) T {
            self.pos -= 1;
            return self.stack[self.pos];
        }

        fn clear(self: *Self) void {
            self.pos = 0;
        }
    };
}

const Address = [*]u8;

fn get_input() bool {
    return false;
}

const Code = struct {
    pc: Address,
    call_stack: StackOf(Address) = StackOf(Address).init(&static_memory.call_stack_data),

    fn readByte(self: *Code) u8 {
        const result = self.pc[0];
        self.pc += 1;
        return result;
    }

    fn readShort(self: *Code) u16 {
        const result = self.pc[0] | (@as(u16, self.pc[1]) << 8);
        self.pc += 2;
        return result;
    }

    fn readConstant(self: *Code, byte_const: bool) u16 {
        return if (byte_const) self.readByte() else self.readShort();
    }

    fn readAddress(self: *Code, relative: bool) Address {
        if (relative) {
            const offset = self.readByte();
            return if (offset > 127) self.pc + offset - 257 else self.pc + offset - 1;
        } else {
            return game.code_start + self.readShort();
        }
    }

    fn readVar(self: *Code) u16 {
        const variable = self.readByte();
        return state.vars[variable];
    }

    fn storeInVar(self: *Code, value: u16) void {
        const variable = self.readByte();
        state.vars[variable] = value;
    }

    fn incVarBy(self: *Code, value: u16) void {
        const variable = self.readByte();
        state.vars[variable] += value;
    }

    fn decVarBy(self: *Code, value: u16) void {
        const variable = self.readByte();
        state.vars[variable] -= value;
    }

    fn storeExit(self: *Code, exit: game.Exit) void {
        self.storeInVar(exit.flags);
        self.storeInVar(exit.room);
    }

    fn jump(self: *Code, condition: bool, relative: bool) void {
        const addr = self.readAddress(relative);
        if (condition) self.pc = addr;
    }

    fn call(self: *Code, relative: bool) void {
        const addr = self.readAddress(relative);
        self.call_stack.push(self.pc);
        self.pc = addr;
    }

    fn ret(self: *Code) void {
        self.pc = self.call_stack.pop();
    }
};

const Arguments = struct { arg1: u16 = 0, arg2: u16 = 0 };
const Opcode = packed struct(u8) { value: u5, rel_addr: bool, byte_const: bool, is_list: bool };
const ListOpcode = packed struct(u8) { list_num: u5, opcode: u2, is_list: bool };

pub const Engine = struct {
    code: Code,
    running: bool = true,

    pub fn init(start: [*]u8) Engine {
        return Engine{ .code = Code{ .pc = start } };
    }

    pub fn run(self: *Engine) void {
        while (self.running) {
            const opcode = @bitCast(Opcode, self.code.readByte());
            if (opcode.is_list) {
                const args = Arguments{ .arg1 = self.code.readByte(), .arg2 = self.code.readByte() };
                Engine.executeListOpcode(@bitCast(ListOpcode, opcode), args);
            } else {
                const args = self.readArgs(opcode);
                self.executeOpcode(opcode, args);
            }
        }
    }

    fn readArgs(self: *Engine, opcode: Opcode) Arguments {
        return switch (opcode.value) {
            0x03, 0x04, 0x09, 0x0A, 0x0B => .{ .arg1 = self.code.readVar() },
            0x05, 0x08 => .{ .arg1 = self.code.readConstant(opcode.byte_const) },
            0x10, 0x11, 0x12, 0x13 => .{ .arg1 = self.code.readVar(), .arg2 = self.code.readVar() },
            0x18, 0x19, 0x1A, 0x1B => .{ .arg1 = self.code.readVar(), .arg2 = self.code.readConstant(opcode.byte_const) },
            0x0F => .{ .arg1 = self.code.readByte(), .arg2 = self.code.readByte() },
            else => .{},
        };
    }

    fn executeOpcode(self: *Engine, opcode: Opcode, args: Arguments) void {
        switch (opcode.value) {
            0x00 => self.code.jump(true, opcode.rel_addr),
            0x01 => self.code.call(opcode.rel_addr),
            0x02 => self.code.ret(),
            0x03 => io.printNumber(args.arg1),
            0x04, 0x05 => messages.print(args.arg1),
            0x06 => self.extended(),
            0x07 => self.running = get_input(),
            0x08, 0x09 => self.code.storeInVar(args.arg1),
            0x0A => self.code.incVarBy(args.arg1),
            0x0B => self.code.decVarBy(args.arg1),
            0x0F => self.code.storeExit(game.exits[args.arg1][args.arg2]),
            0x10, 0x18 => self.code.jump(args.arg1 == args.arg2, opcode.rel_addr),
            0x11, 0x19 => self.code.jump(args.arg1 != args.arg2, opcode.rel_addr),
            0x12, 0x1A => self.code.jump(args.arg1 < args.arg2, opcode.rel_addr),
            0x13, 0x1B => self.code.jump(args.arg1 > args.arg2, opcode.rel_addr),
            else => illegal(opcode.value),
        }
    }

    fn executeListOpcode(opcode: ListOpcode, args: Arguments) void {
        const list = game.lists[opcode.list_num];
        switch (opcode.opcode) {
            0 => list[args.arg1] = state.vars[args.arg2],
            1 => state.vars[args.arg2] = list[state.vars[args.arg1]],
            2 => state.vars[args.arg2] = list[args.arg1],
            3 => list[state.vars[args.arg1]] = state.vars[args.arg2],
        }
    }

    fn extended(self: *Engine) void {
        const opcode = self.code.readByte();
        switch (opcode) {
            0x01 => driver(),
            0x02 => self.code.storeInVar(42),
            0x03 => save(),
            0x04 => restore(),
            0x05 => state.clearVars(),
            0x06 => self.code.call_stack.clear(),
            0xFA => printString(),
            else => illegal(opcode),
        }
    }
};

fn driver() void {
    console_log(200);
}

fn save() void {
    console_log(201);
}

fn restore() void {
    console_log(202);
}

fn printString() void {
    console_log(205);
}

fn illegal(value: u8) void {
    console_log(value);
}
