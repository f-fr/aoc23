// Advent of code 23 - day 01
const std = @import("std");
const aoc = @import("aoc");

fn findNums(comptime dir: enum { fwd, bwd }, line: []const u8) [2]u64 {
    const words = [_][]const u8{ "one", "two", "three", "four", "five", "six", "seven", "eight", "nine" };
    const start = if (dir == .fwd) 0 else line.len - 1;
    var d1: u64 = 100;
    var d2: u64 = 100;
    for (0..line.len) |i| {
        const pos = if (dir == .fwd) start + i else start - i;
        if ('0' <= line[pos] and line[pos] <= '9') {
            d1 = line[pos] - '0';
            if (d2 == 100) d2 = d1;
            break;
        } else if (d2 == 100) {
            for (words, 1..) |word, x| if (std.mem.startsWith(u8, line[pos..], word)) {
                d2 = x;
                break;
            };
        }
    }
    return .{ d1, d2 };
}

pub fn run(lines: *aoc.Lines) ![2]u64 {
    var sum1: u64 = 0;
    var sum2: u64 = 0;

    while (try lines.next()) |line| {
        const n = findNums(.fwd, line);
        const m = findNums(.bwd, line);
        sum1 += n[0] * 10 + m[0];
        sum2 += n[1] * 10 + m[1];
    }

    return .{ sum1, sum2 };
}

pub fn main() !void {
    return aoc.run("01", run);
}

test "Day 01" {
    const PART1: u64 = 142;
    const PART2: u64 = 281;

    {
        var lines = try aoc.Lines.init("input/01/input0.txt");
        defer lines.deinit();
        const scores1 = try run(&lines);

        try std.testing.expectEqual(PART1, scores1[0]);
    }

    {
        var lines = try aoc.Lines.init("input/01/input0part2.txt");
        defer lines.deinit();
        const scores2 = try run(&lines);

        try std.testing.expectEqual(PART2, scores2[1]);
    }
}
