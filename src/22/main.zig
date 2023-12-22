// Advent of code 23 - day 22
const std = @import("std");
const aoc = @import("aoc");

const Pos = @Vector(3, u16);
const Brick = struct {
    a: Pos,
    b: Pos,

    fn lessThanZ(_: void, a: Brick, b: Brick) bool {
        return a.a[2] < b.a[2];
    }
};

pub fn run(lines: *aoc.Lines) ![2]u64 {
    var arena = std.heap.ArenaAllocator.init(aoc.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    var bricks = try std.ArrayList(Brick).initCapacity(a, 1300);

    while (try lines.next()) |line| {
        const parts = try aoc.toNumsAny(u16, 6, line, ",~ ");
        var brick = Brick{ .a = .{ parts[0], parts[1], parts[2] }, .b = .{ parts[3], parts[4], parts[5] } };
        if (brick.a[2] > brick.b[2]) std.mem.swap(Pos, &brick.a, &brick.b);
        try bricks.append(brick);
    }

    std.mem.sortUnstable(Brick, bricks.items, {}, Brick.lessThanZ);

    var heights: [10][10]u16 = .{.{0} ** 10} ** 10;
    var topBricks: [10][10]u16 = .{.{std.math.maxInt(u16)} ** 10} ** 10;
    var edges = std.AutoHashMap([2]usize, void).init(a);

    for (bricks.items, 0..) |*b, idx| {
        var max_z: u16 = 0;
        for (@min(b.*.a[0], b.*.b[0])..@max(b.*.a[0], b.*.b[0]) + 1) |x| {
            for (@min(b.*.a[1], b.*.b[1])..@max(b.*.a[1], b.*.b[1]) + 1) |y| {
                max_z = @max(max_z, heights[x][y]);
            }
        }

        if (max_z >= b.*.a[2]) return error.OverlappingBricks;
        const dz = b.*.a[2] - max_z - 1;
        b.*.a[2] -= dz;
        b.*.b[2] -= dz;

        for (@min(b.*.a[0], b.*.b[0])..@max(b.*.a[0], b.*.b[0]) + 1) |x| {
            for (@min(b.*.a[1], b.*.b[1])..@max(b.*.a[1], b.*.b[1]) + 1) |y| {
                if (heights[x][y] == max_z and topBricks[x][y] != std.math.maxInt(u16)) {
                    try edges.put(.{ topBricks[x][y], idx }, {});
                }
                heights[x][y] = b.*.b[2];
                topBricks[x][y] = @intCast(idx);
            }
        }
    }

    // build the graph of outgoing edges and indegrees
    const AdjList = std.SinglyLinkedList(usize);
    const indegrees = try a.alloc(usize, bricks.items.len);
    var outgoings = try a.alloc(AdjList, bricks.items.len);

    @memset(indegrees, 0);
    for (0..bricks.items.len) |i| outgoings[i] = .{};

    {
        var it = edges.iterator();
        while (it.next()) |e| {
            const u = e.key_ptr.*[0];
            const v = e.key_ptr.*[1];

            const out_node = try a.create(AdjList.Node);
            out_node.*.data = v;
            outgoings[u].prepend(out_node);
            indegrees[v] += 1;
        }
    }

    // start the chain-reaction by bfs
    const inremoved = try a.alloc(usize, bricks.items.len);
    const queue = try a.alloc(usize, bricks.items.len);
    var score1: usize = 0;
    var score2: usize = 0;
    for (0..bricks.items.len) |s| {
        @memset(inremoved, 0);
        var qput: usize = 1;
        var qget: usize = 0;
        queue[0] = s;
        while (qget < qput) {
            const u = queue[qget];
            qget += 1;
            var node = outgoings[u].first;
            while (node) |n| : (node = n.next) {
                const v = n.*.data;
                inremoved[v] += 1;
                if (inremoved[v] == indegrees[v]) {
                    score2 += 1;
                    queue[qput] = v;
                    qput += 1;
                }
            }
        }
        // no other brick moved?
        score1 += @intFromBool(qput == 1);
    }

    return .{ score1, score2 };
}

pub fn main() !void {
    return aoc.run("22", run);
}

test "Day 22 part 1" {
    const EXAMPLE1 =
        \\1,0,1~1,2,1
        \\0,0,2~2,0,2
        \\0,2,3~2,2,3
        \\0,0,4~0,2,4
        \\2,0,5~2,2,5
        \\0,1,6~2,1,6
        \\1,1,8~1,1,9
    ;
    const PART1: u64 = 5;

    var lines = try aoc.Lines.initBuffer(EXAMPLE1);
    defer lines.deinit();
    const scores = try run(&lines);

    try std.testing.expectEqual(PART1, scores[0]);
}

test "Day 22 part 2" {
    const EXAMPLE2 =
        \\1,0,1~1,2,1
        \\0,0,2~2,0,2
        \\0,2,3~2,2,3
        \\0,0,4~0,2,4
        \\2,0,5~2,2,5
        \\0,1,6~2,1,6
        \\1,1,8~1,1,9
    ;
    const PART2: u64 = 7;

    var lines = try aoc.Lines.initBuffer(EXAMPLE2);
    defer lines.deinit();
    const scores = try run(&lines);

    try std.testing.expectEqual(PART2, scores[1]);
}
