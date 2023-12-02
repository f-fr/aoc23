// Advent of code 23 - day 02
const std = @import("std");
const aoc = @import("aoc");

pub fn run(lines: *aoc.Lines) ![2]u64 {
    var score1: usize = 0;
    var score2: usize = 0;
    while (try lines.next()) |line| {
        var it = std.mem.tokenizeAny(u8, line, ":;, ");
        _ = it.next() orelse break; // skip "Game"
        const gid = try aoc.toNum(usize, it.next() orelse break);
        var r: usize = 0;
        var g: usize = 0;
        var b: usize = 0;
        while (it.next()) |cnt| {
            const n = try aoc.toNum(usize, cnt);
            const color = it.next() orelse "";
            if (std.mem.eql(u8, color, "red")) {
                r = @max(r, n);
            } else if (std.mem.eql(u8, color, "green")) {
                g = @max(g, n);
            } else if (std.mem.eql(u8, color, "blue")) {
                b = @max(b, n);
            } else return error.InvalidColor;
        }
        if (r <= 12 and g <= 13 and b <= 14) score1 += gid;
        score2 += r * g * b;
    }

    return .{ score1, score2 };
}

pub fn main() !void {
    return aoc.run("02", run);
}

test "Day 02 part 1" {
    const EXAMPLE1 =
        \\Game 1: 3 blue, 4 red; 1 red, 2 green, 6 blue; 2 green
        \\Game 2: 1 blue, 2 green; 3 green, 4 blue, 1 red; 1 green, 1 blue
        \\Game 3: 8 green, 6 blue, 20 red; 5 blue, 4 red, 13 green; 5 green, 1 red
        \\Game 4: 1 green, 3 red, 6 blue; 3 green, 6 red; 3 green, 15 blue, 14 red
        \\Game 5: 6 red, 1 blue, 3 green; 2 blue, 1 red, 2 green
    ;
    const PART1: u64 = 8;

    var lines = try aoc.Lines.initBuffer(EXAMPLE1);
    defer lines.deinit();
    const scores = try run(&lines);

    try std.testing.expectEqual(PART1, scores[0]);
}

test "Day 02 part 2" {
    const EXAMPLE2 =
        \\Game 1: 3 blue, 4 red; 1 red, 2 green, 6 blue; 2 green
        \\Game 2: 1 blue, 2 green; 3 green, 4 blue, 1 red; 1 green, 1 blue
        \\Game 3: 8 green, 6 blue, 20 red; 5 blue, 4 red, 13 green; 5 green, 1 red
        \\Game 4: 1 green, 3 red, 6 blue; 3 green, 6 red; 3 green, 15 blue, 14 red
        \\Game 5: 6 red, 1 blue, 3 green; 2 blue, 1 red, 2 green
    ;
    const PART2: u64 = 2286;

    var lines = try aoc.Lines.initBuffer(EXAMPLE2);
    defer lines.deinit();
    const scores = try run(&lines);

    try std.testing.expectEqual(PART2, scores[1]);
}
