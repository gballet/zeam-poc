const std = @import("std");

const zkvm_types = enum {
    powdr,
    sp1,
};

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    const target_query = .{ .cpu_arch = .riscv32, .os_tag = .freestanding, .abi = .none, .cpu_model = .{ .explicit = &std.Target.riscv.cpu.generic_rv32 } };
    const target = b.resolveTargetQuery(target_query);

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    const zkvm = b.option(zkvm_types, "zkvm", "zkvm target") orelse .powdr;

    const zkvm_module = switch (zkvm) {
        .powdr => b.addModule("zkvm", .{
            .optimize = optimize,
            .target = target,
            .root_source_file = b.path("src/powdr/lib.zig"),
        }),
        .sp1 => b.addModule("zkvm", .{
            .optimize = optimize,
            .target = target,
            .root_source_file = b.path("src/sp1/lib.zig"),
        }),
    };

    const exe = b.addExecutable(.{
        .name = "zeam-poc",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("zkvm", zkvm_module);

    switch (zkvm) {
        .powdr => {
            exe.addAssemblyFile(b.path("src/powdr/start.s"));
            exe.setLinkerScript(b.path("src/powdr/powdr.x"));
        },
        .sp1 => {
            exe.addAssemblyFile(b.path("src/sp1/start.s"));
            exe.setLinkerScript(b.path("src/sp1/sp1.ld"));
        },
    }

    exe.pie = true;

    // This declares intent for the executable to be installed into the
    // standard location when the user invokes the "install" step (the default
    // step when running `zig build`).
    b.installArtifact(exe);
}
