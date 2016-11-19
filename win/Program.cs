using System;
using System.IO;
using Microsoft.WindowsAPICodePack.Dialogs;
using System.Windows.Forms;
using System.Diagnostics;
using System.Text;
using System.Text.RegularExpressions;
using System.Linq;
using System.Net;
using Semver;

namespace Ace
{
    static class Program
    {
        static string dataDir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "Ace");

        /// <summary>
        /// The main entry point for the application.
        /// </summary>
        [STAThread]
        static void Main()
        {
            try {
                if (!Directory.Exists(dataDir)) Directory.CreateDirectory(dataDir);

                string path = GetLCUPath();
                if (path == null) return;

                // If league is already running, prompt to kill it.
                if (Process.GetProcessesByName("LeagueClient").Length > 0)
                {
                    DialogResult promptResult = MessageBox.Show(
                        "The League client is already running. Do you want to stop it?",
                        "Ace",
                        MessageBoxButtons.OKCancel,
                        MessageBoxIcon.Information,
                        MessageBoxDefaultButton.Button1
                    );

                    if (promptResult == DialogResult.OK)
                    {
                        KillLCU();
                    } else {
                        // Stop ace.
                        return;
                    }
                }

                LaunchLCU(path);

                if (Update())
                {
                    DialogResult promptResult = MessageBox.Show(
                        "Ace has downloaded and installed an update, which will become active with the next restart of the League client. Do you want to restart the League client now?",
                        "Ace Updater",
                        MessageBoxButtons.YesNo,
                        MessageBoxIcon.Information,
                        MessageBoxDefaultButton.Button1
                    );

                    if (promptResult == DialogResult.Yes)
                    {
                        // Kill LCU, then restart it.
                        KillLCU();
                        LaunchLCU(path);
                    }
                }
            } catch (Exception e) {
                MessageBox.Show("An error occured during startup. Please try again and do not hesitate to report the issue if it does not resolve itself. The error was: " + e.ToString(), "Error during startup.", MessageBoxButtons.OK, MessageBoxIcon.Exclamation);
            }
        }

        // Launches the LCU with the provided path.
        static void LaunchLCU(string path)
        {
            string injectJsPath = Path.Combine(dataDir, "inject.js");
            string bundleJsPath = Path.Combine(dataDir, "bundle.js");
            string payloadDllPath = Path.Combine(dataDir, "payload.dll");

            // If the directory didn't exist, create it and copy the files.
            if (!File.Exists(bundleJsPath))
            {
                File.WriteAllBytes(injectJsPath, Encoding.UTF8.GetBytes(Properties.Resources.inject));
                File.WriteAllBytes(bundleJsPath, Encoding.UTF8.GetBytes(Properties.Resources.bundle));
                File.WriteAllBytes(payloadDllPath, Properties.Resources.Payload);
            }            

            string releasePath = GetClientProjectPath(path);

            // If libcefOriginal.dll doesn't exist, this is our first run (or after a patch).
            if (!File.Exists(releasePath + "/deploy/libcefOriginal.dll"))
            {
                File.Move(releasePath + "/deploy/libcef.dll", releasePath + "/deploy/libcefOriginal.dll");
            }

            File.Copy(payloadDllPath, releasePath + "/deploy/libcef.dll", true);

            // Start league :)
            ProcessStartInfo startInfo = new ProcessStartInfo { FileName = path, UseShellExecute = false };
            startInfo.EnvironmentVariables["ACE_INITIAL_PAYLOAD"] = bundleJsPath;
            startInfo.EnvironmentVariables["ACE_LOAD_PAYLOAD"] = injectJsPath;
            Process.Start(startInfo);
        }

        // Either gets the LCU path from the saved properties, or by prompting the user.
        static string GetLCUPath()
        {
            string configPath = Path.Combine(dataDir, "lcuPath");
            string path = File.Exists(configPath) ? File.ReadAllText(configPath) : "C:/Riot Games/League of Legends/LeagueClient.exe";
            bool valid = IsPathValid(path);

            while (!valid)
            {
                // Notify that the path is invalid.
                MessageBox.Show(
                    "Ace could not find the LCU at " + path + ". Please select the location of 'LeagueClient.exe'.",
                    "LCU not found",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Exclamation
                );

                // Ask for new path.
                CommonOpenFileDialog dialog = new CommonOpenFileDialog();
                dialog.Title = "Select LeagueClient.exe location.";
                dialog.InitialDirectory = "C:\\Riot Games\\League of Legends";
                dialog.EnsureFileExists = true;
                dialog.EnsurePathExists = true;
                dialog.DefaultFileName = "LeagueClient";
                dialog.DefaultExtension = "exe";
                dialog.Filters.Add(new CommonFileDialogFilter("Executables", ".exe"));
                dialog.Filters.Add(new CommonFileDialogFilter("All Files", ".*"));
                if (dialog.ShowDialog() == CommonFileDialogResult.Cancel)
                {
                    // User wants to cancel. Exit
                    return null;
                }

                path = dialog.FileName;
                valid = IsPathValid(path);
            }

            // Store choice so we don't have to ask for it again.
            File.WriteAllText(configPath, path);

            return path;
        }

