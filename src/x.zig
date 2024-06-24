const c = @import("c.zig").c;
const std = @import("std");
const main = @import("main.zig");

const XError = error{
    OpenDisplayError,
    NoCompatibleFrameBufferConfig,
    ChooseVisualError,
};

const log = std.log.scoped(.@"glbar/x");

pub const event_mask = c.KeyPressMask | c.KeyReleaseMask | c.ButtonPressMask;

var screen: *c.Screen = undefined;

//TODO: error handling
pub fn init() !struct { display: *c.Display, window: c.Window, context: c.GLXContext } {
    const display = c.XOpenDisplay(null) orelse return error.OpenDisplayError;
    screen = @ptrCast(c.DefaultScreenOfDisplay(display));
    const screen_id = c.DefaultScreen(display);


    var glx_major: c.GLint = undefined;
    var glx_minor: c.GLint = undefined;
    _ = c.glXQueryVersion(display, &glx_major, &glx_minor);

    log.info("GLX v{d}.{d}", .{glx_major, glx_minor});

    var glx_attributes = [_]c.GLint {
        // c.GLX_RGBA,
        c.GLX_DOUBLEBUFFER, c.True,
        // c.GLX_DEPTH_SIZE, 32,
        // c.GLX_RENDER_TYPE, c.GLX_RGBA_BIT,
        // c.GLX_TRANSPARENT_TYPE, c.GLX_TRANSPARENT_RGB,
        // c.GLX_DRAWABLE_TYPE, c.GLX_WINDOW_BIT,
        // c.GLX_X_RENDERABLE, c.True,
        // c.GLX_X_VISUAL_TYPE, c. GLX_TRUE_COLOR,
        // c.GLX_STENCIL_SIZE, 8,
        // c.GLX_RED_SIZE, 8,
        // c.GLX_GREEN_SIZE, 8,
        // c.GLX_BLUE_SIZE, 8,
        // c.GLX_ALPHA_SIZE, 8,
        c.None,
    };

    var fb_count: c_int = undefined;
    const fb_configs = c.glXChooseFBConfig(display, screen_id, &glx_attributes, &fb_count);
    defer _ = c.XFree(@ptrCast(fb_configs));
    log.info("fb count {d}", .{fb_count});
    if (fb_count == 0) return XError.NoCompatibleFrameBufferConfig;

    var fb_config: c.GLXFBConfig = undefined;
    var visual: [*c]c.XVisualInfo = undefined;

    for (0..@intCast(fb_count)) |i| {
        visual = c.glXGetVisualFromFBConfig(display, fb_configs[i]);
        if (visual == 0) return XError.ChooseVisualError;

        const format = c.XRenderFindVisualFormat(display, visual.*.visual);

        if (format.*.direct.alphaMask > 0) {
            log.info("alpha mask: {d}", .{format.*.direct.alphaMask});
            fb_config = fb_configs[i];
            break;
        }

        _ = c.XFree(visual);
    }

    defer _ = c.XFree(visual);

    var window_attributes = c.XSetWindowAttributes {
        .border_pixel = c.BlackPixel(display, screen_id),
        .background_pixel = c.WhitePixel(display, screen_id),
        .override_redirect = c.True,
        .colormap = c.XCreateColormap(display, c.RootWindow(display, screen_id),  visual.*.visual, c.AllocNone),
        .event_mask = c.ExposureMask,
    };

    //TODO: temporarily hardcoded pos
    const window = c.XCreateWindow(display, c.RootWindowOfScreen(screen), 1920, 0, 1, 32+8, 0, visual.*.depth, c.InputOutput, visual.*.visual, c.CWColormap | c.CWBorderPixel | c.CWEventMask, &window_attributes);

    _ = c.XChangeProperty(display, window, c.XInternAtom(display, "_NET_WM_WINDOW_TYPE", c.False), c.XInternAtom(display, "", c.False), 32, c.PropModeReplace, @ptrCast(&c.XInternAtom(display, "_NET_WM_WINDOW_TYPE_DOCK", c.False)), 1);

    _ = c.XSelectInput(display, window, event_mask);

    _ = c.XClearWindow(display, window);
    _ = c.XMapRaised(display, window);


    
    const glXCreateContextAttribsARB: *const fn(*c.Display, c.GLXFBConfig, c.GLXContext, c.Bool, [*c]const c_int) c.GLXContext = @ptrCast(c.glXGetProcAddressARB("glXCreateContextAttribsARB").?);
    
    const glx_ctx_attributes = [_]c.GLint {
        c.GLX_CONTEXT_MAJOR_VERSION_ARB, 4,
        c.GLX_CONTEXT_MINOR_VERSION_ARB, 6,
        c.None,
    };


    const context = glXCreateContextAttribsARB(display, fb_config, null, c.True, &glx_ctx_attributes);

    // const context = c.glXCreateNewContext(display, fb_config, c.GLX_RGBA_TYPE, null, c.True);
    _ = c.glXMakeCurrent(display, window, context);


    var window_width: c_uint = undefined;
    var window_height: c_uint = undefined;
    c.glXQueryDrawable(display, window, c.GLX_WIDTH, &window_width);
    c.glXQueryDrawable(display, window, c.GLX_HEIGHT, &window_height);
    _ = c.XResizeWindow(display, window, window_width, window_height);

    return .{ .display = display, .window = window, .context = context };
}

pub fn deinit(display: *c.Display, window: c.Window, context: c.GLXContext) void {
    c.glXDestroyContext(display, context);
    _ = c.XDestroyWindow(display, window);
    _ = c.XCloseDisplay(display);
}