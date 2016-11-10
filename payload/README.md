# Payload
The code that injects into the LCU, enabling the injection of the Ace bundle.

## Compiling
**Windows**: Build the provided Visual Studio project.  
**Mac**: Run the provided `compile_mac.sh` file.

## Manually Installing
Although the Launcher installs the payload, this can also be done manually.  
**Windows**: Navigate to `LCU_INSTALL_LOCATION/RADS/projects/league_client/releases/HIGHEST_NUMBER/deploy` and rename `libcef.dll` to `libcefOriginal.dll`. Then place the payload dll as `libcef.dll` in the same folder.  
**Mac**: Start the LCU using the following environment flags: `env DYLD_INSERT_LIBRARIES=PATH_TO_DYLIB`.  

Note that on both platforms, the payload expects environment variables `ACE_INITIAL_PAYLOAD` and `ACE_LOAD_PAYLOAD` to be present. If they are not present, the payload will enable remote debugging, but it will not inject any javascript file into the process.