// Advent of code 23 - day 11
const std = @import("std");
const aoc = @import("aoc");

pub fn run(lines: *aoc.Lines) ![2]u64 {
    var arena = std.heap.ArenaAllocator.init(aoc.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    var galaxies = try std.ArrayList(aoc.Pos).initCapacity(a, 200);
    var n: usize = 0;
    var m: usize = 0;
    var colcounts: []usize = undefined;
    var rowcounts = try std.ArrayList(usize).initCapacity(a, 200);
    while (try lines.next()) |line| {
        if (m == 0) {
            m = line.len;
            colcounts = try a.alloc(usize, m);
            @memset(colcounts, 0);
            try rowcounts.ensureTotalCapacity(m);
        }
        var emptyrow = true;
        for (line, 0..) |c, j| {
            if (c == '#') {
                try galaxies.append(.{ .i = n, .j = j });
                colcounts[j] = 1;
                emptyrow = false;
            }
        }

        try rowcounts.append(if (emptyrow) 1 else 0);
        n += 1;
    }

    for (colcounts) |*c| c.* = 1 - c.*;
    for (1..m) |j| colcounts[j] += colcounts[j - 1];
    for (1..n) |j| rowcounts.items[j] += rowcounts.items[j - 1];

    var scores = [2]u64{ 0, 0 };
    inline for (0..2, .{ 2, 1_000_000 }) |part, factor| {
        for (0..galaxies.items.len) |i| {
            var p = galaxies.items[i];
            p.i += rowcounts.items[p.i] * (factor - 1);
            p.j += colcounts[p.j] * (factor - 1);

            for (i + 1..galaxies.items.len) |j| {
                var q = galaxies.items[j];
                q.i += rowcounts.items[q.i] * (factor - 1);
                q.j += colcounts[q.j] * (factor - 1);

                scores[part] += p.dist1(q);
            }
        }
    }

    return scores;
}

pub fn main() !void {
    return aoc.run("11", run);
}

test "Day 11 part 1" {
    const EXAMPLE1 =
        \\...#......
        \\.......#..
        \\#.........
        \\..........
        \\......#...
        \\.#........
        \\.........#
        \\..........
        \\.......#..
        \\#...#.....
    ;
    const PART1: u64 = 374;

    var lines = try aoc.Lines.initBuffer(EXAMPLE1);
    defer lines.deinit();
    const scores = try run(&lines);

    try std.testing.expectEqual(PART1, scores[0]);
}

test "Day 11 part 2" {
    const EXAMPLE2 =
        \\...#......
        \\.......#..
        \\#.........
        \\..........
        \\......#...
        \\.#........
        \\.........#
        \\..........
        \\.......#..
        \\#...#.....
    ;
    const PART2: u64 = 82000210;

    var lines = try aoc.Lines.initBuffer(EXAMPLE2);
    defer lines.deinit();
    const scores = try run(&lines);

    try std.testing.expectEqual(PART2, scores[1]);
}
