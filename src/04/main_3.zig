// Advent of code 23 - day 04
const std = @import("std");
const aoc = @import("aoc");

pub fn run(lines: *aoc.Lines) ![2]u64 {
    var score1: u64 = 0;
    var score2: u64 = 0;
    // all numbers have at most 2 digits
    var seen = [_]u16{0xffff} ** 100; // store the card id a number has been seen last
    var ncopies = [_]usize{1} ** 1000;
    var i: u16 = 0;
    while (try lines.next()) |line| : (i += 1) {
        const pos = std.mem.indexOf(u8, line, ":") orelse break;
        var it = std.mem.tokenizeAny(u8, line[pos + 1 ..], " |");
        var cnt: u6 = 0;
        // hopefully there are no duplicate numbers ...
        while (it.next()) |n| {
            const x = try aoc.toNum(usize, n);
            cnt += @intFromBool(seen[x] == i);
            seen[x] = i;
        }

        score1 += (@as(u64, 1) << cnt) >> 1;
        for (i + 1..i + cnt + 1) |j| ncopies[j] += ncopies[i];
        score2 += ncopies[i];
    }

    return .{ score1, score2 };
}

pub fn main() !void {
    return aoc.run("04", run);
}

test "Day 04 part 1" {
    const EXAMPLE1 =
        \\Card 1: 41 48 83 86 17 | 83 86  6 31 17  9 48 53
        \\Card 2: 13 32 20 16 61 | 61 30 68 82 17 32 24 19
        \\Card 3:  1 21 53 59 44 | 69 82 63 72 16 21 14  1
        \\Card 4: 41 92 73 84 69 | 59 84 76 51 58  5 54 83
        \\Card 5: 87 83 26 28 32 | 88 30 70 12 93 22 82 36
        \\Card 6: 31 18 13 56 72 | 74 77 10 23 35 67 36 11
    ;
    const PART1: u64 = 13;

    var lines = try aoc.Lines.initBuffer(EXAMPLE1);
    defer lines.deinit();
    const scores = try run(&lines);

    try std.testing.expectEqual(PART1, scores[0]);
}

test "Day 04 part 2" {
    const EXAMPLE2 =
        \\Card 1: 41 48 83 86 17 | 83 86  6 31 17  9 48 53
        \\Card 2: 13 32 20 16 61 | 61 30 68 82 17 32 24 19
        \\Card 3:  1 21 53 59 44 | 69 82 63 72 16 21 14  1
        \\Card 4: 41 92 73 84 69 | 59 84 76 51 58  5 54 83
        \\Card 5: 87 83 26 28 32 | 88 30 70 12 93 22 82 36
        \\Card 6: 31 18 13 56 72 | 74 77 10 23 35 67 36 11
    ;
    const PART2: u64 = 30;

    var lines = try aoc.Lines.initBuffer(EXAMPLE2);
    defer lines.deinit();
    const scores = try run(&lines);

    try std.testing.expectEqual(PART2, scores[1]);
}
