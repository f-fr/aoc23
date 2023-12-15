// Advent of code 23 - day 14
const std = @import("std");
const aoc = @import("aoc");

// yeah, the length is hardcoded for the input size (but can easily be made dynamic)
const MaxRowPockets = 1500;
const MaxColPockets = 1464;
const Code = [MaxColPockets / 2]u8;

const Pocket = struct {
    i: u8 = 0,
    beg: u8 = 0,
    end: u8 = 0,
};

fn GenArray(comptime T: type, comptime N: usize) type {
    return struct {
        const Self = @This();

        data: [N]T = undefined,
        actives: [N]usize = undefined,
        nactives: usize = 0,

        pub fn clear(self: *Self) void {
            @memset(&self.data, 0);
            self.nactives = 0;
        }

        pub fn get(self: *const Self, i: usize) T {
            return self.data[i];
        }

        pub fn addOne(self: *Self, i: usize) void {
            if (self.data[i] == 0) {
                self.actives[self.nactives] = i;
                self.nactives += 1;
            }
            self.data[i] += 1;
        }

        pub fn items(self: *const Self) []const usize {
            return self.actives[0..self.nactives];
        }
    };
}

const PocketCnts = GenArray(u8, @max(MaxRowPockets, MaxColPockets));

fn encode(counts: *const PocketCnts) Code {
    var code: [MaxColPockets / 2]u8 = undefined;
    for (0..counts.nactives / 2) |i| {
        // hopefully 4 bits per pocket count are sufficient
        const c1 = counts.get(counts.actives[2 * i]) & 0b1111;
        const c2 = counts.get(counts.actives[2 * i + 1]) & 0b1111;
        code[i] = (c1 << 4) | c2;
    }
    return code;
}

fn scoreAfterNorth(n: usize, colpockets: []const Pocket, colcounts: *const PocketCnts) usize {
    var s: usize = 0;
    for (colpockets, 0..) |pocket, idx| {
        const a = n - pocket.beg;
        const b = a - colcounts.get(idx);
        s += a * (a + 1) / 2 - b * (b + 1) / 2;
    }
    return s;
}

fn scoreAfterWest(n: usize, rowpockets: []const Pocket, rowcounts: *const PocketCnts) usize {
    var s: usize = 0;
    for (rowpockets, 0..) |pocket, idx| {
        const c = rowcounts.get(idx);
        s += c * (n - pocket.i);
    }
    return s;
}

fn tilt(tocounts: *PocketCnts, topocketidx: []const []const usize, fromcounts: *const PocketCnts, frompockets: []const Pocket, fwd: bool) void {
    tocounts.clear();
    for (fromcounts.items()) |idx| {
        const c = fromcounts.get(idx);
        const j = frompockets[idx].i;
        const i_beg = if (fwd) frompockets[idx].beg else frompockets[idx].end - c;
        for (i_beg..i_beg + c) |i| tocounts.addOne(topocketidx[j][i]);
    }
}

pub fn run(lines: *aoc.Lines) ![2]u64 {
    var arena = std.heap.ArenaAllocator.init(aoc.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    var grid = try lines.readGrid(a);

    var rowpocketidx = try a.alloc([]usize, grid.m);
    for (0..grid.m) |i| rowpocketidx[i] = try a.alloc(usize, grid.n);

    var colpocketidx = try a.alloc([]usize, grid.n);
    for (0..grid.n) |i| colpocketidx[i] = try a.alloc(usize, grid.m);

    var rowpockets = try std.ArrayList(Pocket).initCapacity(a, MaxRowPockets);
    var rowcounts = PocketCnts{};
    var colpockets = try std.ArrayList(Pocket).initCapacity(a, MaxColPockets);
    var colcounts = PocketCnts{};

    for (0..grid.n) |i| {
        var j: usize = 0;
        while (j < grid.m) {
            while (j < grid.m and grid.at(i, j) == '#') j += 1;
            const j_beg = j;
            while (j < grid.m and grid.at(i, j) != '#') : (j += 1) {
                rowpocketidx[j][i] = rowpockets.items.len;
            }
            if (j > j_beg) rowpockets.appendAssumeCapacity(.{
                .i = @intCast(i),
                .beg = @intCast(j_beg),
                .end = @intCast(j),
            });
        }
    }

    for (0..grid.m) |j| {
        var i: usize = 0;
        while (i < grid.m) {
            while (i < grid.m and grid.at(i, j) == '#') i += 1;
            const i_beg = i;
            while (i < grid.m and grid.at(i, j) != '#') : (i += 1) {
                colpocketidx[i][j] = colpockets.items.len;
            }
            if (i > i_beg) colpockets.appendAssumeCapacity(.{
                .i = @intCast(j),
                .beg = @intCast(i_beg),
                .end = @intCast(i),
            });
        }
    }

    // fill column pockets
    colcounts.clear();
    for (0..grid.m) |j| {
        for (0..grid.n) |i| {
            if (grid.at(i, j) == 'O') colcounts.addOne(colpocketidx[i][j]);
        }
    }

    const score1 = scoreAfterNorth(grid.n, colpockets.items, &colcounts);

    var seen = std.AutoArrayHashMap(Code, usize).init(a);
    var niter: usize = 1_000_000_000;
    var iter: usize = 0;
    while (iter < niter) : (iter += 1) {
        // tilt north
        tilt(&rowcounts, rowpocketidx, &colcounts, colpockets.items, true);

        // tilt west
        tilt(&colcounts, colpocketidx, &rowcounts, rowpockets.items, true);

        // tilt south
        tilt(&rowcounts, rowpocketidx, &colcounts, colpockets.items, false);

        // tilt east
        tilt(&colcounts, colpocketidx, &rowcounts, rowpockets.items, false);

        if (niter < 1_000_000_000) continue;

        const code = encode(&colcounts);
        const entry = try seen.getOrPut(code);
        if (entry.found_existing) {
            const len = iter - entry.value_ptr.*; // length of the cycle
            const r = (1_000_000_000 - iter - 1) % len;
            niter = iter + r + 1;
        } else entry.value_ptr.* = iter;
    }

    const score2 = scoreAfterWest(grid.n, rowpockets.items, &rowcounts);

    return .{ score1, score2 };
}

pub fn main() !void {
    return aoc.run("14", run);
}

test "Day 14 part 1" {
    const EXAMPLE1 =
        \\O....#....
        \\O.OO#....#
        \\.....##...
        \\OO.#O....O
        \\.O.....O#.
        \\O.#..O.#.#
        \\..O..#O..O
        \\.......O..
        \\#....###..
        \\#OO..#....
    ;
    const PART1: u64 = 136;

    var lines = try aoc.Lines.initBuffer(EXAMPLE1);
    defer lines.deinit();
    const scores = try run(&lines);

    try std.testing.expectEqual(PART1, scores[0]);
}

test "Day 14 part 2" {
    const EXAMPLE2 =
        \\O....#....
        \\O.OO#....#
        \\.....##...
        \\OO.#O....O
        \\.O.....O#.
        \\O.#..O.#.#
        \\..O..#O..O
        \\.......O..
        \\#....###..
        \\#OO..#....
    ;
    const PART2: u64 = 64;

    var lines = try aoc.Lines.initBuffer(EXAMPLE2);
    defer lines.deinit();
    const scores = try run(&lines);

    try std.testing.expectEqual(PART2, scores[1]);
}
