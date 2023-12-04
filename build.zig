const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) !void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    const aoc = b.createModule(.{ .source_file = .{ .path = "src/aoc.zig" } });

    const lib_unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/aoc.zig" },
        .target = target,
        .optimize = optimize,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);

    var gen_txt: [1024]u8 = undefined;
    var gen_fbs = std.io.fixedBufferStream(&gen_txt);
    var gen_w = gen_fbs.writer();
    const gen_step = b.addWriteFiles();

    try gen_w.writeAll(
        \\const std = @import("std");
        \\const aoc = @import("aoc");
        \\const days = .{
    );
    var day_mods = std.ArrayList(struct { name: []const u8, module: *std.Build.Module }).init(b.allocator);

    var dir = try std.fs.openDirAbsolute(b.pathFromRoot("src"), .{ .iterate = true });
    defer dir.close();
    var dir_it = dir.iterate();
    var days = std.ArrayList(usize).init(b.allocator);
    defer days.deinit();

    while (try dir_it.next()) |d| {
        if (d.kind != .directory or d.name.len > 2) continue;
        const day = std.fmt.parseInt(u8, d.name, 10) catch continue;
        if (day < 0 or day > 24) continue;

        const exe_name = try std.fmt.allocPrint(b.allocator, "{d:0>2}", .{day});
        const exe_src = try std.fmt.allocPrint(b.allocator, "src/{s}/main.zig", .{d.name});
        const exe = b.addExecutable(.{
            .name = exe_name,
            .root_source_file = .{ .path = exe_src },
            .target = target,
            .optimize = optimize,
        });
        exe.addModule("aoc", aoc);

        // make a module for this day
        const exe_mod = b.createModule(.{ .source_file = .{ .path = exe_src }, .dependencies = &.{.{ .name = "aoc", .module = aoc }} });
        try day_mods.append(.{ .name = exe_name, .module = exe_mod });

        // install step
        const inst = b.addInstallArtifact(exe, .{});
        b.getInstallStep().dependOn(&inst.step); // add to global install step

        const run_cmd = b.addRunArtifact(exe);
        run_cmd.step.dependOn(&inst.step); // run depends on install

        // This allows the user to pass arguments to the application in the build
        // command itself, like this: `zig build run -- arg1 arg2 etc`
        if (b.args) |args| {
            run_cmd.addArgs(args);
        }

        // user visible step
        const run_step_name = try std.fmt.allocPrint(b.allocator, "run{d:0>2}", .{day});
        const run_step_desc = try std.fmt.allocPrint(b.allocator, "Run day {d:0>2}", .{day});
        const run_step = b.step(run_step_name, run_step_desc);
        run_step.dependOn(&run_cmd.step);

        // tests
        const exe_unit_tests = b.addTest(.{
            .name = exe_name,
            .root_source_file = .{ .path = exe_src },
            .target = target,
            .optimize = optimize,
        });
        exe_unit_tests.addModule("aoc", aoc);
        const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);
        test_step.dependOn(&run_exe_unit_tests.step);

        try days.append(day);
    }

    std.mem.sort(usize, days.items, {}, std.sort.asc(usize));
    for (days.items) |day| {
        try gen_w.print("    .{{ .day = {0d}, .filename = \"input/{0d:0>2}/input1.txt\", .run = @import(\"{0d:0>2}\").run }},\n", .{day});
    }
    try gen_w.print("}};\n\n", .{});
    try gen_w.writeAll(
        \\pub fn main() !void {
        \\    inline for (days) |day| {
        \\        var lines = try aoc.Lines.init(day.filename);
        \\        defer lines.deinit();
        \\
        \\        const t_start = std.time.milliTimestamp();
        \\        _ = try day.run(&lines);
        \\        const t_end = std.time.milliTimestamp();
        \\        const t = @as(f64, @floatFromInt(t_end - t_start)) / 1000.0;
        \\
        \\        aoc.println("Day {d:0>2}: {d:.3}", .{day.day, t});
        \\    }
        \\}
    );

    const times_path = gen_step.add("times.zig", gen_fbs.getWritten());
    const times_exe = b.addExecutable(.{
        .name = "times",
        .root_source_file = times_path,
        .target = target,
        .optimize = .ReleaseFast,
    });
    times_exe.strip = true;
    for (day_mods.items) |mod| times_exe.addModule(mod.name, mod.module);
    times_exe.step.dependOn(&gen_step.step);
    times_exe.addModule("aoc", aoc);
    const times_inst = b.addInstallArtifact(times_exe, .{});
    b.getInstallStep().dependOn(&times_inst.step);
    const times_cmd = b.addRunArtifact(times_exe);
    times_cmd.step.dependOn(&times_inst.step);
    const times_step = b.step("times", "Run all exercises with timings");
    times_step.dependOn(&times_cmd.step);
}
