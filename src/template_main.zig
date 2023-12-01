// Advent of code 23 - day DAY
const std = @import("std");
const aoc = @import("aoc");

pub fn run(lines: *aoc.Lines) ![2]u64 {
    while (try lines.next()) |line| {
        _ = line;
        // TODO
    }

    return .{ 0, 0 };
}

pub fn main() !void {
    return aoc.run("DAY", run);
}

test "Day DAY" {
    const PART1: u64 = 42;
    const PART2: u64 = 42;

    var lines = try aoc.Lines.init("input/DAY/input0.txt");
    defer lines.deinit();
    const scores = try run(&lines);

    try std.testing.expectEqual(PART1, scores[0]);
    try std.testing.expectEqual(PART2, scores[1]);
}
