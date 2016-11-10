using System;
using System.IO;
using Microsoft.WindowsAPICodePack.Dialogs;
using System.Windows.Forms;
using System.Diagnostics;
using System.Text;
using System.Linq;

namespace Ace
{
    static class Program
    {
        /// <summary>
        /// The main entry point for the application.
        /// </summary>
        [STAThread]
        static void Main()
        {
            try {
                String path = Properties.Settings.Default.LCUPath;
                Boolean valid = IsPathValid(path);

                while (!valid)
                {
                    // Notify that the path is invalid.
                    MessageBox.Show(
                        "Ace could not find the LCU at " + path + ". Please select the folder containing 'LeagueClient.exe'.",
                        "LCU not found",
                        MessageBoxButtons.OK,
                        MessageBoxIcon.Exclamation
                    );

                    // Ask for new path.
                    CommonOpenFileDialog dialog = new CommonOpenFileDialog();
                    dialog.Title = "Select LeagueClient.exe location.";
                    dialog.InitialDirectory = "C:/Riot Games";
                    dialog.EnsureFileExists = true;
                    dialog.EnsurePathExists = true;
                    dialog.DefaultFileName = "LeagueClient";
                    dialog.DefaultExtension = "exe";
                    dialog.Filters.Add(new CommonFileDialogFilter("Executables", ".exe"));
                    dialog.Filters.Add(new CommonFileDialogFilter("All Files", ".*"));
                    if (dialog.ShowDialog() == CommonFileDialogResult.Cancel)
                    {
                        // User wants to cancel. Exit
                        return;
                    }

                    path = dialog.FileName;
                    valid = IsPathValid(path);
                }

                // Store choice so we don't have to ask for it again.
                Properties.Settings.Default.LCUPath = path;
                Properties.Settings.Default.Save();

                String tmpDir = Path.Combine(Path.GetTempPath(), "ace");
                if (!Directory.Exists(tmpDir)) Directory.CreateDirectory(tmpDir);

                String injectJsPath = Path.Combine(tmpDir, "inject.js");
                File.WriteAllBytes(injectJsPath, Encoding.UTF8.GetBytes(Properties.Resources.inject));

                String bundleJsPath = Path.Combine(tmpDir, "bundle.js");
                File.WriteAllBytes(bundleJsPath, Encoding.UTF8.GetBytes(Properties.Resources.bundle));

                String releasePath = GetClientProjectPath(path);

                // If league has marked the installation as invalid, the restore will overwrite our changes.
                // We want to make sure that the user knows this.
                if (File.Exists(releasePath + "/RestoreBackup"))
                {
                    MessageBox.Show(
                        "League has marked the LCU installation as corrupt and will attempt to repair the installation when we start it. This will overwrite the changes that Ace applies. In order to fix this, let the installation fully repair itself and then close the League client using the X in the top right corner. After that, start Ace again to reinstall Ace into your League installation.",
                        "Warning",
                        MessageBoxButtons.OK,
                        MessageBoxIcon.Warning
                    );
                }

                // If libcefOriginal.dll doesn't exist, this is our first run (or after a patch).
                if (!File.Exists(releasePath + "/deploy/libcefOriginal.dll"))
                {
                    File.Move(releasePath + "/deploy/libcef.dll", releasePath + "/deploy/libcefOriginal.dll");
                }

                // Overwrite the dll every time, just in case.
                File.WriteAllBytes(releasePath + "/deploy/libcef.dll", Properties.Resources.Payload);

                // Start league :)
                ProcessStartInfo startInfo = new ProcessStartInfo { FileName = path, UseShellExecute = false };
                startInfo.EnvironmentVariables["ACE_INITIAL_PAYLOAD"] = bundleJsPath;
                startInfo.EnvironmentVariables["ACE_LOAD_PAYLOAD"] = injectJsPath;
                Process.Start(startInfo);
            } catch(Exception e) {
                MessageBox.Show("An error occured during startup. Please try again and do not hesitate to report the issue if it does not resolve itself. The error was: " + e.ToString(), "Error during startup.", MessageBoxButtons.OK, MessageBoxIcon.Exclamation);
            }
        }

        // Checks if the provided path is most likely a path where the LCU is installed.
        static Boolean IsPathValid(String path)
        {
            String folder = Path.GetDirectoryName(path);
            return File.Exists(path) && Directory.Exists(folder + "/RADS") && Directory.Exists(folder + "/RADS/projects/league_client");
        }

        // Finds the newest league_client release and returns the path to that release.
        static String GetClientProjectPath(String path)
        {
            String p = Path.GetDirectoryName(path) + "/RADS/projects/league_client/releases";
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
