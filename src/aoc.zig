const std = @import("std");
const testing = std.testing;

pub var allocator_instance = std.heap.GeneralPurposeAllocator(.{}){};
pub var allocator = if (@import("builtin").is_test) testing.allocator else allocator_instance.allocator();

pub const Err = error{
    MissingProgramName,
    InvalidProgramName,
    InvalidInstanceNumber,
};

pub const SplitErr = error{
    TooManyElementsForSplit,
    TooFewElementsForSplit,
};

pub const Grid = struct {
    /// Number of rows
    n: usize,
    /// Number of columns
    m: usize,
    /// The data in row-major order
    data: []u8,

    /// Return the linear offset of the element at (i, j).
    pub fn offset(grid: *const Grid, i: usize, j: usize) usize {
        return grid.m * i + j;
    }

    /// Return the character at position (i, j)
    pub fn at(grid: *const Grid, i: usize, j: usize) u8 {
        return grid.data[grid.offset(i, j)];
    }

    /// Return a slice to the ith row.
    pub fn row(grid: *const Grid, i: usize) []u8 {
        return grid.data[grid.m * i .. grid.m * i + grid.m];
    }
};

pub const Lines = struct {
    file: ?std.fs.File = null,
    r: union {
        file: std.io.BufferedReader(4096, std.fs.File.Reader),
        buffer: std.io.FixedBufferStream([]const u8),
    },
    buf: [4096]u8 = undefined,

    pub fn init(filename: []const u8) !Lines {
        info("Read instance file: {s}", .{filename});

        var file = try std.fs.cwd().openFile(filename, .{ .mode = .read_only });
        errdefer file.close();

        const reader = std.io.bufferedReader(file.reader());

        return Lines{
            .file = file,
            .r = .{ .file = reader },
        };
    }

    pub fn initBuffer(buffer: []const u8) !Lines {
        return Lines{
            .r = .{ .buffer = std.io.fixedBufferStream(buffer) },
        };
    }

    pub fn deinit(self: *Lines) void {
        if (self.file) |f| f.close();
    }

    pub fn next(self: *Lines) !?[]const u8 {
        if (self.file) |_| {
            return self.r.file.reader().readUntilDelimiterOrEof(&self.buf, '\n');
        } else {
            return self.r.buffer.reader().readUntilDelimiterOrEof(&self.buf, '\n');
        }
    }

    /// Read the whole file as a grid and add an additional boundary
    /// character `boundary` around the field.
    ///
    /// The memory belongs to the caller.
    pub fn readGridWithBoundary(self: *Lines, alloc: std.mem.Allocator, boundary: u8) !Grid {
        var data = std.ArrayList(u8).init(alloc);
        defer data.deinit();

        var n: usize = 2;
        var m: usize = 0;
        while (try self.next()) |line| {
            if (m == 0) {
                m = line.len + 2;
                try data.appendNTimes(boundary, m);
            }
            try data.append(boundary);
            try data.appendSlice(line);
            try data.append(boundary);
            n += 1;
        }
        try data.appendNTimes(boundary, m);

        return .{ .n = n, .m = m, .data = try data.toOwnedSlice() };
    }
};

pub fn readLines() !Lines {
    return readLinesOfInstance(null);
}

pub fn readLinesOfExample() !Lines {
    return readLinesOfInstance(0);
}

pub fn readLinesOfInstance(instance: ?usize) !Lines {
    var args = std.process.args();
    const program = args.next() orelse return Err.MissingProgramName;
    const end = std.mem.indexOfScalar(u8, program, '_') orelse program.len;
    const day = std.fmt.parseInt(u8, std.fs.path.basename(program[0..end]), 10) catch return Err.InvalidProgramName;

    const inst = instance orelse fromarg: {
        const inst = args.next() orelse "1";
        const i = std.fmt.parseInt(usize, inst, 10) catch return Err.InvalidInstanceNumber;
        break :fromarg i;
    };

    var filename: [4096]u8 = undefined;
    return Lines.init(try std.fmt.bufPrint(&filename, "input/{d:0>2}/input{}.txt", .{ day, inst }));
}

pub fn run(name: []const u8, comptime runfn: anytype) !void {
    info("AoC23 - day {s}", .{name});
    var lines = try readLines();
    defer lines.deinit();

    const t_start = std.time.milliTimestamp();
    const scores = try runfn(&lines);
    const t_end = std.time.milliTimestamp();

    println("Part 1: {}", .{scores[0]});
    println("Part 2: {}", .{scores[1]});
    println("Time  : {d:.3}", .{@as(f64, @floatFromInt(t_end - t_start)) / 1000.0});
}

pub const info = std.log.info;

pub const print = std.debug.print;

