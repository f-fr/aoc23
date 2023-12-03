// Advent of code 23 - day 03
const std = @import("std");
const aoc = @import("aoc");

fn isValid(lines: []const u8, m: usize, i: usize, beg: usize, end: usize) bool {
    for ([_]usize{ i - 1, i, i + 1 }) |k| {
        if (std.mem.indexOfNone(u8, lines[k * m + beg - 1 .. k * m + end + 1], "0123456789.") != null) return true;
    }

    return false;
}

fn numAt(line: []const u8, pos: usize) ?usize {
    if (!std.ascii.isDigit(line[pos])) return null;

    var i = pos;
    while (i > 0 and '0' <= line[i - 1] and line[i - 1] <= '9') i -= 1;
    const end = std.mem.indexOfNonePos(u8, line, pos, "0123456789") orelse line.len;
    return aoc.toNum(usize, line[i..end]) catch 0;
}

pub fn run(lines: *aoc.Lines) ![2]u64 {
    var data = std.ArrayList(u8).init(aoc.allocator);
    defer data.deinit();
    var n: usize = 2;
    var m: usize = 0;
    // we add a boundary of '.' around the field
    while (try lines.next()) |line| {
        if (m == 0) {
            m = line.len + 2;
            for (0..m) |_| try data.append('.');
        }
        try data.append('.');
        try data.appendSlice(line);
        try data.append('.');
        n += 1;
    }
    for (0..m) |_| try data.append('.');

    var score1: usize = 0;
    var score2: usize = 0;

    for (1..n - 1) |i| {
        const ln = data.items[i * m .. i * m + m];
        // part 1
        var pos: usize = 0;
        while (true) {
            pos = std.mem.indexOfAnyPos(u8, ln, pos, "0123456789") orelse ln.len;
            if (pos >= ln.len) break;
            const end = std.mem.indexOfNonePos(u8, ln, pos, "0123456789") orelse ln.len;
            if (isValid(data.items, m, i, pos, end)) {
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
            for ([_]usize{ i - 1, i, i + 1 }) |k| {
                const ln2 = data.items[k * m .. k * m + m];
                if (numAt(ln2, j)) |x| {
                    cnt += 1;
                    s *= x;
                } else {
                    if (numAt(ln2, j - 1)) |x| {
                        cnt += 1;
                        s *= x;
                    }
                    if (numAt(ln2, j + 1)) |x| {
                        cnt += 1;
                        s *= x;
                    }
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
