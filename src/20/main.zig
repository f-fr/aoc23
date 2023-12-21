// Advent of code 23 - day 20
const std = @import("std");
const aoc = @import("aoc");

const ModuleNames = std.StringHashMap(usize);
const ModType = enum { flipflop, conjunction, broadcaster };
const InputSet = std.bit_set.IntegerBitSet(64);
const Module = struct {
    targets: []usize = &.{},
    data: union(ModType) {
        flipflop: struct {
            on: bool = false,
        },
        conjunction: struct {
            input_high: InputSet = InputSet.initEmpty(),
            nlow: usize = 0,
        },
        broadcaster: void,
    },
};

const Pulse = struct {
    source: usize,
    target: usize,
    high: bool,
};

fn getModuleIndex(alloc: std.mem.Allocator, modulenames: *ModuleNames, name: []const u8) !usize {
    const modulename = try modulenames.getOrPutAdapted(name, modulenames.ctx);
    if (!modulename.found_existing) {
        modulename.key_ptr.* = try alloc.dupe(u8, name);
        modulename.value_ptr.* = modulenames.count() - 1;
    }
    return modulename.value_ptr.*;
}

fn reset(modules: []Module) void {
    for (modules) |*m| {
        if (m.*.data == .flipflop) m.*.data.flipflop.on = false;
        if (m.*.data == .conjunction) {
            m.*.data.conjunction.input_high = InputSet.initEmpty();
            m.*.data.conjunction.nlow = 0;
        }
    }

    for (modules) |m| {
        for (m.targets) |tgt| {
            if (modules[tgt].data == .conjunction) {
                modules[tgt].data.conjunction.nlow += 1;
            }
        }
    }
}

