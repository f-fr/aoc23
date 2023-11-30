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
