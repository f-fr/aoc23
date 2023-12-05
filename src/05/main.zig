// Advent of code 23 - day 05
const std = @import("std");
const aoc = @import("aoc");

const Rng = struct {
    idx: usize,
    src: u64,
    dst: u64,
    len: u64,

    fn end(self: *const Rng) u64 {
        return self.src + self.len;
    }
};

const Inv = struct { beg: u64, end: u64 };

fn lessThanRng(_: void, a: Rng, b: Rng) bool {
    if (a.idx != b.idx) return a.idx < b.idx;
    return a.src < b.src;
}

fn lessThanInv(_: void, a: Inv, b: Inv) bool {
    if (a.beg != b.beg) return a.beg < b.beg;
    return a.end < b.end;
}

pub fn run(lines: *aoc.Lines) ![2]u64 {
    var i: usize = 0;
    var ranges: [1000]Rng = undefined;
    var n: usize = 0;

    const fst_line = try lines.next() orelse return error.MissingSeeds;
    const seeds = try aoc.toNumsAnyA(u64, aoc.allocator, fst_line[(std.mem.indexOfScalar(u8, fst_line, ':') orelse return error.MissingSeeds) + 1 ..], " ");
    defer aoc.allocator.free(seeds);

    while (try lines.next()) |line| {
        if (line.len == 0) continue;
        if (std.mem.indexOfScalar(u8, line, ':') != null) {
            i += 1;
            continue;
        }
        const nums = try aoc.toNumsAny(u64, 3, line, " ");
        ranges[n] = .{ .idx = i, .src = nums[1], .dst = nums[0], .len = nums[2] };
        n += 1;
    }

    std.mem.sort(Rng, ranges[0..n], {}, lessThanRng);
    // fill gap ranges
    var allranges = std.ArrayList(Rng).init(aoc.allocator);
    defer allranges.deinit();
    for (0..n) |j| {
        if (j == 0) {
            try allranges.append(.{ .idx = ranges[j].idx, .src = 0, .dst = 0, .len = ranges[j].src });
        } else if (ranges[j - 1].idx != ranges[j].idx) {
            const s = ranges[j - 1].src + ranges[j - 1].len;
            try allranges.append(.{ .idx = ranges[j - 1].idx, .src = s, .dst = s, .len = std.math.maxInt(u64) - s });
            try allranges.append(.{ .idx = ranges[j].idx, .src = 0, .dst = 0, .len = ranges[j].src });
        } else {
            const s = ranges[j - 1].src + ranges[j - 1].len;
            const l = ranges[j].src - s;
            try allranges.append(.{ .idx = ranges[j].idx, .src = s, .dst = s, .len = l });
        }
        try allranges.append(ranges[j]);
    }

    const Invs = std.ArrayList(Inv);
    var invs = Invs.init(aoc.allocator);
    defer invs.deinit();
    var invs2 = Invs.init(aoc.allocator);
    defer invs2.deinit();

    // This could be done simpler by just computing pairwise
    // intersections of (range,interval) pairs. However, the following
    // implementation runs in O(n) because each range in (essentially)
    // considered at most once.

    var scores: [2]u64 = undefined;
    for (0..2) |part| {
        // initialize starting intervals for each part
        invs.clearRetainingCapacity();
        if (part == 0) {
            for (seeds) |s| try invs.append(Inv{ .beg = s, .end = s + 1 });
        } else {
            for (0..seeds.len / 2) |j| try invs.append(Inv{ .beg = seeds[2 * j], .end = seeds[2 * j] + seeds[2 * j + 1] });
        }

        var k: usize = 0;
        for (1..8) |idx| {
            std.mem.sort(Inv, invs.items, {}, lessThanInv);
            // compress successive intervals
            var skip: usize = 0;
            for (1..invs.items.len) |j| {
                if (invs.items[j - 1 - skip].end >= invs.items[j].beg) {
                    invs.items[j - 1 - skip].end = @max(invs.items[j - 1 - skip].end, invs.items[j].end);
                    skip += 1;
                } else {
                    invs.items[j - skip] = invs.items[j];
                }
            }
            invs.shrinkRetainingCapacity(invs.items.len - skip);
            invs2.clearRetainingCapacity();

            for (invs.items) |inv| {
                // find first range with non-empty intersection
                while (allranges.items[k].idx < idx) k += 1;
                while (inv.end <= allranges.items[k].src or inv.beg >= allranges.items[k].end()) k += 1;
                // add intersection with all ranges having a non-empty intersection with inv
                while (k < allranges.items.len and allranges.items[k].idx == idx and allranges.items[k].src < inv.end) : (k += 1) {
                    const beg = @max(inv.beg, allranges.items[k].src);
                    const end = @min(inv.end, allranges.items[k].end());
                    try invs2.append(.{ //
                        .beg = beg - allranges.items[k].src + allranges.items[k].dst,
                        .end = end - allranges.items[k].src + allranges.items[k].dst,
                    });
                }

                // the last range with non-empty intersection may have a non-empty intersection with the next interval as well
                k -= 1;
            }

            std.mem.swap(Invs, &invs, &invs2);
        }

        scores[part] = invs.items[0].beg;
        for (invs.items[1..]) |inv| scores[part] = @min(scores[part], inv.beg);
    }

    return scores;
}

pub fn main() !void {
    return aoc.run("05", run);
}

test "Day 05 part 1" {
    const EXAMPLE1 =
        \\seeds: 79 14 55 13
        \\
        \\seed-to-soil map:
        \\50 98 2
        \\52 50 48
        \\
        \\soil-to-fertilizer map:
        \\0 15 37
        \\37 52 2
        \\39 0 15
        \\
        \\fertilizer-to-water map:
        \\49 53 8
        \\0 11 42
        \\42 0 7
        \\57 7 4
        \\
        \\water-to-light map:
        \\88 18 7
        \\18 25 70
        \\
        \\light-to-temperature map:
        \\45 77 23
        \\81 45 19
        \\68 64 13
        \\
        \\temperature-to-humidity map:
        \\0 69 1
        \\1 0 69
        \\
        \\humidity-to-location map:
        \\60 56 37
        \\56 93 4
    ;
    const PART1: u64 = 35;

    var lines = try aoc.Lines.initBuffer(EXAMPLE1);
    defer lines.deinit();
    const scores = try run(&lines);

    try std.testing.expectEqual(PART1, scores[0]);
}

test "Day 05 part 2" {
    const EXAMPLE2 =
        \\seeds: 79 14 55 13
        \\
        \\seed-to-soil map:
        \\50 98 2
        \\52 50 48
        \\
        \\soil-to-fertilizer map:
        \\0 15 37
        \\37 52 2
        \\39 0 15
        \\
        \\fertilizer-to-water map:
        \\49 53 8
        \\0 11 42
        \\42 0 7
        \\57 7 4
        \\
        \\water-to-light map:
        \\88 18 7
        \\18 25 70
        \\
        \\light-to-temperature map:
        \\45 77 23
        \\81 45 19
        \\68 64 13
        \\
        \\temperature-to-humidity map:
        \\0 69 1
        \\1 0 69
        \\
        \\humidity-to-location map:
        \\60 56 37
        \\56 93 4
    ;
    const PART2: u64 = 46;

    var lines = try aoc.Lines.initBuffer(EXAMPLE2);
    defer lines.deinit();
    const scores = try run(&lines);

    try std.testing.expectEqual(PART2, scores[1]);
}