pub fn println(comptime format: []const u8, args: anytype) void {
    print(format ++ "\n", args);
}

pub fn trim(s: []const u8) []const u8 {
    return std.mem.trim(u8, s, " \t\r\n");
}

fn genSplitN(comptime N: usize, s: []const u8, separator: []const u8, comptime tokenize: anytype) ![N][]const u8 {
    if (N == 1) return .{s};

    var result: [N][]const u8 = undefined;
    var toks = tokenize(u8, s, separator);
    var i: usize = 0;
    while (toks.next()) |tok| {
        result[i] = tok;
        i += 1;
        if (i + 1 == N) break;
    }
    result[N - 1] = toks.rest();
    // there should be a last element (even if we ignore it because we have the "rest")
    if (toks.next() == null) return SplitErr.TooFewElementsForSplit;

    return result;
}

pub fn splitN(comptime N: usize, s: []const u8, separator: []const u8) ![N][]const u8 {
    return genSplitN(N, s, separator, std.mem.tokenizeSequence);
}

pub fn splitAnyN(comptime N: usize, s: []const u8, separator: []const u8) ![N][]const u8 {
    return genSplitN(N, s, separator, std.mem.tokenizeAny);
}

test "splitN" {
    for (try splitN(6, "A B C D E F", " "), [_][]const u8{ "A", "B", "C", "D", "E", "F" }) |a, b| try testing.expectEqualSlices(u8, a, b);
    for (try splitN(6, "A B C D E F G", " "), [_][]const u8{ "A", "B", "C", "D", "E", "F G" }) |a, b| try testing.expectEqualSlices(u8, a, b);
    try testing.expectError(error.TooFewElementsForSplit, splitN(6, "A B C D E", " "));
}

pub fn toNum(comptime T: type, s: []const u8) !T {
    switch (T) {
        f32, f64 => return std.fmt.parseFloat(T, trim(s)),
        else => return std.fmt.parseInt(T, trim(s), 10),
    }
}

test "toInt" {
    try testing.expectEqual(toNum(i32, "42"), 42);
    try testing.expectEqual(toNum(i32, "  42  "), 42);
    try testing.expectError(error.InvalidCharacter, toNum(i32, "42,"));
}

test "toInt64" {
    try testing.expectEqual(toNum(i64, "42"), 42);
    try testing.expectEqual(toNum(i64, "  42  "), 42);
    try testing.expectError(error.InvalidCharacter, toNum(i64, "42,"));
}

test "toF32" {
    try testing.expectEqual(toNum(f32, "42.23"), 42.23);
    try testing.expectEqual(toNum(f32, "  -42.23  "), -42.23);
    try testing.expectError(error.InvalidCharacter, toNum(f32, "42,23"));
}

test "toF64" {
    try testing.expectEqual(toNum(f64, "42.23"), 42.23);
    try testing.expectEqual(toNum(f64, "  -42.23  "), -42.23);
    try testing.expectError(error.InvalidCharacter, toNum(f64, "42,23"));
}

fn genToMany(comptime T: type, comptime N: usize, s: []const u8, separator: []const u8, comptime tokenize: anytype) ![N]T {
    var result: [N]T = undefined;
    var toks = tokenize(u8, s, separator);
    var i: usize = 0;
    while (toks.next()) |tok| {
        if (i == N) return SplitErr.TooManyElementsForSplit;
        result[i] = try toNum(T, tok);
        i += 1;
    }
    if (i < N) return SplitErr.TooFewElementsForSplit;
    return result;
}

pub fn toNums(comptime T: type, comptime N: usize, s: []const u8, separator: []const u8) ![N]T {
    return genToMany(T, N, s, separator, std.mem.tokenizeSequence);
}

pub fn toNumsAny(comptime T: type, comptime N: usize, s: []const u8, separator: []const u8) ![N]T {
    return genToMany(T, N, s, separator, std.mem.tokenizeAny);
}

test "toInts" {
    try testing.expectEqual(toNums(u32, 6, "1, 2, 3,4,   5   ,6", ","), .{ 1, 2, 3, 4, 5, 6 });
    try testing.expectEqual(toNums(u32, 6, "1,,2,,3,4,,,,5,,,,6", ","), .{ 1, 2, 3, 4, 5, 6 });
    try testing.expectEqual(toNums(u32, 6, "1  2  3 4    5    6", " "), .{ 1, 2, 3, 4, 5, 6 });
    try testing.expectError(error.InvalidCharacter, toNums(u32, 6, "1, 2, a,4,   5   ,6", ","));
    try testing.expectError(error.InvalidCharacter, toNums(u32, 6, "1, 2, ,4,   5   ,6", ","));
    try testing.expectError(error.TooManyElementsForSplit, toNums(u32, 5, "1, 2, 3,4,   5   ,6", ","));
    try testing.expectError(error.TooFewElementsForSplit, toNums(u32, 7, "1, 2, 3,4,   5   ,6", ","));
}

