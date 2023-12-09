// Advent of code 23 - day 09
const std = @import("std");
const aoc = @import("aoc");

pub fn run(lines: *aoc.Lines) ![2]u64 {
    var nums: [100][100]i64 = undefined;
    var score1: i64 = 0;
    var score2: i64 = 0;
    while (try lines.next()) |line| {
        var it = std.mem.tokenizeScalar(u8, line, ' ');
        var n: usize = 0;
        while (it.next()) |tok| : (n += 1) {
            if (n >= 100) return error.TooManyNumbers;
            nums[0][n] = try aoc.toNum(i64, tok);
        }

        var i: usize = 1;
        while (i < n) : (i += 1) {
            var all_zero = true;
            for (0..n - i) |j| {
                nums[i][j] = nums[i - 1][j + 1] - nums[i - 1][j];
                all_zero = all_zero and (nums[i][j] == 0);
            }
            if (all_zero) break;
        }

        var s2: i64 = 0;
        while (i > 0) : (i -= 1) {
            score1 += nums[i - 1][n - i];
            s2 = nums[i - 1][0] - s2;
        }

        score2 += s2;
    }

    return .{ @intCast(score1), @intCast(score2) };
}

pub fn main() !void {
    return aoc.run("09", run);
}

test "Day 09 part 1" {
    const EXAMPLE1 =
        \\0 3 6 9 12 15
        \\1 3 6 10 15 21
        \\10 13 16 21 30 45
    ;
    const PART1: u64 = 114;

    var lines = try aoc.Lines.initBuffer(EXAMPLE1);
    defer lines.deinit();
    const scores = try run(&lines);

    try std.testing.expectEqual(PART1, scores[0]);
}

test "Day 09 part 2" {
    const EXAMPLE2 =
        \\0 3 6 9 12 15
        \\1 3 6 10 15 21
        \\10 13 16 21 30 45
    ;
    const PART2: u64 = 2;

    var lines = try aoc.Lines.initBuffer(EXAMPLE2);
    defer lines.deinit();
    const scores = try run(&lines);

    try std.testing.expectEqual(PART2, scores[1]);
}
