const math3d = @import("math3d.zig");
const Vec4 = math3d.Vec4;
const Mat4x4 = math3d.Mat4x4;
const mat4x4_identity = math3d.mat4x4_identity;
const tetris = @import("tetris.zig");
const Tetris = tetris.Tetris;
const std = @import("std");
const panic = std.debug.panic;
const assert = std.debug.assert;
const bufPrint = std.fmt.bufPrint;
const c = @import("c.zig");
const glfw = @import("vendor/zglfw/src/glfw3.zig");
const debug_gl = @import("debug_gl.zig");
const AllShaders = @import("all_shaders.zig").AllShaders;
const StaticGeometry = @import("static_geometry.zig").StaticGeometry;
const pieces = @import("pieces.zig");
const Piece = pieces.Piece;
const Spritesheet = @import("spritesheet.zig").Spritesheet;

var all_shaders: AllShaders = undefined;
var static_geometry: StaticGeometry = undefined;
var font: Spritesheet = undefined;

fn errorCallback(err: c_int, description: [*c]const u8) callconv(.C) void {
    panic("Error: {}\n", .{@as([*:0]const u8, description)});
}

fn keyCallback(win: *glfw.Window, key: c_int, scancode: c_int, action: c_int, mods: c_int) callconv(.C) void {
    if (action != @enumToInt(glfw.KeyState.Press)) return;
    const t = @ptrCast(*Tetris, @alignCast(@alignOf(Tetris), glfw.getWindowUserPointer(win).?));

    const key_enum = @intToEnum(glfw.Key, key);
    switch (key_enum) {
        glfw.Key.Escape => glfw.setWindowShouldClose(win, true),
        glfw.Key.Space => tetris.userDropCurPiece(t),
        glfw.Key.Down => tetris.userCurPieceFall(t),
        glfw.Key.Left => tetris.userMoveCurPiece(t, -1),
        glfw.Key.Right => tetris.userMoveCurPiece(t, 1),
        glfw.Key.Up => tetris.userRotateCurPiece(t, 1),
        glfw.Key.LeftShift, glfw.Key.RightShift => tetris.userRotateCurPiece(t, -1),
        glfw.Key.R => tetris.restartGame(t),
        glfw.Key.P => tetris.userTogglePause(t),
        glfw.Key.LeftControl, glfw.Key.RightControl => tetris.userSetHoldPiece(t),
        else => {},
    }
}

var tetris_state: Tetris = undefined;

const font_png = @embedFile("../assets/font.png");

