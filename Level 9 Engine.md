#Level 9 Engine Format


##Output Strings

Most game output is produced by piecing together a series of output strings, which the standard Level 9 interpreter calls messages.

###Versions 1--2

###Versions 3--4

In later games, both the string and dictionary systems became considerably more complex. A compressed list of common words was used both to build the messages and as a basis for the input dictionary. (Not all of the words were valid as input, but we'll get to that in a moment.)

#### Word List

Two compression techniques were used to store the word list compactly. First, rather than storing one character per byte, most were stored in five bits. Specifically, the 26 lower-case characters were stored in five bits each (with the remaining 6 values taken up by control codes), while all other characters used ten. Since the output routine automatically capitalised the first word of each sentence, very few ten-bit characters were needed.

Secondly, the words were stored in alphabetical order, and four of the six control codes were used to signal that up to three of the current word's initial letters were to be retained and used to build the next one. This saved significant space when storing a series of similar words.

These five- and ten-bit characters were packed together in order. For example, if the first eight characters were five-bit, they would be packed into the first five bytes as follows. (The top row shows the bits of each 8-bit byte, numbered from the highest bit 7 to the lowest bit 0. The bottom row is numbered likewise for the 5-bit characters.)

76543 210 76 54321 0 7654 3210 7 65432 10 765 43210 ...
43210 432 10 43210 4 3210 4321 0 43210 43 210 43210 ...

The 5-bit character values can be decoded as follows.

0--25 (0x00--0x19) Lowercase 'a' to 'z'

26 (0x1A) First (upper) part of a 10-bit char. The low eight bits of the resulting character are interpreted as ASCII. (Not sure what the eighth and ninth bits are used for?)

27 (0x1B) End word and clear buffer. Indicates that any remaining bits of the current byte are to be thrown away rather than used to form the upper bits of the first character of the next word.

28--31 (0x1C--0x1F) End word and retain 0 (28) to 3 (31) characters.

#### Messages

These are stored in a table consisting of each message's length (in bytes) followed by the message itself. The length is stored in a somewhat curious way, as a series of bytes where 0 adds 63 to the computed length and any value v less than 64 adds v - 1 to the length. The first non-zero byte signals the end of the process. Thus, a length of 150 would be stored as

0    0    25
63 + 63 + 24 = 150

(This basic approach is re-used elsewhere, but with different ranges. You can think of this as a 6-bit system, where 0 means 2**6 - 1 and any value v less than 2**6 adds a final v - 1 to the total.)

In addition, not all message ids are actually used, with some id blocks being left intentionally blank. If the high bit of the first length byte is set, the lower seven bits indicate the size of the block to skip.

Each message is encoded as a series of 15-bit codes, which are either word list entries or literal characters. These codes are compressed by using a 128-entry lookup table to store the most commonly-used codes. If the next byte of the message does not have its high bit set, it represents an entry in the lookup table. Otherwise, its lower seven bits represent the upper seven bits of the code, with the lower seven bits stored in the following byte.

The top three bits of each code represent flags, while the remaining twelve encode the word or character. Values less than 0xF80 represent entries in the word list, while those above 0xF80 are literal ASCII charcters. A value of exactly 0xF80 marks the end of the printable part of the message. Any further codes are used to compile the dictionary, but are not printed.

If two word codes are printed in succession, the output routine inserts a space between them. When printing character codes, it uses the middle and lower flag bits to decide whether to add a space before (middle flag bit set) and/or after (lower flag bit set) the character. (This is largely used to print punctuation corrently.)

Finally, the output routine tracks whether a sentence has just ended by checking for periods, question marks and exclamation marks in the output. If so, it capitalises the following word.

##Dictionary

###Versions 1--2

Here, each dictionary word is fed back to the engine as a single, one-byte value. The dictionary table is stored in a similarly simple way, consisting of each word (in upper case) followed by its value. The last letter of each word is marked by having its high bit set. The total number of words does not appear to be stored anywhere. Punctuation is ignored.

###Versions 3--4

In later games, the dictionary data is not stored separately. Instead, the dictionary builds on the word and message lists. Specifically, if a word appears in at least one message with one or more of its flag bits set (regardless of whether that's in the printable part of the message or not), it is added to the dictionary.

The dictionary entry for a word consists of a list of all its flagged appearances in messages. Each appearance is encoded as a 16-bit number, with the message number in the lower 12 bits and the flags in the upper 3 bits. (The 13th bit appears to be unused.)

## ACode

All the Level 9 games are built using a bytecode interpreter, the core of which remained essentially unchanged even as additional features were added over time.

### Basics

The ACode engine uses 256 16-bit global variables (or registers), no local variables, and nine arrays. Some of these arrays are read-only and stored as part of the game data, while others are stored as part of the game state. Early versions of the engine could only access these arrays by reading and writing values to and from variables, while later versions added opcodes that could read, write, and even execute them directly, giving them a limited ability to modify their own code.

There are two types of instruction: standard and array opcodes. The standard opcodes operate on the global variables, while the array opcodes transfer values between the arrays and the variables. Each opcode is stored as one byte, with the high bit determining the type: array (set) or standard (unset).

### Standard Opcodes
Standard opcodes are encoded as a 5-bit instruction with two flags, as follows.

0 ra bc instr (u5)

(The top bit is always unset, as discussed above.) The ra flag indicates whether the opcode uses relative (set) or absolute (unset) addresses, while the bc flag indicates whether any literal constant is 8-bit (set) or 16-bit (unset). Relative addresses are stored as 8-bit signed values, relative to the byte that stores the address, while absolute addresses are 16-bit values. (Thus, a relative address of 1 indicates the byte following the address.)

#### 0x00 (addr) -- Jump
Jump to addr.

#### 0x01 (addr) -- Call
Call the routine at addr. Since there are no local variables, this is essentially just a jump, but with the address following the call stored on the call stack so the routine can return.

#### 0x02 -- Return
Return from the current routine. In other words, pop the address from the top of the call stack and continue execution there.

#### 0x03 (var1) -- Print number
Output the value stored in var1 to the screen.

#### 0x04 (var1) and 0x05 (const) -- Print Message
Output the message stored in var1 or specified by const to the screen.

#### 0x06 -- Extended
Execute the following bytes as an extended opcode.

#### 0x07 (var1) (var2) (var3) (var4) -- Read Input
Read user input. 

In versions 1 and 2, the parser reads up to three words from the input (skipping any it doesn't understand and throwing away any additional input) and stores the associated dictionary entries in vars 1--3. Var4 stores the number of recognised words read.

In versions 3 and 4, the parser reads one word from the input and essentially stores its dictionary entry in Array 9 (see below for details). Unlike in versions 1 and 2, it does not throw any remaining input away, meaning that it will generally take multiple steps to fully read one command. When the current command has been completely read, it stores a value of zero to indicate end of command. The arguments (var1--var4) are ignored.

#### 0x08 (const) (var1) and 0x08 (var2) (var1) -- Store
Store const or the value of var2 in var1.

#### 0x0A (var2) (var1) -- Increment
Increment var1 by the value of var2.

#### 0x0B (var2) (var1) -- Decrement
Decrement var1 by the value of var2.

#### 0x0C and 0x0D
Unused.

#### 0x0E (const) (var1) -- Jump table
Look up the 16-bit table with absolute address const, find the entry given by the value of var1, and jump to it.

#### 0x0F (var1) (var2) (var3) (var4) -- Exit
Look up exit var2 of room var1 in the exit table, then store the flags in var4 and the destination room in var4.

#### 0x10 (var1) (var2) (addr) and 0x18 (var1) (const) (addr) -- Jump If Equal
Jump to addr if var1 equals var2/const.

#### 0x11 (var1) (var2) (addr) and 0x19 (var1) (const) (addr) -- Jump If Not Equal
Jump to addr if var1 does not equal var2/const.

#### 0x12 (var1) (var2) (addr) and 0x1A (var1) (const) (addr) -- Jump If Less
Jump to addr if var1 is less than var2/const.

#### 0x13 (var1) (var2) (addr) and 0x1B (var1) (const) (addr) -- Jump If Greater
Jump to addr if var1 is greater than var2/const.

#### 0x14 (byte1) (byte2) -- Toggle image
Toggle the image on (byte1 > 0) or off (byte1 == 0). If byte1 == 0, there is no byte2. You might think that byte2 would represent something about the image number or state, but this does not appear to be the case.

#### 0x15 (byte1) -- Clear image
Clear the canvas. Again, the argument byte1 appears to be unused.

#### 0x16 (var1) -- Draw Image
Draw image var1 to the canvas.

#### 0x17 (var1) (var2) (var3) (var4) (var5) (var6) -- Next Object
This refers to the object tree (see below).

#### 0x1C -- Print Current Word
Print the most recent word seen in the input, regardless of whether it was understood. (This is used, for example, to tell the player that the parser could not understand them.)

#### 0x1D--0x1F
Unused.


 
