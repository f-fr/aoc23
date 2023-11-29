// Advent of code 23 - day DAY
const std = @import("std");
const aoc = @import("aoc");

fn run(lines: *aoc.Lines) ![2]u64 {
    while (try lines.next()) |line| {
        _ = line;
        // TODO
    }
}

pub fn main() !void {
    aoc.info("AoC23 - day DAY", .{});
    var lines = try aoc.readLines();
    defer lines.deinit();

    const scores = try run(&lines);

    aoc.println("Part 1: {}", .{scores[0]});
    aoc.println("Part 2: {}", .{scores[1]});
}
