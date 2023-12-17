const std = @import("std");
const testing = std.testing;

pub const GenArray = @import("./genary.zig").GenArray;
pub const Search = @import("./search.zig").Search;
pub const PriQueue = @import("./priqueue.zig");

//pub var allocator_instance = std.heap.GeneralPurposeAllocator(.{}){};
// 1.5 MiB of memory for dynamic allocation
var mem_buffer: [1024 * 1024 * 100]u8 = undefined;
pub var allocator_instance = std.heap.FixedBufferAllocator.init(&mem_buffer);
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

pub const Dir = enum { north, west, south, east };
pub const Dirs = std.enums.values(Dir);

pub const Pos = struct {
    i: usize,
    j: usize,

    pub fn eql(a: Pos, b: Pos) bool {
        return a.i == b.i and a.j == b.j;
    }

    pub fn step(p: Pos, dir: Dir) Pos {
        return switch (dir) {
            .north => .{ .i = p.i - 1, .j = p.j },
            .west => .{ .i = p.i, .j = p.j - 1 },
            .south => .{ .i = p.i + 1, .j = p.j },
            .east => .{ .i = p.i, .j = p.j + 1 },
        };
    }

    pub fn stepn(p: Pos, dir: Dir, n: usize) Pos {
        return switch (dir) {
            .north => .{ .i = p.i - n, .j = p.j },
            .west => .{ .i = p.i, .j = p.j - n },
            .south => .{ .i = p.i + n, .j = p.j },
            .east => .{ .i = p.i, .j = p.j + n },
        };
    }

    pub fn dist1(a: Pos, b: Pos) usize {
        return (if (a.i > b.i) a.i - b.i else b.i - a.i) +
            (if (a.j > b.j) a.j - b.j else b.j - a.j);
    }
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

    pub fn atPos(grid: *const Grid, p: Pos) u8 {
        return grid.at(p.i, p.j);
    }

    /// Return a slice to the ith row.
    pub fn row(grid: *const Grid, i: usize) []u8 {
        return grid.data[grid.m * i .. grid.m * i + grid.m];
    }

    pub fn findFirst(grid: *const Grid, ch: u8) ?Pos {
        if (std.mem.indexOfScalar(u8, grid.data, ch)) |off| {
            return .{ .i = off / grid.m, .j = off % grid.m };
        }

        return null;
    }

    pub fn setAll(grid: *Grid, c: u8) void {
        @memset(grid.data, c);
    }

    pub fn set(grid: *Grid, i: usize, j: usize, c: u8) void {
        grid.data[grid.offset(i, j)] = c;
    }

    pub fn setPos(grid: *Grid, p: Pos, c: u8) void {
        grid.set(p.i, p.j, c);
    }

    pub fn dupe(grid: *const Grid, alloc: std.mem.Allocator) !Grid {
        return Grid{
            .n = grid.n,
            .m = grid.m,
            .data = try alloc.dupe(u8, grid.data),
        };
    }
};

