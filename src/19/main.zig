// Advent of code 23 - day 19
const std = @import("std");
const aoc = @import("aoc");

const Range = [2]u16;
const Cube = [4]Range;

const Rule = struct {
    category: u8,
    less: bool,
    value: u16,
    target: usize,

    fn applies(rule: *const Rule, values: [4]u16) bool {
        return if (rule.category == 4)
            true
        else if (rule.less)
            values[rule.category] < rule.value
        else
            values[rule.category] > rule.value;
    }

    fn applyRange(rule: *const Rule, values: Cube) struct { accepted: ?Cube, rejected: ?Cube } {
        const c = rule.category;
        if (c == 4) return .{ .accepted = values, .rejected = null };
        var accepted = values;
        var rejected = values;
        if (rule.less) {
            rejected[c][0] = @min(accepted[c][1], rule.value);
            accepted[c][1] = @min(accepted[c][1], rule.value - 1);
        } else {
            rejected[c][1] = @max(accepted[c][0], rule.value);
            accepted[c][0] = @max(accepted[c][0], rule.value + 1);
        }

        return .{
            .accepted = if (accepted[c][0] <= accepted[c][1]) accepted else null,
            .rejected = if (rejected[c][0] <= rejected[c][1]) rejected else null,
        };
    }
};

const Workflow = struct {
    rules: []Rule = &.{},
};

const WorkflowNames = std.StringHashMap(usize);

fn getWorkflowIndex(alloc: std.mem.Allocator, workflownames: *WorkflowNames, name: []const u8) !usize {
    const workflowname = try workflownames.getOrPutAdapted(name, workflownames.ctx);
    if (!workflowname.found_existing) {
        workflowname.key_ptr.* = try alloc.dupe(u8, name);
        workflowname.value_ptr.* = workflownames.count() - 1;
    }
    return workflowname.value_ptr.*;
}

