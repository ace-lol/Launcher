import Foundation
import Cocoa

// Checks if the specified path to an .app bundle is most likely the league installation.
func is_valid_binary(_ path: String) -> Bool {
    return FileManager.default.fileExists(atPath: binary_path)
        && FileManager.default.fileExists(atPath: binary_path + "/Contents/LoL/RADS/projects/league_client")
        && FileManager.default.fileExists(atPath: binary_path + "/Contents/LoL/LeagueClient.app")
}

// Runs a simple shell command using `/bin/sh -c "CMD"`
func exec_shell(_ cmd: String) -> Process {
    let task = Process()
    task.launchPath = "/bin/sh"
    task.arguments = ["-c", cmd]
    task.launch()
    return task
}

// TODO(molenzwiebel): Updating
// Make sure to kill ace_daemon so that it loads the new version if available

// Find the path to the LCU, either from saved configs or the default.
var binary_path = UserDefaults.standard.string(forKey: "leagueclient_path") ?? "/Applications/League of Legends.app"
var valid = is_valid_binary(binary_path)

while !valid {
    // Notify that the path could not be found.
    let alert = NSAlert()
    alert.messageText = "Ace could not find the LCU at \(binary_path). Please check that you selected the correct 'League of Legends.app'."
    alert.runModal()
    
    // Prompt for a new path.
    let fileDialog = NSOpenPanel()
    fileDialog.allowedFileTypes = ["app"]
    fileDialog.runModal()
    
    if let url = fileDialog.url {
        binary_path = url.path
        valid = is_valid_binary(binary_path)
    } else {
        // User pressed cancel. Exit.
        exit(1)
    }
}

// Save the path for next time
UserDefaults.standard.setValue(binary_path, forKey: "leagueclient_path")
UserDefaults.standard.synchronize()

// Check if the daemon is already running
let task = exec_shell("ps -Ac | grep 'ace_daemon' > /dev/null")
task.waitUntilExit()

if task.terminationStatus == 1 {
    // Start ace_daemon
    let resources_path = Bundle.main.bundlePath + "/Contents/Resources"
    let _ = exec_shell("cd '\(resources_path)' && ./ace_daemon")
}

// Find the paths for the things we want to inject.
let dylib_path = Bundle.main.path(forResource: "payload", ofType: "dylib")!
let inject_path = Bundle.main.path(forResource: "inject", ofType: "js")!

// Construct command that launches league.
let command = "cd '\(binary_path)/Contents/LoL' && DYLD_FORCE_FLAT_NAMESPACE=1 DYLD_INSERT_LIBRARIES='\(dylib_path)' ACE_PAYLOAD_PATH='\(inject_path)' LeagueClient.app/Contents/MacOS/LeagueClient"

// Liftoff!
let _ = exec_shell(command)
