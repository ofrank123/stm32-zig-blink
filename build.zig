const Build = @import("std").Build;
const builtin = @import("builtin");
const std = @import("std");

pub fn build(b: *Build) void {
    // Target STM32F446
    const target = .{
        .cpu_arch = .thumb,
        .cpu_model = .{ .explicit = &std.Target.arm.cpu.cortex_m4 },
        .os_tag = .freestanding,
        .abi = .eabihf,
    };

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.

    const elf = b.addExecutable(std.Build.ExecutableOptions{
        .target = target,
        .root_source_file = .{ .path = "main.zig" },
        .name = "firmware.elf",
    });
    elf.setLinkerScript(.{ .path = "link.ld" });
    b.installArtifact(elf);

    const bin = elf.addObjCopy(Build.Step.ObjCopy.Options{
        .format = .bin,
    });

    const copy_bin = b.addInstallBinFile(bin.getOutput(), "firmware.bin");
    copy_bin.step.dependOn(&bin.step);

    b.getInstallStep().dependOn(&copy_bin.step);

    const flash_cmd = b.addSystemCommand(&[_][]const u8{
        "st-flash",
        "--reset",
        "write",
        b.getInstallPath(copy_bin.dir, copy_bin.dest_rel_path),
        "0x8000000",
    });
    flash_cmd.step.dependOn(b.getInstallStep());

    const flash_step = b.step("flash", "Flash the binary to connected MCU");
    flash_step.dependOn(&flash_cmd.step);
}
