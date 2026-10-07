const std = @import("std");

pub fn build(b: *std.Build) void {
    const exe = b.addExecutable(.{
        .name = "fractal",
        .root_module = b.createModule(.{
            .root_source_file = b.path("fractal.zig"),
            .target = b.resolveTargetQuery(.{}),
            .optimize = b.standardOptimizeOption(.{}),
        }),
    });
    b.installArtifact(exe);
    const run = b.addRunArtifact(exe);
    const run_step = b.step("run", "Render fractal to fractal.ppm");
    run_step.dependOn(&run.step);
}