fn genToManyA(comptime T: type, alloc: std.mem.Allocator, s: []const u8, separator: []const u8, comptime tokenize: anytype) ![]T {
    var result = std.ArrayList(T).init(alloc);
    defer result.deinit();

    var toks = tokenize(u8, s, separator);
    while (toks.next()) |tok| try result.append(try toNum(T, tok));

    return result.toOwnedSlice();
}

pub fn toNumsA(comptime T: type, alloc: std.mem.Allocator, s: []const u8, separator: []const u8) ![]T {
    return genToManyA(T, alloc, s, separator, std.mem.tokenizeSequence);
}

pub fn toNumsAnyA(comptime T: type, alloc: std.mem.Allocator, s: []const u8, separator: []const u8) ![]T {
    return genToManyA(T, alloc, s, separator, std.mem.tokenizeAny);
}

test "toNumsA" {
    const a = testing.allocator_instance.allocator();
    var arena = std.heap.ArenaAllocator.init(a);
    defer arena.deinit();
    const aa = arena.allocator();

    try testing.expectEqualSlices(u32, (try toNumsA(u32, aa, "1, 2, 3,4,   5   ,6", ",")), &[_]u32{ 1, 2, 3, 4, 5, 6 });
    try testing.expectEqualSlices(u32, (try toNumsA(u32, aa, "1,,2,,3,4,,,,5,,,,6", ",")), &[_]u32{ 1, 2, 3, 4, 5, 6 });
    try testing.expectEqualSlices(u32, (try toNumsA(u32, aa, "1  2  3 4    5    6", " ")), &[_]u32{ 1, 2, 3, 4, 5, 6 });
    try testing.expectError(error.InvalidCharacter, toNumsA(u32, a, "1, 2, a,4,   5   ,6", ","));
    try testing.expectError(error.InvalidCharacter, toNumsA(u32, a, "1, 2, ,4,   5   ,6", ","));
}

test "toNumsAnyA" {
    const a = testing.allocator_instance.allocator();
    var arena = std.heap.ArenaAllocator.init(a);
    defer arena.deinit();
    const aa = arena.allocator();

    try testing.expectEqualSlices(u32, (try toNumsAnyA(u32, aa, "1, 2, 3,4,   5   ,6", ", ")), &[_]u32{ 1, 2, 3, 4, 5, 6 });
    try testing.expectEqualSlices(u32, (try toNumsAnyA(u32, aa, "1,,2,,3,4,,,,5,,,,6", ",")), &[_]u32{ 1, 2, 3, 4, 5, 6 });
    try testing.expectEqualSlices(u32, (try toNumsAnyA(u32, aa, "1  2  3 4    5    6", " ")), &[_]u32{ 1, 2, 3, 4, 5, 6 });
    try testing.expectError(error.InvalidCharacter, toNumsAnyA(u32, a, "1, 2, a,4,   5   ,6", ","));
    try testing.expectError(error.InvalidCharacter, toNumsAnyA(u32, a, "1, 2, ,4,   5   ,6", ","));
}

test "toFloats" {
    try testing.expectEqual(toNums(f32, 6, "1.42, 2.42, 3.42,4.42,   5.42   ,6.42", ","), .{ 1.42, 2.42, 3.42, 4.42, 5.42, 6.42 });
    try testing.expectEqual(toNums(f32, 6, "1.42,,2.42,,3.42,4.42,,,,5.42,,,,6.42", ","), .{ 1.42, 2.42, 3.42, 4.42, 5.42, 6.42 });
    try testing.expectEqual(toNums(f32, 6, "1.42  2.42  3.42 4.42    5.42    6.42", " "), .{ 1.42, 2.42, 3.42, 4.42, 5.42, 6.42 });
    try testing.expectError(error.InvalidCharacter, toNums(f32, 6, "1.42, 2.42, a,4.42,   5.42   ,6.42", ","));
    try testing.expectError(error.InvalidCharacter, toNums(f32, 6, "1.42, 2.42, ,4.42,   5.42   ,6.42", ","));
    try testing.expectError(error.TooManyElementsForSplit, toNums(f32, 5, "1.42, 2.42, 3.42,4.42,   5.42   ,6.42", ","));
    try testing.expectError(error.TooFewElementsForSplit, toNums(f32, 7, "1.42, 2.42, 3.42,4.42,   5.42   ,6.42", ","));
}

pub fn sort(comptime T: type, items: []T) void {
    std.mem.sort(T, items, {}, std.sort.asc(T));
}
