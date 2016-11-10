# Launcher

Executable that launches the LCU with Ace loaded and ready to go.

## Building - Windows
Open the attached project in `win/`. The project expects various resources to be present, which will need to be added (right click Project -> Properties -> Resources):
- `inject.js`: The inject.js file in the root of this repository.
- `Payload.dll`: The compiled Payload DLL. Instructions for compiling the payload can be found at `payload/README.md`.
- `bundle.js`: The packaged Ace JavaScript/HTML/css.  
**The files will need to have these exact names!**

When distributing, use [ILMerge](https://www.microsoft.com/en-us/download/details.aspx?id=17630) to merge the code pack DLLs into a single executable (this is not needed during development).

## Building - Mac
Open the attached project in `mac/`. The project automatically compiles `payload.dylib` using `compile_mac.sh` in `payload/` as part of the build process, so ignore that Xcode shows it as missing. The project expects a `bundle.js` file with the bundled Ace source, which needs to be added manually. Make sure that when adding `bundle.js`, the file is added to the target and is listed in `Copy Bundle Resources`.