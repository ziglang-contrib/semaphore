const std = @import("std");
const builtin = @import("builtin");

const os = std.os;
const testing = std.testing;

const c = switch (builtin.os.tag) {
    .linux, .freebsd => @cImport({
        @cInclude("semaphore.h");
    }),
    else =>
        @compileError(@tagName(builtin.os.tag) ++ " is not a supported os"),
};

/// An operating system backed semaphore.
///
/// Contrary to mutices and spinlocks, acquiring the semaphore will not return
/// a held object as waiting and signaling the semaphore is expected to be done
/// in an orthogonal manner.
pub const Semaphore = struct {
    const Self = @This();

    handle: switch (builtin.os.tag) {
        .linux, .netbsd, .openbsd, .freebsd =>
            c.sem_t,
        else =>
            unreachable,
    },

    /// Initializes a semaphore with the given initial value.
    ///
    /// `deinit` must be called when the semaphore is no longer used.
    pub fn init(value: usize) Self {
        switch (builtin.os.tag) {
            .linux, .netbsd, .openbsd, .freebsd => {
                var self: Self = undefined;

                _ = c.sem_init(&self.handle, 0, @truncate(c_uint, value));

                return self;
            },
            else => {
                unreachable;
            },
        }
    }

    /// Cleans up the state associated with the semaphore.
    pub fn deinit(self: *Self) void {
        switch (builtin.os.tag) {
            .linux, .netbsd, .openbsd, .freebsd => {
                _ = c.sem_destroy(&self.handle);
            },
            else => {
                unreachable;
            },
        }
    }

    /// Decrements the semaphore, blocking if the counter will past zero until
    /// a `signal` is received.
    pub fn wait(self: *Self) void {
        switch (builtin.os.tag) {
            .linux, .netbsd, .openbsd, .freebsd => {
                while (true) {
                    const rc = c.sem_wait(&self.handle);

                    switch (os.errno(rc)) {
                        0           => break,
                        os.EINTR    => {},
                        else        => unreachable,
                    }
                }
            },
            else => {
                unreachable;
            },
        }
    }

    /// Signals the semaphore, incrementing the counter associted with it.
    pub fn signal(self: *Self) void {
        switch (builtin.os.tag) {
            .linux, .netbsd, .openbsd, .freebsd => {
                const rc = c.sem_post(&self.handle);

                switch (os.errno(rc)) {
                    0       => {},
                    else    => unreachable,
                }
            },
            else => {
                unreachable;
            },
        }
    }

    /// The set of possible errors when calling `Semaphore.tryWait`.
    pub const TryWaitError = error {
        /// The wait operation would block.
        WouldBlock,
    };

    /// Attempts to wait on this semaphore, returning `error.WouldBlock` if the
    /// wait would block.
    pub fn tryWait(self: *Self) TryWaitError!void {
        switch (builtin.os.tag) {
            .linux, .netbsd, .openbsd, .freebsd => {
                const rc = c.sem_trywait(&self.handle);

                switch (os.errno(rc)) {
                    0           => {},
                    os.EAGAIN   => return TryWaitError.WouldBlock,
                    else        => unreachable,
                }
            },
            else => {
                unreachable;
            },
        }
    }

    /// The set of possible errors when calling `Semaphore.timedWait`.
    pub const TimedWaitError = error {
        /// The wait operation timed out.
        TimedOut,
    };

    /// Attempts to wait on this semaphore for a given amount of milliseconds,
    /// returning `error.Timeout` if the wait times out.
    pub fn timedWait(self: *Self, milliseconds: usize) TimedWaitError!void {
        switch (builtin.os.tag) {
            .linux, .netbsd, .openbsd, .freebsd => {
                var timespec = c.timespec{
                    .tv_sec = @as(c.time_t, @intCast(c_long, @divFloor(milliseconds, 1000))),
                    .tv_nsec = @as(c_long, @intCast(c_long, @mod(milliseconds, 1000) * 1000)),
                };

                while (true) {
                    const rc = c.sem_timedwait(&self.handle, &timespec);

                    switch (os.errno(rc)) {
                        0               => break,
                        os.EINTR        => {},
                        os.ETIMEDOUT    => return TimedWaitError.TimedOut,
                        else            => unreachable,
                    }
                }
            },
            else => {
                unreachable;
            },
        }
    }
};

test "initialization and deinitiialization" {
    var sem = Semaphore.init(0);
    defer sem.deinit();
}

test "blocking and non-blocking wait" {
    var sem = Semaphore.init(2);
    defer sem.deinit();

    sem.wait();
    sem.wait();

    var err: ?anyerror = null;

    testing.expectError(error.WouldBlock, sem.tryWait());
}

test "timed wait" {
    var sem = Semaphore.init(0);
    defer sem.deinit();

    testing.expectError(error.TimedOut, sem.timedWait(1));
}

test "signal" {
    var sem = Semaphore.init(0);
    defer sem.deinit();

    testing.expectError(error.WouldBlock, sem.tryWait());

    sem.signal();
    sem.signal();

    sem.tryWait() catch unreachable;
    sem.tryWait() catch unreachable;

    testing.expectError(error.WouldBlock, sem.tryWait());
}
