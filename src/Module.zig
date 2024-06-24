const Module = @This();
const std = @import("std");

const log = std.log.scoped(.@"glbar/Module");

allocator: std.mem.Allocator,
command: []const u8,
name: []const u8,

thread: std.Thread = undefined,
mutex: std.Thread.Mutex = .{},
running: bool = true,

child: std.process.Child = undefined,

string: []const u8 = "none",

pub fn start(self: *Module) !void {
    if (!self.mutex.tryLock()) return error.AlreadyStarted;
    defer self.mutex.unlock();

    self.thread = try std.Thread.spawn(.{}, func, .{self});
}

pub fn stop(self: *Module) void {
    self.mutex.lock();
    self.running = false;
    self.mutex.unlock();

    self.thread.join();
}

pub fn get(self: *Module) []const u8 {
    self.mutex.lock();
    defer self.mutex.unlock();

    return self.string;
}

fn func(self: *Module) !void {
    self.mutex.lock();

    //self.child = std.process.Child.init(&[_][]const u8{"sh", "-c", "playerctl --player=cmus,firefox,%any -F metadata --format='{{title}} - {{artist}}'"}, self.allocator);
    self.child = std.process.Child.init(&[_][]const u8{"sh", "-c", self.command}, self.allocator);
    self.child.stdout_behavior = std.process.Child.StdIo.Pipe;
    self.child.stdin_behavior = std.process.Child.StdIo.Pipe;

    try self.child.spawn();
    defer _ = self.child.kill() catch unreachable;

    var line = std.ArrayList(u8).init(self.allocator);
    defer line.deinit();
    



    var poller = std.io.poll(self.allocator, enum { stdout }, .{
        .stdout = self.child.stdout.?,
    });
    defer poller.deinit();

    self.mutex.unlock();

    while (true) {
        std.time.sleep(100000);
        try std.Thread.yield();

        self.mutex.lock();
        defer self.mutex.unlock();

        if (!self.running) break;


        _ = try poller.pollTimeout(10);
        const len = poller.fifo(.stdout).count;

        if (len == 0) continue;

        line.clearAndFree();

        const buf = try self.allocator.alloc(u8, len);
        defer self.allocator.free(buf);

        _ = try poller.fifo(.stdout).reader().streamUntilDelimiter(line.writer(), '\n', len);
        log.debug("{s}: {s}", .{self.name, line.items});
        self.string = line.items;
    }


    _ = try self.child.kill();
}