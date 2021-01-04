# Tetris

A simple tetris clone written in [zig programming language](https://github.com/andrewrk/zig).

[Vimeo Demo](https://vimeo.com/481429586).

![demo screenshot](http://i.imgur.com/umuNndz.png)

[Windows 64-bit build](http://superjoe.s3.amazonaws.com/temp/tetris.zip)

## Controls

 * Left/Right/Down Arrow - Move piece left/right/down.
 * Up Arrow - Rotate piece clockwise.
 * Shift - Rotate piece counter clockwise.
 * Space - Drop piece immediately.
 * R - Start new game.
 * P - Pause and unpause game.
 * Escape - Quit.

## Dependencies

 * [Zig compiler](https://github.com/andrewrk/zig) - use the debug build.
 * [libepoxy](https://github.com/anholt/libepoxy)
 * [GLFW](http://www.glfw.org/) (used via the wrapper library [glfw3.zig](https://github.com/Iridescence-Technologies/zglfw))

## Building and Running

```sh
zig build play
```
