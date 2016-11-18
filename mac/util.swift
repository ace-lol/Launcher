import Foundation

/**
 Checks if the specified path to an .app bundle is most likely the league installation.
 
 - parameter binary_path: The path to the binary
 - returns: Whether the path most likely contains a valid LCU installation.
 */
func isValidBinary(_ path: String) -> Bool {
    return FileManager.default.fileExists(atPath: path)
        && FileManager.default.fileExists(atPath: path + "/Contents/LoL/RADS/projects/league_client")
        && FileManager.default.fileExists(atPath: path + "/Contents/LoL/LeagueClient.app")
}

/**
 Runs the provided command as a shell string, internally using `/bin/sh -c "CMD"`.
 
 - parameter cmd: The shell code to execute.
 - returns: A handle to the spawned process.
 */
func execShell(_ cmd: String) -> Process {
    let task = Process()
    task.launchPath = "/bin/sh"
    task.arguments = ["-c", cmd]
    task.launch()
    return task
}


/**
 Parses the bundle.js file in the current app bundle, looking for the string
 `window.ACE_VERSION = "(.*)"`. If found, returns the version (string contents).
 
 - returns: The version found.
 - throws: If the file could not be loaded or if the string was not found.
 */
func getBundleVersion() throws -> String {
    let bundlePath = Bundle.main.path(forResource: "bundle", ofType: "js")!
    let bundleContents = try String(contentsOfFile: bundlePath)
    
    let regexp = try NSRegularExpression(pattern: "window\\.ACE_VERSION\\s?=\\s?\"(.*?)\"", options: [])
    let regexpMatch = regexp.firstMatch(in: bundleContents, options: [], range: NSMakeRange(0, bundleContents.characters.count))
    let range = regexpMatch!.rangeAt(1)
    let r = bundleContents.index(bundleContents.startIndex, offsetBy: range.location) ..< bundleContents.index(bundleContents.startIndex, offsetBy: range.location + range.length)
    
    return bundleContents.substring(with: r)
}

/**
 Makes a synchronous request to the provided URL, returning the Data received.
 
 - parameter url: The URL to request.
 - returns: The data received from the request.
 - throws: If the request failed for any reason.
 */
func requestSync(url: String) throws -> Data {
    let url = URL(string: url)!
    let request = URLRequest(url: url)
    let semaphore = DispatchSemaphore(value: 0)
    var data: Data? = nil
    
    URLSession.shared.dataTask(with: request) {
        data = $0.0
        semaphore.signal()
    }.resume()
    
    let _ = semaphore.wait(timeout: .distantFuture)
    return data!
}
