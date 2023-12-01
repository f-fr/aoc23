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

test "Day DAY part 1" {
    const EXAMPLE1 =
        \\TODO
    ;
    const PART1: u64 = 42;

    var lines = try aoc.Lines.initBuffer(EXAMPLE1);
    defer lines.deinit();
    const scores = try run(&lines);

    try std.testing.expectEqual(PART1, scores[0]);
}

test "Day DAY part 2" {
    const EXAMPLE2 =
        \\TODO
    ;
    const PART2: u64 = 42;

    var lines = try aoc.Lines.initBuffer(EXAMPLE2);
    defer lines.deinit();
    const scores = try run(&lines);

    try std.testing.expectEqual(PART2, scores[1]);
}
