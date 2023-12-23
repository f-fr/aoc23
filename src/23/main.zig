// Advent of code 23 - day 23
const std = @import("std");
const aoc = @import("aoc");

const SeenNodes = std.bit_set.IntegerBitSet(64);
const State = struct {
    pos: aoc.Pos,
    seen: SeenNodes,
    dir: aoc.Dir,
    nsteps: usize,
};

const LabeledNode = struct {
    pos: aoc.Pos,
    seen: SeenNodes,
};

const Nodes = aoc.GridT(?usize);
const Seen = std.AutoHashMap(LabeledNode, usize);

const AdjList = std.ArrayList(usize);
const Edge = struct {
    length: usize,
    src: usize,
    snk: usize,

    fn other(e: Edge, u: usize) usize {
        return if (u == e.src) e.snk else e.src;
    }

    fn moreByLen(edges: []const Edge, e: usize, f: usize) bool {
        return edges[e].length > edges[f].length;
    }
};

pub fn run(lines: *aoc.Lines) ![2]u64 {
    var arena = std.heap.ArenaAllocator.init(aoc.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    var grid = try lines.readGrid(a);
    var nodegrid = try Nodes.initWith(a, grid.n, grid.m, null);
    var nnodes: usize = 0;
    var end: aoc.Pos = undefined;

    for (0..grid.n) |i| {
        for (0..grid.m) |j| {
            if (grid.at(i, j) != '#') {
                nodegrid.set(i, j, nnodes);
                end = .{ .i = i, .j = j };
                nnodes += 1;
            }
        }
    }

    var crossgrid = try Nodes.initWith(a, grid.n, grid.m, null);
    var ncrosses: usize = 0;
    for (0..grid.n) |i| {
        for (0..grid.m) |j| {
            const p = aoc.Pos{ .i = i, .j = j };
            if (nodegrid.atPos(p) == null) continue;
            var cnt: usize = 0;
            for (aoc.Dirs) |dir| {
                const v = p.maybeStep(dir, grid.n, grid.m) orelse continue;
                if (nodegrid.atPos(v) != null) cnt += 1;
            }
            if (cnt > 2) {
                crossgrid.setPos(p, ncrosses);
                ncrosses += 1;
            }
        }
    }

    const score1 = findPath(&grid, .{ .i = 0, .j = 1 }, end, 0, true);

    // fake crosses: start and end
    crossgrid.set(0, 1, ncrosses);
    crossgrid.setPos(end, ncrosses + 1);
    ncrosses += 2;

    for (0..grid.n) |i| {
        for (0..grid.m) |j| {
            switch (grid.at(i, j)) {
                '>', '<', '^', 'v' => grid.set(i, j, '.'),
                else => {},
            }
        }
    }

    // build the crossroads graph
    const adjlists = try a.alloc(AdjList, ncrosses);
    for (adjlists) |*adj| adj.* = try AdjList.initCapacity(a, 4); // max degree == 4

    var edges = try a.alloc(Edge, ncrosses * 2); // max degree == 4
    var nedges: usize = 0;

    for (0..grid.n) |i| {
        for (0..grid.m) |j| {
            const sidx = crossgrid.at(i, j) orelse continue;
            var queue: [150 * 150]struct { aoc.Pos, ?aoc.Dir, usize } = undefined;
            var qput: usize = 1;
            var qget: usize = 0;
            queue[0] = .{ .{ .i = i, .j = j }, null, 0 };
            while (qget < qput) {
                const ust = queue[qget];
                const u = ust[0];
                const udir = ust[1];
                const ustep = ust[2];
                qget += 1;

                if (crossgrid.atPos(u)) |uidx| {
                    if (uidx != sidx) {
                        if (uidx < sidx) {
                            edges[nedges] = .{ .length = ustep, .src = sidx, .snk = uidx };
                            adjlists[sidx].appendAssumeCapacity(nedges);
                            adjlists[uidx].appendAssumeCapacity(nedges);
                            nedges += 1;
                        }
                        continue;
                    }
                }

                for (aoc.Dirs) |dir| {
                    const v = u.maybeStep(dir, grid.n, grid.m) orelse continue;
                    if (dir.reverse() == udir) continue;
                    if (grid.atPos(v) != '.') continue;
                    queue[qput] = .{ v, dir, ustep + 1 };
                    qput += 1;
                }
            }
        }
    }

    // sort all adjlists by decreasing length
    // for (adjlists) |*adj| {
    //     std.mem.sortUnstable(usize, adj.*.items, edges, Edge.moreByLen);
    // }

    const score2 = findPath2(adjlists, edges, SeenNodes.initEmpty(), ncrosses - 2, ncrosses - 1, 0);

    return .{ score1, score2 };
}

fn findPath(grid: *aoc.Grid, u: aoc.Pos, end: aoc.Pos, nsteps: usize, slopes: bool) usize {
    if (u.i == end.i and u.j == end.j) return nsteps;

    const c = grid.atPos(u);
    grid.setPos(u, '#');

    var max: usize = 0;
    if (slopes and c != '.') {
        switch (c) {
            '>' => {
                const v = u.step(.east);
                if (grid.atPos(v) != '#') max = findPath(grid, v, end, nsteps + 1, slopes);
            },
            '<' => {
                const v = u.step(.west);
                if (grid.atPos(v) != '#') max = findPath(grid, v, end, nsteps + 1, slopes);
            },
            '^' => {
                const v = u.step(.north);
                if (grid.atPos(v) != '#') max = findPath(grid, v, end, nsteps + 1, slopes);
            },
            'v' => {
                const v = u.step(.south);
                if (grid.atPos(v) != '#') max = findPath(grid, v, end, nsteps + 1, slopes);
            },
            else => unreachable,
        }
    } else {
        for (aoc.Dirs) |dir| {
            const v = u.maybeStep(dir, grid.n, grid.m) orelse continue;
            if (grid.atPos(v) == '#') continue;
            max = @max(max, findPath(grid, v, end, nsteps + 1, slopes));
        }
    }

    grid.setPos(u, c);

    return max;
}

var max_dist: usize = 0;
fn findPath2(adjlists: []const AdjList, edges: []const Edge, seen: SeenNodes, u: usize, end: usize, dist: usize) usize {
    if (u == end) {
        max_dist = @max(max_dist, dist);
        //aoc.println("found path d:{} max_d:{}", .{ dist, max_dist });
        return dist;
    }

    var useen = seen;
    useen.set(u);

    var max: usize = 0;
    for (adjlists[u].items) |e| {
        const v = edges[e].other(u);
        if (seen.isSet(v)) continue;
        max = @max(max, findPath2(adjlists, edges, useen, v, end, dist + edges[e].length));
    }

    return max;
}

pub fn main() !void {
    return aoc.run("23", run);
}

test "Day 23 part 1" {
    const EXAMPLE1 =
        \\#.#####################
        \\#.......#########...###
        \\#######.#########.#.###
        \\###.....#.>.>.###.#.###
        \\###v#####.#v#.###.#.###
        \\###.>...#.#.#.....#...#
        \\###v###.#.#.#########.#
        \\###...#.#.#.......#...#
        \\#####.#.#.#######.#.###
        \\#.....#.#.#.......#...#
        \\#.#####.#.#.#########v#
        \\#.#...#...#...###...>.#
        \\#.#.#v#######v###.###v#
        \\#...#.>.#...>.>.#.###.#
        \\#####v#.#.###v#.#.###.#
        \\#.....#...#...#.#.#...#
        \\#.#########.###.#.#.###
        \\#...###...#...#...#.###
        \\###.###.#.###v#####v###
        \\#...#...#.#.>.>.#.>.###
        \\#.###.###.#.###.#.#v###
        \\#.....###...###...#...#
        \\#####################.#
    ;
    const PART1: u64 = 94;

    var lines = try aoc.Lines.initBuffer(EXAMPLE1);
    defer lines.deinit();
    const scores = try run(&lines);

    try std.testing.expectEqual(PART1, scores[0]);
}

test "Day 23 part 2" {
    const EXAMPLE2 =
        \\#.#####################
        \\#.......#########...###
        \\#######.#########.#.###
        \\###.....#.>.>.###.#.###
        \\###v#####.#v#.###.#.###
        \\###.>...#.#.#.....#...#
        \\###v###.#.#.#########.#
        \\###...#.#.#.......#...#
        \\#####.#.#.#######.#.###
        \\#.....#.#.#.......#...#
        \\#.#####.#.#.#########v#
        \\#.#...#...#...###...>.#
        \\#.#.#v#######v###.###v#
        \\#...#.>.#...>.>.#.###.#
        \\#####v#.#.###v#.#.###.#
        \\#.....#...#...#.#.#...#
        \\#.#########.###.#.#.###
        \\#...###...#...#...#.###
        \\###.###.#.###v#####v###
        \\#...#...#.#.>.>.#.>.###
        \\#.###.###.#.###.#.#v###
        \\#.....###...###...#...#
        \\#####################.#
    ;
    const PART2: u64 = 154;

    var lines = try aoc.Lines.initBuffer(EXAMPLE2);
    defer lines.deinit();
    const scores = try run(&lines);

    try std.testing.expectEqual(PART2, scores[1]);
}
