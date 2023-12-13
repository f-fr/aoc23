// Advent of code 23 - day 13
const std = @import("std");
const aoc = @import("aoc");

fn middleOfPalindrome(nums: []const u32) @Vector(2, usize) {
    var pos0: usize = 0;
    var pos1: usize = 0;
    for (1..nums.len) |i| {
        var cnt_diff: usize = 0;
        for (0..@min(i, nums.len - i)) |k| {
            const diff = nums[i - k - 1] ^ nums[i + k];
            const lz = @clz(diff);
            const tz = @ctz(diff);
            if (lz == 32) {
                // both are equal
            } else if (lz + tz == 31) {
                // exactly one bit
                if (cnt_diff > 0) break;
                cnt_diff += 1;
            } else {
                break;
            }
        } else {
            if (cnt_diff == 0)
                pos0 = i
            else
                pos1 = i;
            if (pos0 != 0 and pos1 != 0) break;
        }
    }

    return .{ pos0, pos1 };
}

pub fn run(lines: *aoc.Lines) ![2]u64 {
    var cols: [32]u32 = undefined;
    var rows: [32]u32 = undefined;

    var scores = @Vector(2, usize){ 0, 0 };
    var done = false;
    var idx: usize = 0;
    while (!done) {
        idx += 1;
        var n: usize = 0;
        var m: usize = 0;

        while (try lines.next()) |line| {
            if (line.len == 0) break;

            if (m == 0) {
                m = line.len;
                @memset(&cols, 0);
            } else if (m != line.len) return error.InvalidGrid;

            var row: u32 = 0;
            for (line, 0..) |c, i| {
                row = (row << 1) | @intFromBool(c == '#');
                cols[i] = (cols[i] << 1) | @intFromBool(c == '#');
            }
            rows[n] = row;

            n += 1;
        } else {
            done = true;
        }

        const m_cols = middleOfPalindrome(cols[0..m]);
        const m_rows = middleOfPalindrome(rows[0..n]);
        scores += m_cols + m_rows * @as(@Vector(2, usize), @splat(100));
    }

    return scores;
}

pub fn main() !void {
    return aoc.run("13", run);
}

test "Day 13 part 1" {
    const EXAMPLE1 =
        \\#.##..##.
        \\..#.##.#.
        \\##......#
        \\##......#
        \\..#.##.#.
        \\..##..##.
        \\#.#.##.#.
        \\
        \\#...##..#
        \\#....#..#
        \\..##..###
        \\#####.##.
        \\#####.##.
        \\..##..###
        \\#....#..#
    ;
    const PART1: u64 = 405;

    var lines = try aoc.Lines.initBuffer(EXAMPLE1);
    defer lines.deinit();
    const scores = try run(&lines);

    try std.testing.expectEqual(PART1, scores[0]);
}

test "Day 13 part 2" {
    const EXAMPLE2 =
        \\#.##..##.
        \\..#.##.#.
        \\##......#
        \\##......#
        \\..#.##.#.
        \\..##..##.
        \\#.#.##.#.
        \\
        \\#...##..#
        \\#....#..#
        \\..##..###
        \\#####.##.
        \\#####.##.
        \\..##..###
        \\#....#..#
    ;
    const PART2: u64 = 400;

    var lines = try aoc.Lines.initBuffer(EXAMPLE2);
    defer lines.deinit();
    const scores = try run(&lines);

    try std.testing.expectEqual(PART2, scores[1]);
}
