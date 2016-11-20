import Foundation
import Cocoa

/**
 Starts ace using the provided path to the league app bundle.
 
 - parameter path: The path to 'League of Legends.app'.
 */
func startAce(path: String) {
    // Find the paths for the things we want to inject.
    let dylibPath = Bundle.main.path(forResource: "payload", ofType: "dylib")!
    let bundlePath = Bundle.main.path(forResource: "bundle", ofType: "js")!
    let injectPath = Bundle.main.path(forResource: "inject", ofType: "js")!
    
    // Construct command that launches league.
    let command = "cd '\(path)/Contents/LoL' && DYLD_INSERT_LIBRARIES='\(dylibPath)' ACE_INITIAL_PAYLOAD='\(bundlePath)' ACE_LOAD_PAYLOAD='\(injectPath)' LeagueClient.app/Contents/MacOS/LeagueClient"
    
    // Liftoff!
    execShell(command).waitUntilExit()
}

/**
 - returns: valid path to the league bundle, or nil if not provided by the user.
 */
func getLeagueAppPath() -> String? {
    // Find the path to the LCU, either from saved configs or the default.
    var appPath = UserDefaults.standard.string(forKey: "leagueclient_path") ?? "/Applications/League of Legends.app"
    var valid = isValidBinary(appPath)
    
    while !valid {
        // Notify that the path could not be found.
        let alert = NSAlert()
        alert.messageText = "Ace could not find the LCU at \(appPath). Please check that you selected the correct 'League of Legends.app'."
        alert.runModal()
        
        // Prompt for a new path.
        let fileDialog = NSOpenPanel()
        fileDialog.allowedFileTypes = ["app"]
        fileDialog.runModal()
        
        if let url = fileDialog.url {
            appPath = url.path
            valid = isValidBinary(appPath)
        } else {
            // User pressed cancel. Return NIL.
            return nil
        }
    }
    
    // Save the path for next time
    UserDefaults.standard.setValue(appPath, forKey: "leagueclient_path")
    UserDefaults.standard.synchronize()
    
    return appPath
}

/**
 Synchronously checks for an update. If found, downloads the new bundle and installs it.
 - returns: true if an update was found and installed, false otherwise.
 */
func update() -> Bool {
    guard let currentVer = try? getBundleVersion()
        else { return false }
    
    guard let githubReleases = try? requestSync(url: "https://api.github.com/repos/ace-lol/ace/releases")
        else { return false }
    
    guard let githubJson = try? JSONSerialization.jsonObject(with: githubReleases, options: []) as? Array<Any>
        else { return false }
    
    guard let lastRelease = githubJson?[0] as? [String: AnyObject]
        else { return false }
    
    guard let releaseTagname = lastRelease["tag_name"] as? String
        else { return false }
    
    // If the release isn't a valid semver or if the release isn't newer.
    if !Semver.valid(version: releaseTagname) || !Semver.gt(releaseTagname, currentVer) {
        return false
    }
    
    // Download new assets.
    guard let assets = lastRelease["assets"] as? Array<[String: AnyObject]>
        else { return false }
    
    let assetGroups = [("bundle.js", "bundle", "js"), ("inject.js", "inject", "js"), ("payload_mac.dylib", "payload", "dylib")]
    for group in assetGroups {
        if let asset = assets.first(where: { ($0["name"] as! String) == group.0 }) {
            guard let assetContents = try? requestSync(url: asset["browser_download_url"] as! String)
                else { return false }
            
            do {
                let bundleUrl = Bundle.main.url(forResource: group.1, withExtension: group.2)!
                try assetContents.write(to: bundleUrl)
            } catch {
                return false
            }
        }
    }
    
    return true
}

/**
 Synchronously kills the running LeagueClient process. Returns once the process is killed.
 */
func killLCU() {
    var lcu: NSRunningApplication? = nil
    
    for app in NSWorkspace.shared().runningApplications {
        if app.bundleURL?.lastPathComponent == "LeagueClient.app" {
            lcu = app
            break
        }
    }
    
    if let lcu = lcu {
        lcu.terminate()
        while true {
            // Poll the status of the process we just killed.
            // This returns 0 if the process is still alive.
            // We cannot use lcu.isTerminated since it only updates during
            // a foundation run loop. Since we block the thread, no run loops
            // are triggered, and such the property does not update.
            let task = execShell("kill -0 \(lcu.processIdentifier) &> /dev/null")
            task.waitUntilExit()
            
            if task.terminationStatus != 0 {
                break
            }
            
            // Wait for 100ms
            usleep(100_000)
        }
    }
}

// ==== Main code ====
if let lcuPath = getLeagueAppPath() {
    if ProcessInfo().isOperatingSystemAtLeast(OperatingSystemVersion(majorVersion: 10, minorVersion: 12, patchVersion: 0)) {
        // Launch the LCU with ace injected.
        startAce(path: lcuPath)
    
        // If we updated, let the user know.
        if update() {
            let alert = NSAlert()
            alert.messageText = "Ace has downloaded and installed an update, which will become active with the next restart of the League client. Do you want to restart the     League client now?"
            alert.addButton(withTitle: "Restart")
            alert.addButton(withTitle: "Later")
    
            // If the user wants to restart, kill the LCU and start it again.
            if alert.runModal() == NSAlertFirstButtonReturn {
                killLCU()
                startAce(path: lcuPath)
           }
        }
    } else {
        let alert = NSAlert()
        alert.messageText = "Ace is not currently compatible with versions of macOS before 10.12."
        alert.addButton(withTitle: "rip")
        alert.runModal()
        exit(0)
    }
}
