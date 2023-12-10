// Advent of code 23 - day 10
const std = @import("std");
const aoc = @import("aoc");
const debug = @import("builtin").mode == .Debug;

const Dir = enum { north, west, south, east };
const Pos = struct { i: usize, j: usize };

fn find(grid: *const aoc.Grid, ch: u8) ?Pos {
    for (0..grid.n) |i| {
        for (0..grid.m) |j| {
            if (grid.at(i, j) == ch) return .{ .i = i, .j = j };
        }
    }
    return null;
}

fn step(p: Pos, dir: Dir) Pos {
    return switch (dir) {
        .north => .{ .i = p.i - 1, .j = p.j },
        .west => .{ .i = p.i, .j = p.j - 1 },
        .south => .{ .i = p.i + 1, .j = p.j },
        .east => .{ .i = p.i, .j = p.j + 1 },
    };
}

fn tile(d1: Dir, d2: Dir) ?u8 {
    if (d1 == .north and d2 == .north) return '|';
    if (d1 == .north and d2 == .west) return 'L';
    if (d1 == .north and d2 == .east) return 'J';

    if (d1 == .east and d2 == .north) return 'F';
    if (d1 == .east and d2 == .south) return 'L';
    if (d1 == .east and d2 == .east) return '-';

    if (d1 == .south and d2 == .south) return '|';
    if (d1 == .south and d2 == .west) return 'F';
    if (d1 == .south and d2 == .east) return '7';

    if (d1 == .west and d2 == .north) return '7';
    if (d1 == .west and d2 == .south) return 'J';
    if (d1 == .west and d2 == .west) return '-';

    return null;
}

