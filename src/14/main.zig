// Advent of code 23 - day 14
const std = @import("std");
const aoc = @import("aoc");

const V = @Vector(2, i8);

fn score(grid: *const aoc.Grid) u64 {
    var s: usize = 0;
    for (1..grid.n - 1) |i| {
        for (1..grid.m - 1) |j| {
            if (grid.at(i, j) == 'O') s += (grid.n - 1 - i);
        }
    }
    return s;
}

fn at(grid: *const aoc.Grid, pos: V) u8 {
    const i: usize = @intCast(pos[0]);
    const j: usize = @intCast(pos[1]);
    return grid.at(i, j);
}

fn set(grid: *aoc.Grid, pos: V, c: u8) void {
    const i: usize = @intCast(pos[0]);
    const j: usize = @intCast(pos[1]);
    return grid.set(i, j, c);
}

fn tilt(grid: *aoc.Grid, dir: aoc.Dir) void {
    var start: V = undefined;
    var dir_step: V = undefined;
    var dir_next: V = undefined;
    var n: usize = undefined;
    var m: usize = undefined;
    switch (dir) {
        .north => {
            start = .{ 1, 1 };
            dir_step = .{ 1, 0 };
            dir_next = .{ 0, 1 };
            n = grid.n - 2;
            m = grid.m - 2;
        },
        .west => {
            start = .{ 1, 1 };
            dir_step = .{ 0, 1 };
            dir_next = .{ 1, 0 };
            n = grid.m - 2;
            m = grid.n - 2;
        },
        .south => {
            start = .{ @intCast(grid.n - 2), 1 };
            dir_step = .{ -1, 0 };
            dir_next = .{ 0, 1 };
            n = grid.n - 2;
            m = grid.m - 2;
        },
        .east => {
            start = .{ 1, @intCast(grid.m - 2) };
            dir_step = .{ 0, -1 };
            dir_next = .{ 1, 0 };
            n = grid.m - 2;
            m = grid.n - 2;
        },
    }

    for (0..m) |_| {
        var i: usize = 0;
        var pos = start;
        while (i < n) {
            while (i < n and at(grid, pos) == '#') : (i += 1) {
                pos += dir_step;
            }
            var ngaps: i8 = 0;
            while (i < n and at(grid, pos) != '#') : (i += 1) {
                if (at(grid, pos) == '.') {
                    ngaps += 1;
                } else if (ngaps > 0) {
                    const to = pos - dir_step * @as(V, @splat(ngaps));
                    set(grid, pos, '.');
                    set(grid, to, 'O');
                }
                pos += dir_step;
            }
        }

        start += dir_next;
    }
}

const Code = [100]u128;

fn encode(grid: *const aoc.Grid) Code {
    var code = [1]u128{0} ** 100;
    for (1..grid.n - 1) |i| {
        for (1..grid.m - 1) |j| {
            code[i - 1] = code[i - 1] << 1 | @intFromBool(grid.at(i, j) == 'O');
        }
    }
    return code;
}

pub fn run(lines: *aoc.Lines) ![2]u64 {
    var arena = std.heap.ArenaAllocator.init(aoc.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    var grid = try lines.readGridWithBoundary(a, '#');

    var score1: u64 = 0;
    var score2: u64 = 0;

    var seen = std.AutoHashMap(Code, usize).init(a);

    loop: for (0..1_000_000_000) |iter| {
        inline for (.{ .north, .west, .south, .east }) |dir| {
            tilt(&grid, dir);
            if (iter == 0 and dir == .north) score1 = score(&grid);
        }
        const code = encode(&grid);
        if (seen.get(code)) |i| {
            const len = iter - i; // length of the cycle
            const r = (1_000_000_000 - iter - 1) % len;
            // few remaining steps (this could be saved)
            for (0..r) |_| {
                inline for (.{ .north, .west, .south, .east }) |dir| tilt(&grid, dir);
            }
            score2 = score(&grid);
            break :loop;
        }
        try seen.put(code, iter);
    }

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
