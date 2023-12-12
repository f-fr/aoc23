// Advent of code 23 - day 12
const std = @import("std");
const aoc = @import("aoc");

const State = struct {
    idx: usize,
    pos: usize,
};

const MaxBlocks = 31;
const MaxBlockSize = 20;
const States = struct {
    generation: u32 = 1,
    counts: [MaxBlocks][MaxBlockSize]u64 = undefined,
    gens: [MaxBlocks][MaxBlockSize]u32 = .{.{0} ** MaxBlockSize} ** MaxBlocks,
    active: [MaxBlocks * MaxBlockSize]State = undefined,
    nactive: usize = 0,

    fn clearRetainingCapacity(self: *States) void {
        self.generation += 1;
        self.nactive = 0;
    }

    fn states(self: *const States) []const State {
        return self.active[0..self.nactive];
    }

    fn get(self: *const States, st: State) ?u64 {
        if (self.gens[st.idx][st.pos] != self.generation) return null;
        return self.counts[st.idx][st.pos];
    }

    fn addState(self: *States, idx: usize, pos: usize, cnt: u64) void {
        const st = State{ .idx = idx, .pos = pos };
        if (self.gens[st.idx][st.pos] == self.generation) {
            self.counts[st.idx][st.pos] += cnt;
        } else {
            self.gens[st.idx][st.pos] = self.generation;
            self.active[self.nactive] = st;
            self.nactive += 1;
            self.counts[st.idx][st.pos] = cnt;
        }
    }
};

fn unfold(comptime N: comptime_int, alloc: std.mem.Allocator, record: []const u8, blocks: []const u8) !struct { []u8, []u8 } {
    const new_records = try std.mem.join(alloc, "?", &(.{record} ** N));
    errdefer alloc.free(new_records);
    const new_blocks = try std.mem.join(alloc, "", &(.{blocks} ** N));
    return .{ new_records, new_blocks };
}

pub fn run(lines: *aoc.Lines) ![2]u64 {
    var arena = std.heap.ArenaAllocator.init(aoc.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    var states1 = States{};
    var states2 = States{};

    var cur_states = &states1;
    var nxt_states = &states2;

    var score1: u64 = 0;
    var score2: u64 = 0;
    while (try lines.next()) |line| {
        const parts = try aoc.splitN(2, line, " ");
        const single_blocks = try aoc.toNumsA(u8, a, parts[1], ",");
        defer a.free(single_blocks);

        const unfolded = try unfold(5, a, parts[0], single_blocks);
        defer a.free(unfolded[0]);
        defer a.free(unfolded[1]);

        const records = unfolded[0];
        const blocks = unfolded[1];

        cur_states.clearRetainingCapacity();
        cur_states.addState(0, 0, 1);

        for (records, 0..) |c, i| {
            nxt_states.clearRetainingCapacity();

            for (cur_states.states()) |st| {
                const n = cur_states.get(st) orelse unreachable;
                if (st.pos == 0) { // before a block
                    if (st.idx < blocks.len and c != '.')
                        // start block
                        nxt_states.addState(st.idx, 1, n);

                    // increase gap
                    if (c != '#') nxt_states.addState(st.idx, 0, n);
                } else if (st.pos == blocks[st.idx]) {
                    // behind block -> expect a gap
                    if (c != '#') nxt_states.addState(st.idx + 1, 0, n);
                } else {
                    // within a block -> expect no gap
                    if (c != '.') nxt_states.addState(st.idx, st.pos + 1, n);
                }
            }

            if (i == parts[0].len) {
                const m = single_blocks.len;
                score1 += cur_states.get(.{ .idx = m, .pos = 0 }) orelse 0;
                score1 += cur_states.get(.{ .idx = m - 1, .pos = blocks[m - 1] }) orelse 0;
            }

            std.mem.swap(*States, &cur_states, &nxt_states);
        }

        const m = blocks.len;
        score2 += cur_states.get(.{ .idx = m, .pos = 0 }) orelse 0;
        score2 += cur_states.get(.{ .idx = m - 1, .pos = blocks[m - 1] }) orelse 0;
    }

    return .{ score1, score2 };
}

pub fn main() !void {
    return aoc.run("12", run);
}

test "Day 12 part 1 - example 1" {
    const EXAMPLE1 =
        \\#.#.### 1,1,3
        \\.#...#....###. 1,1,3
        \\.#.###.#.###### 1,3,1,6
        \\####.#...#... 4,1,1
        \\#....######..#####. 1,6,5
        \\.###.##....# 3,2,1
    ;
    const PART1: u64 = 6;

    var lines = try aoc.Lines.initBuffer(EXAMPLE1);
    defer lines.deinit();
    const scores = try run(&lines);

    try std.testing.expectEqual(PART1, scores[0]);
}

test "Day 12 part 1 - example 2" {
    const EXAMPLE1 =
        \\???.### 1,1,3
        \\.??..??...?##. 1,1,3
        \\?#?#?#?#?#?#?#? 1,3,1,6
        \\????.#...#... 4,1,1
        \\????.######..#####. 1,6,5
        \\?###???????? 3,2,1
    ;
    const PART1: u64 = 21;

    var lines = try aoc.Lines.initBuffer(EXAMPLE1);
    defer lines.deinit();
    const scores = try run(&lines);

    try std.testing.expectEqual(PART1, scores[0]);
}

test "Day 12 part 2" {
    const EXAMPLE2 =
        \\???.### 1,1,3
        \\.??..??...?##. 1,1,3
        \\?#?#?#?#?#?#?#? 1,3,1,6
        \\????.#...#... 4,1,1
        \\????.######..#####. 1,6,5
        \\?###???????? 3,2,1
    ;
    const PART2: u64 = 525152;

    var lines = try aoc.Lines.initBuffer(EXAMPLE2);
    defer lines.deinit();
    const scores = try run(&lines);

    try std.testing.expectEqual(PART2, scores[1]);
}
