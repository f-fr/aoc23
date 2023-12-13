// Advent of code 23 - day 13
const std = @import("std");
const aoc = @import("aoc");

fn middleOfPalindrome(nums: []const u32, ignore: ?usize) usize {
    for (1..nums.len) |i| {
        if (i == ignore) continue;
        for (0..@min(i, nums.len - i)) |k| {
            if (nums[i - k - 1] != nums[i + k]) break;
        } else return i;
    }

    return 0;
}

pub fn run(lines: *aoc.Lines) ![2]u64 {
    var cols: [32]u32 = undefined;
    var rows: [32]u32 = undefined;

    var score1: u64 = 0;
    var score2: u64 = 0;
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

        const m_cols1 = middleOfPalindrome(cols[0..m], null);
        const m_rows1 = middleOfPalindrome(rows[0..n], null);
        score1 += m_cols1 + 100 * m_rows1;

        part2: for (0..n) |i| {
            for (0..m) |j| {
                // flip the bit at column i and row j
                rows[i] ^= @as(u32, 1) << @as(u5, @intCast(m - j - 1));
                cols[j] ^= @as(u32, 1) << @as(u5, @intCast(n - i - 1));

                const m_cols = middleOfPalindrome(cols[0..m], m_cols1);
                const m_rows = middleOfPalindrome(rows[0..n], m_rows1);

                if (m_cols != 0 or m_rows != 0) {
                    score2 += m_cols + 100 * m_rows;
                    break :part2;
                }

                // undo
                rows[i] ^= @as(u32, 1) << @as(u5, @intCast(m - j - 1));
                cols[j] ^= @as(u32, 1) << @as(u5, @intCast(n - i - 1));
            }
        }
    }

    return .{ score1, score2 };
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