pub fn main() !void {
    _ = glfw.setErrorCallback(errorCallback);

    try glfw.init();
    defer glfw.terminate();

    glfw.windowHint(glfw.WindowHint.ContextVersionMajor, 3);
    glfw.windowHint(glfw.WindowHint.ContextVersionMinor, 2);
    glfw.windowHint(glfw.WindowHint.OpenGLForwardCompat, @as(c_int, c.GL_TRUE));
    glfw.windowHint(glfw.WindowHint.OpenGLDebugContext, debug_gl.is_on);
    glfw.windowHint(glfw.WindowHint.OpenGLProfile, @enumToInt(glfw.GLProfileAttribute.OpenglCoreProfile));
    glfw.windowHint(glfw.WindowHint.DepthBits, 0);
    glfw.windowHint(glfw.WindowHint.StencilBits, 8);
    glfw.windowHint(glfw.WindowHint.Resizable, @as(c_int, c.GL_FALSE));

    var window = try glfw.createWindow(tetris.window_width, tetris.window_height, "Tetris", null, null);
    defer glfw.destroyWindow(window);

    _ = glfw.setKeyCallback(window, keyCallback);
    glfw.makeContextCurrent(window);
    glfw.swapInterval(1);

    // create and bind exactly one vertex array per context and use
    // glVertexAttribPointer etc every frame.
    var vertex_array_object: c.GLuint = undefined;
    c.glGenVertexArrays(1, &vertex_array_object);
    c.glBindVertexArray(vertex_array_object);
    defer c.glDeleteVertexArrays(1, &vertex_array_object);

    const t = &tetris_state;
    glfw.getFramebufferSize(window, &t.framebuffer_width, &t.framebuffer_height);
    assert(t.framebuffer_width >= tetris.window_width);
    assert(t.framebuffer_height >= tetris.window_height);

    all_shaders = try AllShaders.create();
    defer all_shaders.destroy();

    static_geometry = StaticGeometry.create();
    defer static_geometry.destroy();

    font.init(font_png, tetris.font_char_width, tetris.font_char_height) catch {
        panic("unable to read assets\n", .{});
    };
    defer font.deinit();

    var seed_bytes: [@sizeOf(u64)]u8 = undefined;
    std.crypto.randomBytes(seed_bytes[0..]) catch |err| {
        panic("unable to seed random number generator: {}", .{err});
    };
    t.prng = std.rand.DefaultPrng.init(std.mem.readIntNative(u64, &seed_bytes));
    t.rand = &t.prng.random;

    tetris.resetProjection(t);

    tetris.restartGame(t);

    c.glClearColor(0.0, 0.0, 0.0, 1.0);
    c.glEnable(c.GL_BLEND);
    c.glBlendFunc(c.GL_SRC_ALPHA, c.GL_ONE_MINUS_SRC_ALPHA);
    c.glPixelStorei(c.GL_UNPACK_ALIGNMENT, 1);

    c.glViewport(0, 0, t.framebuffer_width, t.framebuffer_height);
    glfw.setWindowUserPointer(window, @ptrCast(*c_void, t));

    debug_gl.assertNoError();

    const start_time = glfw.getTime();
    var prev_time = start_time;

    while (!glfw.windowShouldClose(window)) {
        c.glClear(c.GL_COLOR_BUFFER_BIT | c.GL_DEPTH_BUFFER_BIT | c.GL_STENCIL_BUFFER_BIT);

        const now_time = glfw.getTime();
        const elapsed = now_time - prev_time;
        prev_time = now_time;

        tetris.nextFrame(t, elapsed);

        tetris.draw(t, @This());
        glfw.swapBuffers(window);

        glfw.pollEvents();
    }

    debug_gl.assertNoError();
}

pub fn fillRectMvp(t: *Tetris, color: Vec4, mvp: Mat4x4) void {
    all_shaders.primitive.bind();
    all_shaders.primitive.setUniformVec4(all_shaders.primitive_uniform_color, color);
    all_shaders.primitive.setUniformMat4x4(all_shaders.primitive_uniform_mvp, mvp);

    c.glBindBuffer(c.GL_ARRAY_BUFFER, static_geometry.rect_2d_vertex_buffer);
    c.glEnableVertexAttribArray(@intCast(c.GLuint, all_shaders.primitive_attrib_position));
    c.glVertexAttribPointer(@intCast(c.GLuint, all_shaders.primitive_attrib_position), 3, c.GL_FLOAT, c.GL_FALSE, 0, null);

    c.glDrawArrays(c.GL_TRIANGLE_STRIP, 0, 4);
}

pub fn drawParticle(t: *Tetris, p: tetris.Particle) void {
    const model = mat4x4_identity.translateByVec(p.pos).rotate(p.angle, p.axis).scale(p.scale_w, p.scale_h, 0.0);

    const mvp = t.projection.mult(model);

    all_shaders.primitive.bind();
    all_shaders.primitive.setUniformVec4(all_shaders.primitive_uniform_color, p.color);
    all_shaders.primitive.setUniformMat4x4(all_shaders.primitive_uniform_mvp, mvp);

    c.glBindBuffer(c.GL_ARRAY_BUFFER, static_geometry.triangle_2d_vertex_buffer);
    c.glEnableVertexAttribArray(@intCast(c.GLuint, all_shaders.primitive_attrib_position));
    c.glVertexAttribPointer(@intCast(c.GLuint, all_shaders.primitive_attrib_position), 3, c.GL_FLOAT, c.GL_FALSE, 0, null);

    c.glDrawArrays(c.GL_TRIANGLE_STRIP, 0, 3);
}

pub fn drawText(t: *Tetris, text: []const u8, left: i32, top: i32, size: f32) void {
    for (text) |col, i| {
        if (col <= '~') {
            const char_left = @intToFloat(f32, left) + @intToFloat(f32, i * tetris.font_char_width) * size;
            const model = mat4x4_identity.translate(char_left, @intToFloat(f32, top), 0.0).scale(size, size, 0.0);
            const mvp = t.projection.mult(model);

            font.draw(all_shaders, col, mvp);
        } else {
            unreachable;
        }
    }
}