pub fn run(lines: *aoc.Lines) ![2]u64 {
    var arena = std.heap.ArenaAllocator.init(aoc.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const grid = try lines.readGridWithBoundary(a, '.');
    var loop = try grid.dupe(a);

    const s = find(&grid, 'S') orelse return error.NoStart;

    var score1: usize = 0;
    var score2: usize = 0;
    sdir: for ([_]Dir{ .north, .west, .south, .east }) |sdir| {
        loop.setAll('.');
        var p: Pos = step(s, sdir);
        const cs = grid.at(p.i, p.j);
        switch (sdir) {
            .north => switch (cs) {
                '|', 'F', '7' => {},
                else => continue,
            },
            .west => switch (cs) {
                '-', 'F', 'L' => {},
                else => continue,
            },
            .south => switch (cs) {
                '|', 'L', 'J' => {},
                else => continue,
            },
            .east => switch (cs) {
                '-', '7', 'J' => {},
                else => continue,
            },
        }

        var dir = sdir;
        var cnt: usize = 0;
        while (p.i != s.i or p.j != s.j) {
            const c = grid.at(p.i, p.j);
            loop.set(p.i, p.j, c);
            const nxt_dir: Dir = switch (dir) {
                .north => switch (c) {
                    '|' => .north,
                    '7' => .west,
                    'F' => .east,
                    else => continue :sdir,
                },
                .west => switch (c) {
                    '-' => .west,
                    'F' => .south,
                    'L' => .north,
                    else => continue :sdir,
                },
                .south => switch (c) {
                    '|' => .south,
                    'J' => .west,
                    'L' => .east,
                    else => continue :sdir,
                },
                .east => switch (c) {
                    '-' => .east,
                    '7' => .south,
                    'J' => .north,
                    else => continue :sdir,
                },
            };
            p = step(p, nxt_dir);
            dir = nxt_dir;
            cnt += 1;
        }

        loop.set(s.i, s.j, tile(sdir, dir) orelse unreachable);

        score1 = (cnt + 1) / 2;

        var cnt_in: usize = 0;
        for (0..loop.n) |i| {
            var in = false;
            var onpipe: u8 = '.';
            for (0..loop.m) |j| {
                switch (loop.at(i, j)) {
                    '.' => {
                        cnt_in += @intFromBool(in and onpipe == '.');
                        if (debug and in and onpipe == '.') loop.set(i, j, '*');
                    },
                    '|' => in = !in,
                    'L' => onpipe = 'L',
                    'F' => onpipe = 'F',
                    '7' => {
                        if (onpipe == 'L') in = !in;
                        onpipe = '.';
                    },
                    'J' => {
                        if (onpipe == 'F') in = !in;
                        onpipe = '.';
                    },
                    '-' => if (onpipe == '.') unreachable,
                    else => unreachable,
                }
            }
        }

        score2 = cnt_in;

        if (debug) {
            for (0..loop.n) |i| {
                for (0..loop.m) |j| {
                    const c = switch (loop.at(i, j)) {
                        '-' => "─",
                        '|' => "│",
                        '7' => "┐",
                        'F' => "┌",
                        'J' => "┘",
                        'L' => "└",
                        '*' => "█",
                        else => " ",
                    };
                    std.debug.print("{s}", .{c});
                }
                std.debug.print("\n", .{});
            }
        }

        break;
    }

    return .{ score1, score2 };
}

pub fn main() !void {
    return aoc.run("10", run);
}

test "Day 10 part 1 - example 1" {
    const EXAMPLE1 =
        \\-L|F7
        \\7S-7|
        \\L|7||
        \\-L-J|
        \\L|-JF
    ;
    const PART1: u64 = 4;

    var lines = try aoc.Lines.initBuffer(EXAMPLE1);
    defer lines.deinit();
    const scores = try run(&lines);

    try std.testing.expectEqual(PART1, scores[0]);
}

test "Day 10 part 1 - example 2" {
    const EXAMPLE1 =
        \\7-F7-
        \\.FJ|7
        \\SJLL7
        \\|F--J
        \\LJ.LJ
    ;
    const PART1: u64 = 8;

    var lines = try aoc.Lines.initBuffer(EXAMPLE1);
    defer lines.deinit();
    const scores = try run(&lines);

    try std.testing.expectEqual(PART1, scores[0]);
}

test "Day 10 part 2 - example 1" {
    const EXAMPLE2 =
        \\...........
        \\.S-------7.
        \\.|F-----7|.
        \\.||.....||.
        \\.||.....||.
        \\.|L-7.F-J|.
        \\.|..|.|..|.
        \\.L--J.L--J.
        \\...........
    ;
    const PART2: u64 = 4;

    var lines = try aoc.Lines.initBuffer(EXAMPLE2);
    defer lines.deinit();
    const scores = try run(&lines);

    try std.testing.expectEqual(PART2, scores[1]);
}

test "Day 10 part 2 - example 2" {
    const EXAMPLE2 =
        \\.F----7F7F7F7F-7....
        \\.|F--7||||||||FJ....
        \\.||.FJ||||||||L7....
        \\FJL7L7LJLJ||LJ.L-7..
        \\L--J.L7...LJS7F-7L7.
        \\....F-J..F7FJ|L7L7L7
        \\....L7.F7||L7|.L7L7|
        \\.....|FJLJ|FJ|F7|.LJ
        \\....FJL-7.||.||||...
        \\....L---J.LJ.LJLJ...
    ;
    const PART2: u64 = 8;

    var lines = try aoc.Lines.initBuffer(EXAMPLE2);
    defer lines.deinit();
    const scores = try run(&lines);

    try std.testing.expectEqual(PART2, scores[1]);
}

test "Day 10 part 2 - example 3" {
    const EXAMPLE2 =
        \\FF7FSF7F7F7F7F7F---7
        \\L|LJ||||||||||||F--J
        \\FL-7LJLJ||||||LJL-77
        \\F--JF--7||LJLJ7F7FJ-
        \\L---JF-JLJ.||-FJLJJ7
        \\|F|F-JF---7F7-L7L|7|
        \\|FFJF7L7F-JF7|JL---7
        \\7-L-JL7||F7|L7F-7F7|
        \\L.L7LFJ|||||FJL7||LJ
        \\L7JLJL-JLJLJL--JLJ.L
    ;
    const PART2: u64 = 10;

    var lines = try aoc.Lines.initBuffer(EXAMPLE2);
    defer lines.deinit();
    const scores = try run(&lines);

    try std.testing.expectEqual(PART2, scores[1]);
}
