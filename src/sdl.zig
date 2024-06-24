const c = @import("c.zig").c;
const std = @import("std");
const main = @import("main.zig");

const SDLError = error{
    CreateWindowError,
    CreateGLContextError,
};

const log = std.log.scoped(.sdl);

var context: c.SDL_GLContext = undefined;

pub fn init() !*c.SDL_Window {
    var sdl_version: c.SDL_version = undefined;
    c.SDL_GetVersion(&sdl_version);

    log.info("Initializing SDL v{d}.{d}.{d}", .{ sdl_version.major, sdl_version.minor, sdl_version.patch });

    log.info("Initializing subsystems", .{});
    _ = c.SDL_InitSubSystem(c.SDL_INIT_EVERYTHING);

    log.info("Setting window hint", .{});
    _ = c.SDL_SetHint(c.SDL_HINT_X11_WINDOW_TYPE, "_NET_WM_WINDOW_TYPE_DOCK");

    log.info("Setting GL attributs", .{});
    _ = c.SDL_GL_SetAttribute(c.SDL_GL_CONTEXT_PROFILE_MASK, c.SDL_GL_CONTEXT_PROFILE_CORE);
    _ = c.SDL_GL_SetAttribute(c.SDL_GL_CONTEXT_MAJOR_VERSION, 3);
    _ = c.SDL_GL_SetAttribute(c.SDL_GL_CONTEXT_MINOR_VERSION, 3);
    _ = c.SDL_GL_SetAttribute(c.SDL_GL_STENCIL_SIZE, 8);
    _ = c.SDL_GL_SetAttribute(c.SDL_GL_CONTEXT_PROFILE_MASK, c.SDL_GL_CONTEXT_PROFILE_CORE);

    _ = c.SDL_GL_SetAttribute(c.SDL_GL_ALPHA_SIZE, 8);
    _ = c.SDL_GL_SetAttribute(c.SDL_GL_DOUBLEBUFFER, 1);

    log.info("Creating window", .{});
    const window = try createWindow();

    log.info("Creating GL context", .{});
    context = try createContext(window);

    return window;
}

pub fn deinit(window: *c.SDL_Window) void {
    log.info("Deinitializing", .{});

    log.info("Destroying GL Context", .{});
    c.SDL_GL_DeleteContext(context);

    log.info("Destroying window", .{});
    c.SDL_DestroyWindow(window);

    log.info("Quitting subsystems", .{});
    c.SDL_QuitSubSystem(c.SDL_INIT_EVERYTHING);
}

fn createWindow() !*c.SDL_Window {
    const window = c.SDL_CreateWindow(
        main.info.name, 
        c.SDL_WINDOWPOS_CENTERED,
        1400,
        0, (24*96)/72,
        c.SDL_WINDOW_OPENGL | c.SDL_WINDOW_BORDERLESS
    );

    if (window == null) {
        log.err("Failed to create window: {s}", .{c.SDL_GetError()});
        return SDLError.CreateWindowError;
    }

    return window.?;
}

fn createContext(window: *c.SDL_Window) !c.SDL_GLContext {
    return c.SDL_GL_CreateContext(window) orelse {
        log.err("Failed to create GL context: {s}", .{c.SDL_GetError()});
        return SDLError.CreateGLContextError;
    };
}