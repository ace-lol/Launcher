# Payload

The core that enables Ace to inject into the League Client.

## Compiling
**Windows**: Build the provided Visual Studio project.  
**Mac**: Run the provided `compile_mac.sh` file.

## Manually Installing
Although the Launcher installs the payload, this can also be done manually.  
**Windows**: Navigate to `LCU_INSTALL_LOCATION/RADS/projects/league_client/releases/HIGHEST_NUMBER/deploy` and rename `libcef.dll` to `libcefOriginal.dll`. Then place the payload dll as `libcef.dll` in the same folder.  
**Mac**: Start the LCU using the following environment flags: `env DYLD_FORCE_FLAT_NAMESPACE=1 DYLD_INSERT_LIBRARIES=PATH_TO_DYLIB`.  

Note that on both platforms, the payload expects an environment variable `ACE_PAYLOAD_PATH` to be present. If it is not present, the payload will enable remote debugging, but it will not inject any javascript file into the process.