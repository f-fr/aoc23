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

    fn lessThan(_: void, a: Rng, b: Rng) bool {
        if (a.idx != b.idx) return a.idx < b.idx;
        return a.src < b.src;
    }
};

const Inv = struct {
    beg: u64,
    end: u64,

    fn lessThan(_: void, a: Inv, b: Inv) bool {
        if (a.beg != b.beg) return a.beg < b.beg;
        return a.end < b.end;
    }
};

pub fn run(lines: *aoc.Lines) ![2]u64 {
    var arena = std.heap.ArenaAllocator.init(aoc.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const fst_line = try aoc.splitN(2, try lines.next() orelse return error.MissingSeeds, ":");
    const seeds = try aoc.toNumsAnyA(u64, a, fst_line[1], " ");

    var nsteps: usize = 0;
    var ranges: [1000]Rng = undefined;
    var n: usize = 0;
    while (try lines.next()) |line| {
        if (line.len == 0) continue;
        if (std.mem.indexOfScalar(u8, line, ':')) |_| {
            nsteps += 1;
            continue;
        }
        const nums = try aoc.toNumsAny(u64, 3, line, " ");
        ranges[n] = .{ .idx = nsteps, .src = nums[1], .dst = nums[0], .len = nums[2] };
        n += 1;
    }

    std.mem.sortUnstable(Rng, ranges[0..n], {}, Rng.lessThan);
    // fill gap ranges
    var allranges = try a.alloc(Rng, n * 2 + nsteps);
    var m: usize = 0;
    for (0..n) |j| {
        if (j == 0 or ranges[j - 1].idx != ranges[j].idx) {
            allranges[m] = .{ .idx = ranges[j].idx, .src = 0, .dst = 0, .len = ranges[j].src };
            m += 1;
        }

        allranges[m] = ranges[j];
        m += 1;

        const s = ranges[j].end();
        const e = if (j + 1 == n or ranges[j].idx != ranges[j + 1].idx) std.math.maxInt(u64) else ranges[j + 1].src;
        allranges[m] = .{ .idx = ranges[j].idx, .src = s, .dst = s, .len = e - s };
        m += 1;
    }

    const Invs = std.ArrayList(Inv);
    var invs = try Invs.initCapacity(a, 200);
    var invs2 = try Invs.initCapacity(a, 200);

    // This could be done simpler by just computing pairwise
    // intersections of (range,interval) pairs. However, the following
    // implementation runs in O(n) because each range is (essentially)
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
        for (1..nsteps + 1) |idx| {
            std.mem.sortUnstable(Inv, invs.items, {}, Inv.lessThan);
            // compress successive intervals
            var skip: usize = 0;
            for (1..invs.items.len) |j| {
                if (invs.items[j - 1 - skip].end >= invs.items[j].beg) {
                    invs.items[j - 1 - skip].end = @max(invs.items[j - 1 - skip].end, invs.items[j].end);
                    skip += 1;
                } else invs.items[j - skip] = invs.items[j];
            }
            invs.shrinkRetainingCapacity(invs.items.len - skip);
            invs2.clearRetainingCapacity();

            for (invs.items) |inv| {
                // find first range with non-empty intersection
                while (allranges[k].idx < idx) k += 1;
                while (inv.end <= allranges[k].src or inv.beg >= allranges[k].end()) k += 1;
                // add intersection with all ranges having a non-empty intersection with inv
                while (k < allranges.len and allranges[k].idx == idx and allranges[k].src < inv.end) : (k += 1) {
                    const beg = @max(inv.beg, allranges[k].src);
                    const end = @min(inv.end, allranges[k].end());
                    try invs2.append(.{ //
                        .beg = beg - allranges[k].src + allranges[k].dst,
                        .end = end - allranges[k].src + allranges[k].dst,
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