pub fn run(lines: *aoc.Lines) ![2]u64 {
    var arena = std.heap.ArenaAllocator.init(aoc.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    var workflownames = std.StringHashMap(usize).init(a);
    try workflownames.ensureTotalCapacity(1000);

    var workflows = try std.ArrayList(Workflow).initCapacity(a, 1000);

    const rejectIdx = try getWorkflowIndex(a, &workflownames, "R");
    const acceptIdx = try getWorkflowIndex(a, &workflownames, "A");

    while (try lines.next()) |line| {
        if (line.len == 0) break;
        const parts = try aoc.splitAnyN(10, line, "{}, ");
        const workflowidx = try getWorkflowIndex(a, &workflownames, parts[0]);

        var nrules: usize = 0;
        for (parts[1..]) |part| {
            if (part.len == 0) break;
            nrules += 1;
        }

        if (nrules == 0) return error.InvalidEmptyWorkflow;

        const rules = try a.alloc(Rule, nrules);
        for (parts[1 .. nrules + 1], rules, 1..) |part, *rule, i| {
            var target: []const u8 = undefined;
            if (part.len > 2 and (part[1] == '<' or part[1] == '>')) {
                rule.*.category = @intCast(std.mem.indexOfScalar(u8, "xmas", part[0]) orelse
                    return error.InvalidCategory);
                rule.*.less = part[1] == '<';
                const colon = std.mem.indexOfScalarPos(u8, part, 2, ':') orelse return error.MissingTargetRule;
                rule.*.value = try aoc.toNum(u16, part[2..colon]);
                target = part[colon + 1 ..];
            } else {
                rule.*.category = 4; // catch all rule
                rule.*.less = false;
                rule.*.value = 0;
                target = part;
            }

            if ((i == nrules) != (rule.*.category == 4)) return error.InvalidCatchAllRule;

            const targetidx = try getWorkflowIndex(a, &workflownames, target);
            rule.*.target = targetidx;
        }

        if (workflowidx >= workflows.items.len)
            try workflows.appendNTimes(.{}, workflowidx + 1 - workflows.items.len);
        workflows.items[workflowidx] = .{ .rules = rules };
    }

    const inIdx = workflownames.get("in") orelse return error.MissingInWorkflow;

    // ensure all workflows are well - defined
    {
        var it = workflownames.iterator();
        while (it.next()) |e| {
            const i = e.value_ptr.*;
            if (i == acceptIdx or i == rejectIdx) continue;
            if (i >= workflows.items.len or workflows.items[i].rules.len == 0)
                return error.UndefinedWorkflow;
        }
    }

    var score1: usize = 0;
    while (try lines.next()) |line| {
        const parts = try aoc.splitAnyN(9, line, "{},= ");
        var values: [4]u16 = undefined;
        for (0..4) |i| {
            if (parts[2 * i].len != 1) return error.InvalidPartCategory;
            const c = std.mem.indexOfScalar(u8, "xmas", parts[2 * i][0]) orelse
                return error.InvalidPartCategory;
            values[c] = try aoc.toNum(u16, parts[2 * i + 1]);
        }

        // apply rules
        var cur = inIdx;
        while (cur != acceptIdx and cur != rejectIdx) {
            for (workflows.items[cur].rules) |rule| {
                if (rule.applies(values)) {
                    cur = rule.target;
                    break;
                }
            } else unreachable;
        }

        if (cur == acceptIdx) {
            for (values) |v| score1 += v;
        }
    }

    const cube: Cube = .{.{ 1, 4000 }} ** 4;
    const score2 = countMatches(workflows.items, inIdx, acceptIdx, rejectIdx, cube);

    return .{ score1, score2 };
}

fn countMatches(workflows: []const Workflow, cur: usize, acceptIdx: usize, rejectIdx: usize, cube: Cube) u64 {
    if (cur == acceptIdx) {
        var volume: u64 = 1;
        for (cube) |rng| volume *= (rng[1] - rng[0] + 1);
        return volume;
    } else if (cur == rejectIdx) {
        return 0;
    }

    var score: u64 = 0;
    var remaining: Cube = cube;
    for (workflows[cur].rules) |rule| {
        const result = rule.applyRange(remaining);
        if (result.accepted) |accepted|
            score += countMatches(workflows, rule.target, acceptIdx, rejectIdx, accepted);
        remaining = result.rejected orelse break; // break if nothing left
    }
    return score;
}

pub fn main() !void {
    return aoc.run("19", run);
}

test "Day 19 part 1" {
    const EXAMPLE1 =
        \\px{a<2006:qkq,m>2090:A,rfg}
        \\pv{a>1716:R,A}
        \\lnx{m>1548:A,A}
        \\rfg{s<537:gd,x>2440:R,A}
        \\qs{s>3448:A,lnx}
        \\qkq{x<1416:A,crn}
        \\crn{x>2662:A,R}
        \\in{s<1351:px,qqz}
        \\qqz{s>2770:qs,m<1801:hdj,R}
        \\gd{a>3333:R,R}
        \\hdj{m>838:A,pv}
        \\
        \\{x=787,m=2655,a=1222,s=2876}
        \\{x=1679,m=44,a=2067,s=496}
        \\{x=2036,m=264,a=79,s=2244}
        \\{x=2461,m=1339,a=466,s=291}
        \\{x=2127,m=1623,a=2188,s=1013}
    ;
    const PART1: u64 = 19114;

    var lines = try aoc.Lines.initBuffer(EXAMPLE1);
    defer lines.deinit();
    const scores = try run(&lines);

    try std.testing.expectEqual(PART1, scores[0]);
}

test "Day 19 part 2" {
    const EXAMPLE2 =
        \\px{a<2006:qkq,m>2090:A,rfg}
        \\pv{a>1716:R,A}
        \\lnx{m>1548:A,A}
        \\rfg{s<537:gd,x>2440:R,A}
        \\qs{s>3448:A,lnx}
        \\qkq{x<1416:A,crn}
        \\crn{x>2662:A,R}
        \\in{s<1351:px,qqz}
        \\qqz{s>2770:qs,m<1801:hdj,R}
        \\gd{a>3333:R,R}
        \\hdj{m>838:A,pv}
        \\
        \\{x=787,m=2655,a=1222,s=2876}
        \\{x=1679,m=44,a=2067,s=496}
        \\{x=2036,m=264,a=79,s=2244}
        \\{x=2461,m=1339,a=466,s=291}
        \\{x=2127,m=1623,a=2188,s=1013}
    ;
    const PART2: u64 = 167409079868000;

    var lines = try aoc.Lines.initBuffer(EXAMPLE2);
    defer lines.deinit();
    const scores = try run(&lines);

    try std.testing.expectEqual(PART2, scores[1]);
}
