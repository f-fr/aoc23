// Advent of code 23 - day 10
const std = @import("std");
const aoc = @import("aoc");

fn tile(d1: aoc.Dir, d2: aoc.Dir) ?u8 {
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
    const s = grid.findFirst('S') orelse return error.NoStart;

    const score1: usize = 0;
    _ = score1;
    const score2: usize = 0;
    _ = score2;
    for (aoc.Dirs) |sdir| {
        var p = s.step(sdir);
        const cs = grid.atPos(p);
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
        var area2: isize = 0;
        while (true) {
            cnt += 1;
            const c = if (!p.eql(s)) grid.atPos(p) else (tile(sdir, dir) orelse unreachable);
            const h: isize = @intCast(p.i);
            switch (c) {
                '-' => area2 += 2 * if (dir == .east) h else -h,
                '7', 'J' => area2 += if (dir == .east) h else -h,
                'F', 'L' => area2 += if (dir == .west) -h else h,
                '|' => {},
                else => unreachable,
            }
            const nxt_dir: aoc.Dir = switch (dir) {
                .north => switch (c) {
                    '|' => .north,
                    '7' => .west,
                    'F' => .east,
                    else => break,
                },
                .west => switch (c) {
                    '-' => .west,
                    'F' => .south,
                    'L' => .north,
                    else => break,
                },
                .south => switch (c) {
                    '|' => .south,
                    'J' => .west,
                    'L' => .east,
                    else => break,
                },
                .east => switch (c) {
                    '-' => .east,
                    '7' => .south,
                    'J' => .north,
                    else => break,
                },
            };
            if (p.eql(s)) return .{ cnt / 2, @abs(area2) / 2 + 1 - cnt / 2 };
            p = p.step(nxt_dir);
            dir = nxt_dir;
        }
    }

    return .{ 0, 0 };
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
