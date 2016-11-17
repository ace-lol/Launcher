/*
 * The following file has been adapted from Semver.Swift by di wu.
 * See it's original source at: https://github.com/weekwood/Semver.Swift.
 *
 * Semver.Swift was released under the MIT license:
 * Copyright (c) 2015 di wu <di.wu@me.com>
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */
import Foundation

struct Regex {
    var pattern: String {
        didSet {
            updateRegex()
        }
    }
    
    var expressionOptions: NSRegularExpression.Options {
        didSet {
            updateRegex()
        }
    }
    
    var matchingOptions: NSRegularExpression.MatchingOptions
    var regex: NSRegularExpression?
    
    init(pattern: String, expressionOptions: NSRegularExpression.Options, matchingOptions: NSRegularExpression.MatchingOptions) {
        self.pattern = pattern
        self.expressionOptions = expressionOptions
        self.matchingOptions = matchingOptions
        updateRegex()
    }
    
    init(pattern: String) {
        self.pattern = pattern
        expressionOptions = NSRegularExpression.Options.caseInsensitive
        matchingOptions = NSRegularExpression.MatchingOptions.reportProgress
        updateRegex()
    }
    
    mutating func updateRegex() {
        do {
            regex = try NSRegularExpression(pattern: pattern, options: expressionOptions)
        } catch {
            print(error)
        }
    }
}

extension String {
    func matchRegex(pattern: Regex) -> Bool {
        let range: NSRange = NSMakeRange(0, characters.count)
        if pattern.regex != nil {
            let matches: [AnyObject] = pattern.regex!.matches(in: self, options: pattern.matchingOptions, range: range)
            return matches.count > 0
        }
        return false
    }
    
    func match(patternString: String) -> Bool {
        return self.matchRegex(pattern: Regex(pattern: patternString))
    }
    
    func replaceRegex(pattern: Regex, template: String) -> String {
        if self.matchRegex(pattern: pattern) {
            let range: NSRange = NSMakeRange(0, characters.count)
            if pattern.regex != nil {
                return pattern.regex!.stringByReplacingMatches(in: self, options: pattern.matchingOptions, range: range, withTemplate: template)
            }
        }
        return self
    }
    
    func replace(pattern: String, template: String) -> String {
        return self.replaceRegex(pattern: Regex(pattern: pattern), template: template)
    }
}


public class Semver {
    let SemVerRegexp = "\\A(\\d+\\.\\d+\\.\\d+)(-([0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*))?(\\+([0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*))?\\Z"
    
    var major: String = ""
    var minor: String = ""
    var patch: String = ""
    var pre: String = ""
    var build: String = ""
    var versionStr: String = ""
    
    let BUILD_DELIMITER: String = "+"
    let PRERELEASE_DELIMITER: String = "-"
    let VERSION_DELIMITER: String  = "."
    let IGNORE_PREFIX: String = "v"
    let IGNORE_EQ: String = "="
    
    required public init() {
        
    }
    
    public class func version() -> String {
        return "0.1.2"
    }
    
    convenience init(version: String!) {
        self.init()
        self.versionStr = version
        if valid(){
            var v = versionStr.components(separatedBy: VERSION_DELIMITER) as Array
            major = v[0]
            minor = v[1]
            patch = v[2]
            
            var prerelease = versionStr.components(separatedBy: PRERELEASE_DELIMITER) as Array
            if (prerelease.count > 1) {
                pre = prerelease[1]
            }
            
            var buildVersion = versionStr.components(separatedBy: BUILD_DELIMITER) as Array
            if (buildVersion.count > 1) {
                build = buildVersion[1]
            }
        }
    }
    
    func diff(_ version2: String) -> Int {
        let version = Semver(version: version2)
        if (major.compare(version.major) != .orderedSame) {
            return major.compare(version.major).rawValue
        }
        
        if (minor.compare(version.minor) != .orderedSame) {
            return minor.compare(version.minor).rawValue
        }
        
        if (patch.compare(version.patch) != .orderedSame) {
            return patch.compare(version.patch, options: NSString.CompareOptions.numeric).rawValue
        }
        
        return 0
    }
    
    public class func valid(version: String) -> Bool {
        return Semver(version: version).valid()
    }
    
    public func valid() -> Bool{
        if let _ = versionStr.range(of: SemVerRegexp, options: .regularExpression) {
            return true
        }
        return false
    }
    
    public class func clean(version: String) -> String{
        return Semver(version: version).clean()
    }
    
    public func clean() -> String{
        versionStr = versionStr.trimmingCharacters(in: NSCharacterSet.whitespaces)
        return versionStr.replace(pattern: "^[=v]+", template: "")
    }
    
    public class func gt(_ version1: String, _ version2: String) -> Bool {
        return Semver(version: version1).diff(version2) > 0
    }
    
    public class func lt(_ version1: String, _ version2: String) -> Bool {
        return Semver(version: version1).diff(version2) < 0
    }
    
    public class func gte(_ version1: String, _ version2: String) -> Bool {
        return Semver(version: version1).diff(version2) >= 0
    }
    
    public class func lte(_ version1: String, _ version2: String) -> Bool {
        return Semver(version: version1).diff(version2) <= 0
    }
    
    public class func eq(_ version1: String, _ version2: String) -> Bool {
        return Semver(version: version1).diff(version2) == 0
    }
}