        // Possibly updates to a new version of Ace. This method is blocking.
        // Returns true if an update was applied, false otherwise.
        static bool Update()
        {
            try {
                string json = Encoding.UTF8.GetString(RequestURL("https://api.github.com/repos/ace-lol/ace/releases").ToArray());
                JsonArray data = SimpleJson.DeserializeObject<JsonArray>(json);
                if (data.Count < 1) return false;

                JsonObject latest = (JsonObject)data[0];
                string release = (string)latest["tag_name"];
                if (release == null) return false;

                SemVersion newVer;
                // If the semver isn't valid or if we are already on the newest version.
                if (!SemVersion.TryParse(release, out newVer) || newVer <= GetBundleVersion()) return false;

                JsonArray assets = (JsonArray) latest["assets"];
                if (assets == null) return false;
                if (assets.Count < 1) return false;

                string[][] updateGroups = new string[][] {
                    new string[]{ "bundle.js", "bundle.js" },
                    new string[]{ "inject.js", "inject.js" },
                    new string[]{ "payload_win.dll", "payload.dll" }
                };

                foreach (string[] group in updateGroups)
                {
                    JsonObject asset = (JsonObject)assets.Find(x => ((string)((JsonObject)x)["name"]) == group[0]);
                    if (asset == null) continue;

                    string path = Path.Combine(dataDir, group[1]);

                    MemoryStream newData = RequestURL(((string) asset["browser_download_url"]));
                    if (newData == null) return false;

                    File.WriteAllBytes(path, newData.ToArray());
                }

                return true;
            } catch (Exception ex) {
                Console.WriteLine("error: " + ex);
                return false;
            }
        }

        // Tries to find the current version from the currently installed bundle.
        static string GetBundleVersion()
        {
            string bundleJsPath = Path.Combine(dataDir, "bundle.js");

            string contents = File.ReadAllText(bundleJsPath);
            Match match = Regex.Match(contents, "window\\.ACE_VERSION\\s?=\\s?\"(.*?)\"");
            return match.Groups[1].ToString();
        }

        // Makes a synchronous request to the provided URL.
        static MemoryStream RequestURL(string url)
        {
            HttpWebRequest request = (HttpWebRequest) WebRequest.Create(url);
            request.UserAgent = "Ace"; // Somehow the response is malformed if we don't send a user agent. See http://stackoverflow.com/questions/2482715/the-server-committed-a-protocol-violation-section-responsestatusline-error
            request.AutomaticDecompression = DecompressionMethods.GZip | DecompressionMethods.Deflate;

            using (WebResponse response = request.GetResponse())
            using (Stream stream = response.GetResponseStream())
            {
                MemoryStream ms = new MemoryStream();
                stream.CopyTo(ms);
                return ms;
            }
        }

        // Kills the running LCU instance, if applicable.
        static void KillLCU()
        {
            Process[] lcuCandidates = Process.GetProcessesByName("LeagueClient");
            if (lcuCandidates.Length == 1)
            {
                Process lcu = lcuCandidates[0];
                lcu.Kill();
                lcu.WaitForExit();
                System.Threading.Thread.Sleep(1000);
            }
        }

        // Checks if the provided path is most likely a path where the LCU is installed.
        static bool IsPathValid(string path)
        {
            string folder = Path.GetDirectoryName(path);
            return File.Exists(path) && Directory.Exists(folder + "/RADS") && Directory.Exists(folder + "/RADS/projects/league_client");
        }

        // Finds the newest league_client release and returns the path to that release.
        static string GetClientProjectPath(string path)
        {
            string p = Path.GetDirectoryName(path) + "/RADS/projects/league_client/releases";
            return Directory.GetDirectories(p).Select(x => {
                try
                {
                    // Convert 0.0.0.29 to 29.
                    return new { Path = x, Version = int.Parse(Path.GetFileName(x).Replace(".", "")) };
                }
                catch (FormatException)
                {
                    // Invalid path, -1.
                    return new { Path = x, Version = -1 };
                }
            }).OrderBy(x => x.Version).Last().Path;
        }
    }
}
