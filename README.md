# Launcher

Executable that launches the LCU with Ace loaded and ready to go.

## Building - Windows
_TODO_

## Building - Mac
Open the attached project in `mac/`. The project expects various resources to be present, which will need to be added:
- `ace_deamon`: The compiled Daemon executable.
- `payload.dylib`: The compiled Payload library.
- `bundle.js`: The packaged Ace JavaScript/HTML/css.

For all of the above, make sure that they are added to `Copy Bundle Resources` and that `payload.dylib` is _not_ added in `Link Binary with Libraries`.