pub const Lines = struct {
    file: ?std.fs.File = null,
    r: union {
        file: std.io.BufferedReader(4096, std.fs.File.Reader),
        buffer: std.io.FixedBufferStream([]const u8),
    },
    buf: [4096]u8 = undefined,
    delimiter: u8 = '\n',

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
            return self.r.file.reader().readUntilDelimiterOrEof(&self.buf, self.delimiter);
        } else {
            return self.r.buffer.reader().readUntilDelimiterOrEof(&self.buf, self.delimiter);
        }
    }

    /// Read the whole file as a grid.
    pub fn readGrid(self: *Lines, alloc: std.mem.Allocator) !Grid {
        return try readNextGrid(self, alloc) orelse error.UnexpectedEndOfFile;
    }

    /// Read the next lines of a file (until an empty line or eof) as a grid.
    pub fn readNextGrid(self: *Lines, alloc: std.mem.Allocator) !?Grid {
        var data = std.ArrayList(u8).init(alloc);
        defer data.deinit();

        var n: usize = 0;
        var m: usize = 0;
        while (try self.next()) |line| {
            if (line.len == 0) break;
            if (m == 0) {
                m = line.len;
                // assume that the grid is quadratic
                try data.ensureTotalCapacity(m * m);
            } else if (m != line.len)
                return error.InvalidRowLength;
            try data.appendSlice(line);
            n += 1;
        }

        if (m == 0) return null;

        return .{ .n = n, .m = m, .data = try data.toOwnedSlice() };
    }

    /// Read the whole file as a grid and add an additional boundary
    /// character `boundary` around the field.
    ///
    /// The memory belongs to the caller.
    pub fn readGridWithBoundary(self: *Lines, alloc: std.mem.Allocator, boundary: u8) !Grid {
        return try readNextGridWithBoundary(self, alloc, boundary) orelse error.UnexpectedEndOfFile;
    }

    /// Read the next lines as a grid and add an additional boundary
    /// character `boundary` around the field.
    ///
    /// The grid ends at the next empty line or eof.
    /// Returns `null` if there is no further grid.
    ///
    /// The memory belongs to the caller.
    pub fn readNextGridWithBoundary(self: *Lines, alloc: std.mem.Allocator, boundary: u8) !?Grid {
        var data = std.ArrayList(u8).init(alloc);
        defer data.deinit();

        var n: usize = 2;
        var m: usize = 0;
        while (try self.next()) |line| {
            if (line.len == 0) break;
            if (m == 0) {
                m = line.len + 2;
                // assume that the grid is quadratic
                try data.ensureTotalCapacity(m * m);
                try data.appendNTimes(boundary, m);
            } else if (m != line.len + 2)
                return error.InvalidRowLength;
            try data.append(boundary);
            try data.appendSlice(line);
            try data.append(boundary);
            n += 1;
        }

        if (m == 0) return null;

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

    var timer = try std.time.Timer.start();
    const scores = try runfn(&lines);
    const t_end = timer.lap();

    println("Part 1: {}", .{scores[0]});
    println("Part 2: {}", .{scores[1]});
    println("Time  : {d:.3}", .{@as(f64, @floatFromInt(t_end)) / 1e9});
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
    result[i] = toks.rest();
    i += 1;
    while (i < N) : (i += 1) {
        result[i] = "";
    }

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
    for (try splitN(6, "A B C D E", " "), [_][]const u8{ "A", "B", "C", "D", "E", "" }) |a, b| try testing.expectEqualSlices(u8, a, b);
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
    std.mem.sortUnstable(T, items, {}, std.sort.asc(T));
}

/// least common multiple
pub fn lcm(a: u64, b: u64) u64 {
    return a * (b / std.math.gcd(a, b));
}

/// Extended version of Euclid's algorithm.
///
/// Returns s and t such that s*a+t*b=gcd.
pub fn gcd_ext(a: i64, b: i64) struct { gcd: i64, s: i64, t: i64 } {
    var r0 = a;
    var r1 = b;
    var s0: i64 = 1;
    var s1: i64 = 0;
    var t0: i64 = 0;
    var t1: i64 = 1;
    while (r1 != 0) {
        const q = @divFloor(r0, r1);
        const r2 = @rem(r0, r1);
        if (r2 != r0 - q * r1) unreachable;
        const s2 = s0 - q * s1;
        const t2 = t0 - q * t1;

        r0 = r1;
        r1 = r2;
        s0 = s1;
        s1 = s2;
        t0 = t1;
        t1 = t2;
    }

    if (s0 * a + t0 * b != r0) unreachable;

    return .{ .gcd = r0, .s = s0, .t = t0 };
}

pub const Crt = struct { a: u64, m: u64 };

pub fn crt(eqs: []const Crt) ?u64 {
    if (eqs.len == 0) return null;
    if (eqs.len == 1) return eqs[0].a;

    var a0: i64 = @intCast(eqs[0].a);
    var m0: i64 = @intCast(eqs[0].m);
    for (1..eqs.len) |i| {
        const a1: i64 = @intCast(eqs[i].a);
        const m1: i64 = @intCast(eqs[i].m);
        const gcd = gcd_ext(m0, m1);
        if (@rem(a0, gcd.gcd) != @rem(a1, gcd.gcd)) return null;
        const l = m0 * @divFloor(m1, gcd.gcd);
        const x = @rem(l + a0 - gcd.s * m0 * @divFloor(a0 - a1, gcd.gcd), l);
        a0 = x;
        m0 = l;
    }

    return @intCast(a0);
}

test "crt" {
    try std.testing.expectEqual(@as(?u64, 301), //
        crt(&.{
        .{ .a = 1, .m = 2 },
        .{ .a = 1, .m = 3 },
        .{ .a = 1, .m = 4 },
        .{ .a = 1, .m = 5 },
        .{ .a = 1, .m = 6 },
        .{ .a = 0, .m = 7 },
    }));

    try std.testing.expectEqual(@as(?u64, 47), //
        crt(&.{
        .{ .a = 2, .m = 3 },
        .{ .a = 3, .m = 4 },
        .{ .a = 2, .m = 5 },
    }));

    try std.testing.expectEqual(@as(?u64, 23), //
        crt(&.{
        .{ .a = 2, .m = 3 },
        .{ .a = 3, .m = 5 },
        .{ .a = 2, .m = 7 },
    }));
}

test {
    testing.refAllDecls(@This());
}
