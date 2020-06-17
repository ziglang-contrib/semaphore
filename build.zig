const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();
    const lib = b.addStaticLibrary("semaphore", "src/semaphore.zig");
    lib.setBuildMode(mode);
    lib.install();

    var main_tests = b.addTest("src/semaphore.zig");
    main_tests.setBuildMode(mode);
    main_tests.linkLibC();
    main_tests.linkSystemLibrary("pthread");

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&main_tests.step);
}
