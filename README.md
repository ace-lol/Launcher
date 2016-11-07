# Launcher

Executable that launches the LCU with Ace loaded and ready to go.

## Building - Windows
Open the attached project in `win/`. The project expects various resources to be present, which will need to be added (right click Project -> Properties -> Resources):
- `inject.js`: The inject.js file in the root of this repository.
- `ace_daemon.exe`: The compiled Daemon executable.
- `Payload.dll`: The compiled Payload DLL.
- `bundle.js`: The packaged Ace JavaScript/HTML/css.  
**The files will need to have these exact names!**

When distributing, use [ILMerge](https://www.microsoft.com/en-us/download/details.aspx?id=17630) to merge the code pack DLLs into a single executable (this is not needed during development).

## Building - Mac
Open the attached project in `mac/`. The project expects various resources to be present, which will need to be added:
- `ace_deamon`: The compiled Daemon executable.
- `payload.dylib`: The compiled Payload library.
- `bundle.js`: The packaged Ace JavaScript/HTML/css.

For all of the above, make sure that they are added to `Copy Bundle Resources` and that `payload.dylib` is _not_ added in `Link Binary with Libraries`.