const std = @import("std");

pub fn build(b: *std.Build) void {

    const optimize = b.standardOptimizeOption(.{
        .preferred_optimize_mode = std.builtin.OptimizeMode.ReleaseSmall
    });

    const target = b.resolveTargetQuery(.{
        .cpu_arch = .wasm32, 
        .os_tag = .freestanding,
        .cpu_features_add = std.Target.wasm.featureSet(&.{
            .atomics,
            .bulk_memory, 
            .mutable_globals, 
            .multivalue, 
            .extended_const, 
            .sign_ext
        })
    });

    const root_module = b.createModule(.{
        .root_source_file = b.path("source/l9.zig"), 
        .target = target,
        .optimize = optimize,
        //.strip = true
    });

    const exe = b.addExecutable(.{
        .name = "l9",
        .root_module = root_module,
    });

    exe.entry = .disabled;
    exe.rdynamic = true;
    exe.export_table = true;

    const install = b.addInstallArtifact(exe, .{
        .dest_dir = .{ .override = .{ .custom = "." }}
    });

    b.default_step.dependOn(&install.step);
}