pub fn run(lines: *aoc.Lines) ![2]u64 {
    var arena = std.heap.ArenaAllocator.init(aoc.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    var mod_names = ModuleNames.init(a);
    try mod_names.ensureTotalCapacity(100);
    var modules = try std.ArrayList(Module).initCapacity(a, 100);

    const bc_idx = try getModuleIndex(a, &mod_names, "broadcaster");
    const rx_idx = try getModuleIndex(a, &mod_names, "rx");

    var n_edges: usize = 0;
    while (try lines.next()) |line| {
        const parts = try aoc.splitAnyN(10, line, "->, ");
        const modtype: ModType = switch (parts[0][0]) {
            '%' => .flipflop,
            '&' => .conjunction,
            else => .broadcaster,
        };

        if (modtype == .broadcaster and !std.mem.eql(u8, parts[0], "broadcaster"))
            return error.InvalidModuleName;
        const modname = parts[0][@intFromBool(modtype != .broadcaster)..];
        const modidx = try getModuleIndex(a, &mod_names, modname);

        if (modidx >= modules.items.len)
            try modules.appendNTimes(.{ .data = .{ .broadcaster = {} } }, modidx + 1 - modules.items.len);

        var targets = try std.ArrayList(usize).initCapacity(a, 4);
        for (parts[1..]) |tgt| {
            if (tgt.len == 0) break;
            try targets.append(try getModuleIndex(a, &mod_names, tgt));
        }
        n_edges += targets.items.len;
        modules.items[modidx] = .{
            .targets = try targets.toOwnedSlice(),
            .data = switch (modtype) {
                .flipflop => .{ .flipflop = .{} },
                .conjunction => .{ .conjunction = .{} },
                .broadcaster => .{ .broadcaster = {} },
            },
        };
    }

    // possibly append an "output" target
    if (mod_names.count() > modules.items.len)
        try modules.appendNTimes(.{ .data = .{ .broadcaster = {} } }, mod_names.count() - modules.items.len);

    const result = try findCycle(a, modules.items, bc_idx, rx_idx, 1000);

    const score1 = result.nhigh * result.nlow;

    var cycles: [100]u64 = undefined;
    for (modules.items[bc_idx].targets, 0..) |tgt, i| {
        reset(modules.items);
        cycles[i] = (try findCycle(a, modules.items, tgt, rx_idx, null)).cycle;
    }

    const score2 = aoc.lcmOfAll(cycles[0..modules.items[bc_idx].targets.len]);

    return .{ score1, score2 };
}

fn findCycle(a: std.mem.Allocator, modules: []Module, start: usize, end: usize, niter: ?usize) !struct { nhigh: u64, nlow: u64, cycle: usize } {
    reset(modules);

    const queue = try a.alloc(Pulse, 10 * modules.len);
    defer a.free(queue);

    var nhigh: u64 = 0;
    var nlow: u64 = 0;
    var iter: usize = 0;
    while (iter < niter orelse iter + 1) : (iter += 1) {
        var state: u64 = 0;
        for (modules, 0..) |mod, i| {
            if (mod.data == .flipflop and mod.data.flipflop.on) {
                state |= @as(u64, 1) << @as(u6, @intCast(i));
            }
        }

        if (niter == null and iter > 0 and state == 0) break; // hopefully this work

        var qput: usize = 1;
        var qget: usize = 0;
        queue[0] = .{ .source = 0, .target = start, .high = false };
        while (qget < qput) {
            const pulse = queue[qget];
            qget += 1;
            const mod = &modules[pulse.target];

            if (pulse.high) nhigh += 1 else nlow += 1;

            if (pulse.target == end) {
                if (!pulse.high) aoc.println("end is low at {}", .{iter + 1});
                continue;
            }

            var send_high = false;
            switch (mod.*.data) {
                .flipflop => |*f| {
                    if (pulse.high) continue;
                    f.*.on = !f.*.on;
                    send_high = f.*.on;
                },
                .conjunction => |*c| {
                    if (pulse.high) {
                        if (!c.*.input_high.isSet(pulse.source)) {
                            c.*.nlow -= 1;
                            c.*.input_high.set(pulse.source);
                        }
                    } else {
                        if (c.*.input_high.isSet(pulse.source)) {
                            c.*.nlow += 1;
                            c.*.input_high.unset(pulse.source);
                        }
                    }
                    send_high = mod.*.data.conjunction.nlow != 0;
                },
                .broadcaster => {
                    send_high = pulse.high;
                },
            }

            for (mod.*.targets) |tgt| {
                // aoc.println("{} -{s}→ {}", .{ pulse.target, if (send_high) "high" else "low", tgt });
                queue[qput] = .{ .source = pulse.target, .target = tgt, .high = send_high };
                qput += 1;
            }
        }
    }

    return .{ .nhigh = nhigh, .nlow = nlow, .cycle = iter };
}

fn writeDot(mod_names: *const ModuleNames, modules: []const Module) !void {
    const dir = std.fs.cwd();
    const f = try dir.createFile("graph.dot", .{});
    defer f.close();
    const w = f.writer();
    try w.print("digraph modules\n", .{});
    try w.print("{{\n", .{});
    var it = mod_names.iterator();
    while (it.next()) |e| {
        const t: []const u8 = switch (modules[e.value_ptr.*].data) {
            .flipflop => "%",
            .conjunction => "&",
            .broadcaster => "",
        };
        try w.print("  {} [label=\"{}:{s}{s}\"];\n", .{ e.value_ptr.*, e.value_ptr.*, t, e.key_ptr.* });
    }
    for (modules.items, 0..) |mod, i| {
        for (mod.targets) |tgt| {
            try w.print("  {} -> {};\n", .{ i, tgt });
        }
    }
    try w.print("}}\n", .{});
}

pub fn main() !void {
    return aoc.run("20", run);
}

test "Day 20 part 1 - example 1" {
    const EXAMPLE1 =
        \\broadcaster -> a, b, c
        \\%a -> b
        \\%b -> c
        \\%c -> inv
        \\&inv -> a
    ;
    const PART1: u64 = 32000000;

    var lines = try aoc.Lines.initBuffer(EXAMPLE1);
    defer lines.deinit();
    const scores = try run(&lines);

    try std.testing.expectEqual(PART1, scores[0]);
}

test "Day 20 part 1 - example 2" {
    const EXAMPLE1 =
        \\broadcaster -> a
        \\%a -> inv, con
        \\&inv -> b
        \\%b -> con
        \\&con -> output
    ;
    const PART1: u64 = 11687500;

    var lines = try aoc.Lines.initBuffer(EXAMPLE1);
    defer lines.deinit();
    const scores = try run(&lines);

    try std.testing.expectEqual(PART1, scores[0]);
}

test "Day 20 part 2" {
    // const EXAMPLE2 =
    //     \\TODO
    // ;
    // const PART2: u64 = 42;

    // var lines = try aoc.Lines.initBuffer(EXAMPLE2);
    // defer lines.deinit();
    // const scores = try run(&lines);

    // try std.testing.expectEqual(PART2, scores[1]);
}
