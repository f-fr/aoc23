// Advent of code 23 - day 06
const std = @import("std");
const aoc = @import("aoc");

fn solve(t: u64, d: u64) u64 {
    var l: u64 = 0;
    var r = t / 2 + 1;

    while (l + 1 < r) {
        const m = (l + r) / 2;
        if (m * (t - m) <= d)
            l = m
        else
            r = m;
    }
    const min = r;

    l = t / 2 - 1;
    r = t;
    while (l + 1 < r) {
        const m = (l + r) / 2;
        if (m * (t - m) <= d)
            r = m
        else
            l = m;
    }
    const max = l;

    return max - min + 1;
}

pub fn run(lines: *aoc.Lines) ![2]u64 {
    var arena = std.heap.ArenaAllocator.init(aoc.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    var buf: [100]u8 = undefined;
    const ltimes = try aoc.splitN(2, try lines.next() orelse return error.MissingTimes, ":");
    const times = try aoc.toNumsAnyA(u64, a, ltimes[1], " ");
    const nt = ltimes[1].len - std.mem.replace(u8, ltimes[1], " ", "", &buf);
    const t2 = try aoc.toNum(u64, buf[0..nt]);

    const ldists = try aoc.splitN(2, try lines.next() orelse return error.MissingDists, ":");
    const dists = try aoc.toNumsAnyA(u64, a, ldists[1], " ");
    const nd = ldists[1].len - std.mem.replace(u8, ldists[1], " ", "", &buf);
    const d2 = try aoc.toNum(u64, buf[0..nd]);

    var score1: u64 = 1;
    for (times, dists) |t, d| {
        score1 *= solve(t, d);
    }

    const score2 = solve(t2, d2);

    return .{ score1, score2 };
}

pub fn main() !void {
    return aoc.run("06", run);
}

test "Day 06 part 1" {
    const EXAMPLE1 =
        \\Time:      7  15   30
        \\Distance:  9  40  200
    ;
    const PART1: u64 = 288;

    var lines = try aoc.Lines.initBuffer(EXAMPLE1);
    defer lines.deinit();
    const scores = try run(&lines);

    try std.testing.expectEqual(PART1, scores[0]);
}

test "Day 06 part 2" {
    const EXAMPLE2 =
        \\Time:      7  15   30
        \\Distance:  9  40  200
    ;
    const PART2: u64 = 71503;

    var lines = try aoc.Lines.initBuffer(EXAMPLE2);
    defer lines.deinit();
    const scores = try run(&lines);

    try std.testing.expectEqual(PART2, scores[1]);
}
