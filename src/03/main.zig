// Advent of code 23 - day 03
const std = @import("std");
const aoc = @import("aoc");

const isDigit = std.ascii.isDigit;

fn isValid(lines: []const u8, m: usize, i: usize, beg: usize, end: usize) bool {
    inline for (.{ i - 1, i, i + 1 }) |k| {
        for (lines[k * m + beg - 1 .. k * m + end + 1]) |ch| if (!isDigit(ch) and ch != '.') return true;
    }
    return false;
}

fn numAt(line: []const u8, pos: usize) ?usize {
    if (!isDigit(line[pos])) return null;

    var i = pos;
    while (i > 0 and isDigit(line[i - 1])) i -= 1;

    var end = pos + 1;
    while (end < line.len and isDigit(line[end])) : (end += 1) {}

    return aoc.toNum(usize, line[i..end]) catch 0;
}

pub fn run(lines: *aoc.Lines) ![2]u64 {
    const grid = try lines.readGridWithBoundary(aoc.allocator, '.');
    const n = grid.n;
    const m = grid.m;
    const data = grid.data;
    defer aoc.allocator.free(data);

    var score1: usize = 0;
    var score2: usize = 0;

    for (1..n - 1) |i| {
        const ln = data[i * m .. i * m + m];
        // part 1
        var pos: usize = 0;
        while (true) {
            while (pos < ln.len and !isDigit(ln[pos])) : (pos += 1) {}
            if (pos == ln.len) break;

            var end = pos + 1;
            while (end < ln.len and isDigit(ln[end])) : (end += 1) {}

            if (isValid(data, m, i, pos, end)) {
                const x = try aoc.toNum(usize, ln[pos..end]);
                score1 += x;
            }
            pos = end;
        }

        // part 2
        for (1..ln.len - 1) |j| {
            if (ln[j] != '*') continue;
            var cnt: usize = 0;
            var s: usize = 1;
            inline for (.{ i - 1, i, i + 1 }) |k| {
                const ln2 = data[k * m .. k * m + m];
                if (numAt(ln2, j)) |x| {
                    cnt += 1;
                    s *= x;
                } else {
                    inline for (.{ j - 1, j + 1 }) |l|
                        if (numAt(ln2, l)) |x| {
                            cnt += 1;
                            s *= x;
                        };
                }
            }

            if (cnt == 2) score2 += s;
        }
    }

    return .{ score1, score2 };
}

pub fn main() !void {
    return aoc.run("03", run);
}

test "Day 03 part 1" {
    const EXAMPLE1 =
        \\467..114..
        \\...*......
        \\..35..633.
        \\......#...
        \\617*......
        \\.....+.58.
        \\..592.....
        \\......755.
        \\...$.*....
        \\.664.598..
    ;
    const PART1: u64 = 4361;

    var lines = try aoc.Lines.initBuffer(EXAMPLE1);
    defer lines.deinit();
    const scores = try run(&lines);

    try std.testing.expectEqual(PART1, scores[0]);
}

test "Day 03 part 2" {
    const EXAMPLE2 =
        \\467..114..
        \\...*......
        \\..35..633.
        \\......#...
        \\617*......
        \\.....+.58.
        \\..592.....
        \\......755.
        \\...$.*....
        \\.664.598..
    ;
    const PART2: u64 = 467835;

    var lines = try aoc.Lines.initBuffer(EXAMPLE2);
    defer lines.deinit();
    const scores = try run(&lines);

    try std.testing.expectEqual(PART2, scores[1]);
}
