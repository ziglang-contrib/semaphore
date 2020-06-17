# Semaphore

A Zig library to use operating systems semaphores.

## Usage

### Linux

Execute the following from your project root to install the library. Note that
the `dependencies` folder can be replaced with any other directory.

```sh
mkdir -p dependencies
git submodule add https://github.com/ziglang-contrib/semaphore dependencies/semaphore
```

Add the following to your `build.zig` (replacing `exe` with the actual build
step that requires this library):

```zig
step.addPackagePath("semaphore", "dependencies/semaphore/src/semaphore.zig");
step.linkSystemLibrary("pthread");
```
