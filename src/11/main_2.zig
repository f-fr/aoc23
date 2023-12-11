// Advent of code 23 - day 11
const std = @import("std");
const aoc = @import("aoc");

const Pos = [2]usize;

fn lessByCoord(i: usize, a: Pos, b: Pos) bool {
    return a[i] < b[i];
}

pub fn run(lines: *aoc.Lines) ![2]u64 {
    var arena = std.heap.ArenaAllocator.init(aoc.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    var galaxies = try std.ArrayList(Pos).initCapacity(a, 200);
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
                try galaxies.append(.{ n, j });
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

    const l = galaxies.items.len;
    var scores = [2]u64{ 0, 0 };
    inline for (0..2, .{ rowcounts.items, colcounts }) |i, counts| {
        std.mem.sortUnstable(Pos, galaxies.items, i, lessByCoord);
        for (1..l) |k| {
            inline for (0..2, .{ 2, 1_000_000 }) |part, factor| {
                const x1 = galaxies.items[k - 1][i];
                const x2 = galaxies.items[k][i];
                const y1: u64 = @as(u64, @intCast(x1)) + counts[x1] * (factor - 1);
                const y2: u64 = @as(u64, @intCast(x2)) + counts[x2] * (factor - 1);

                scores[part] += (y2 - y1) * k * (l - k);
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
