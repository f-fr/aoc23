// Advent of code 23 - day 18
const std = @import("std");
const aoc = @import("aoc");

pub fn run(lines: *aoc.Lines) ![2]u64 {
    var y: [2]i64 = .{ 0, 0 };
    var area: [2]i64 = .{ 0, 0 };
    var n_boundary: [2]u64 = .{ 0, 0 };

    while (try lines.next()) |line| {
        const parts = try aoc.splitAnyN(3, line, " ()");

        const dir1 = parts[0];
        const dist1 = try aoc.toNum(u16, parts[1]);
        if (dir1.len != 1) return error.InvalidDirection;

        if (parts[2][6] -% '0' > 3) return error.InvalidRGBDirection;
        const dir2 = "RDLU"[parts[2][6] - '0'];
        const dist2 = try std.fmt.parseInt(u32, parts[2][1..6], 16);

        const dir: [2]u8 = .{ dir1[0], dir2 };
        const dist: [2]u32 = .{ dist1, dist2 };

        for (0..2) |part| {
            switch (dir[part]) {
                'R' => area[part] += dist[part] * y[part],
                'L' => area[part] -= dist[part] * y[part],
                'U' => y[part] -= dist[part],
                'D' => y[part] += dist[part],
                else => return error.InvalidDirection,
            }
            n_boundary[part] += dist[part];
        }
    }

    var scores: [2]u64 = undefined;
    for (0..2) |i| scores[i] = @abs(area[i]) + 1 + n_boundary[i] / 2;

    return scores;
}

pub fn main() !void {
    return aoc.run("18", run);
}

test "Day 18 part 1" {
    const EXAMPLE1 =
        \\R 6 (#70c710)
        \\D 5 (#0dc571)
        \\L 2 (#5713f0)
        \\D 2 (#d2c081)
        \\R 2 (#59c680)
        \\D 2 (#411b91)
        \\L 5 (#8ceee2)
        \\U 2 (#caa173)
        \\L 1 (#1b58a2)
        \\U 2 (#caa171)
        \\R 2 (#7807d2)
        \\U 3 (#a77fa3)
        \\L 2 (#015232)
        \\U 2 (#7a21e3)
    ;
    // const EXAMPLE1 =
    //     \\R 4 (#000000)
    //     \\D 4 (#000000)
    //     \\L 4 (#000000)
    //     \\U 4 (#000000)
    // ;
    const PART1: u64 = 62;

    var lines = try aoc.Lines.initBuffer(EXAMPLE1);
    defer lines.deinit();
    const scores = try run(&lines);

    try std.testing.expectEqual(PART1, scores[0]);
}

test "Day 18 part 2" {
    const EXAMPLE2 =
        \\R 6 (#70c710)
        \\D 5 (#0dc571)
        \\L 2 (#5713f0)
        \\D 2 (#d2c081)
        \\R 2 (#59c680)
        \\D 2 (#411b91)
        \\L 5 (#8ceee2)
        \\U 2 (#caa173)
        \\L 1 (#1b58a2)
        \\U 2 (#caa171)
        \\R 2 (#7807d2)
        \\U 3 (#a77fa3)
        \\L 2 (#015232)
        \\U 2 (#7a21e3)
    ;
    const PART2: u64 = 952408144115;

    var lines = try aoc.Lines.initBuffer(EXAMPLE2);
    defer lines.deinit();
    const scores = try run(&lines);

    try std.testing.expectEqual(PART2, scores[1]);
}
