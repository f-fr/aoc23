// Advent of code 23 - day 25
const std = @import("std");
const aoc = @import("aoc");

const assert = std.debug.assert;

const NodeNames = std.StringHashMap(usize);
fn getNodeIndex(alloc: std.mem.Allocator, nodenames: *NodeNames, name: []const u8) !usize {
    const nodename = try nodenames.getOrPutAdapted(name, nodenames.ctx);
    if (!nodename.found_existing) {
        nodename.key_ptr.* = try alloc.dupe(u8, name);
        nodename.value_ptr.* = nodenames.count() - 1;
    }
    return nodename.value_ptr.*;
}

pub fn run(lines: *aoc.Lines) ![2]u64 {
    var arena = std.heap.ArenaAllocator.init(aoc.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    var nodenames = NodeNames.init(a);
    try nodenames.ensureTotalCapacity(1000);

    var edges = try std.ArrayList([2]usize).initCapacity(a, 10000);

    while (try lines.next()) |line| {
        var toks = std.mem.tokenizeAny(u8, line, ": ");
        const u = toks.next() orelse break;
        const uidx = try getNodeIndex(a, &nodenames, u);
        while (toks.next()) |v| {
            const vidx = try getNodeIndex(a, &nodenames, v);
            try edges.append(.{ uidx, vidx });
            try edges.append(.{ vidx, uidx });
        }
    }

    const n = nodenames.count();
    const m = edges.items.len;

    const AdjList = std.ArrayList(usize);
    var neighs = try a.alloc(AdjList, nodenames.count());
    for (neighs) |*ns| ns.* = try AdjList.initCapacity(a, 10);

    for (edges.items, 0..) |e, eidx| {
        try neighs[e[0]].append(eidx);
        try neighs[e[1]].append(eidx);
    }

    var flow = try a.alloc(u8, m);
    var pred = try a.alloc(?[2]usize, n);

    var queue = try a.alloc(usize, n);
    var qput: usize = 0;
    var qget: usize = 0;

    const score1: usize = main: for (1..n) |t| {
        @memset(flow, 0);
        for (0..4) |iter| {
            _ = iter;

            @memset(pred, null);
            pred[0] = .{ 0, 0 };
            queue[0] = 0;
            qput = 1;
            qget = 0;
            while (qget < qput) {
                const u = queue[qget];
                qget += 1;
                if (u == t) break;
                for (neighs[u].items) |e| {
                    if (edges.items[e][0] == u) { // outgoing edge
                        const v = edges.items[e][1];
                        if (flow[e] == 0 and pred[v] == null) {
                            pred[v] = .{ u, e };
                            queue[qput] = v;
                            qput += 1;
                        }
                    } else { // incoming edge
                        const v = edges.items[e][0];
                        if (flow[e] == 1 and pred[v] == null) {
                            pred[v] = .{ u, e };
                            queue[qput] = v;
                            qput += 1;
                        }
                    }
                }
            } else {
                var maxcut: usize = 0;
                for (pred) |p| {
                    if (p != null) maxcut += 1;
                }
                break :main maxcut * (n - maxcut);
            }

            // found s-t path, augment
            var u = t;
            while (pred[u].?[0] != u) : (u = pred[u].?[0]) {
                const e = pred[u].?[1];
                if (edges.items[e][1] == u) { // forward edge
                    assert(flow[e] == 0);
                    flow[e] = 1;
                } else {
                    assert(flow[e] == 1);
                    flow[e] = 0;
                }
            }
        }
    } else {
        break :main 0;
    };

    return .{ score1, 0 };
}

pub fn main() !void {
    return aoc.run("25", run);
}

test "Day 25 part 1" {
    const EXAMPLE1 =
        \\jqt: rhn xhk nvd
        \\rsh: frs pzl lsr
        \\xhk: hfx
        \\cmg: qnr nvd lhk bvb
        \\rhn: xhk bvb hfx
        \\bvb: xhk hfx
        \\pzl: lsr hfx nvd
        \\qnr: nvd
        \\ntq: jqt hfx bvb xhk
        \\nvd: lhk
        \\lsr: lhk
        \\rzs: qnr cmg lsr rsh
        \\frs: qnr lhk lsr
    ;
    const PART1: u64 = 54;

    var lines = try aoc.Lines.initBuffer(EXAMPLE1);
    defer lines.deinit();
    const scores = try run(&lines);

    try std.testing.expectEqual(PART1, scores[0]);
}
