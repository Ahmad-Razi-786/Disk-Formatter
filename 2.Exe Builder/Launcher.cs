using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Windows.Forms;

static class Program
{
    [STAThread]
    static int Main()
    {
        try
        {
            string tmp = Path.Combine(Path.GetTempPath(), "DiskFormatter_" + Guid.NewGuid().ToString("N") + ".ps1");
            using (Stream s = Assembly.GetExecutingAssembly().GetManifestResourceStream("DiskFormatter.ps1"))
            {
                if (s == null) { MessageBox.Show("Embedded script not found.", "Disk Formatter"); return 1; }
                using (FileStream f = File.Create(tmp)) { s.CopyTo(f); }
            }

            // Always use the 64-bit PowerShell on 64-bit Windows (Get-Disk needs it).
            string win = Environment.GetEnvironmentVariable("windir");
            string ps = Path.Combine(win, @"System32\WindowsPowerShell\v1.0\powershell.exe");
            if (Environment.Is64BitOperatingSystem && !Environment.Is64BitProcess)
                ps = Path.Combine(win, @"Sysnative\WindowsPowerShell\v1.0\powershell.exe");

            // Dot-source the script so everything lives in one global scope.
            string args = "-NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -Command \". '" + tmp.Replace("'", "''") + "'\"";
            ProcessStartInfo psi = new ProcessStartInfo(ps, args);
            psi.UseShellExecute = false;
            psi.CreateNoWindow = true;
            using (Process p = Process.Start(psi)) { p.WaitForExit(); }
            try { File.Delete(tmp); } catch { }
            return 0;
        }
        catch (Exception ex)
        {
            MessageBox.Show("Disk Formatter could not start:\n\n" + ex.Message, "Disk Formatter");
            return 1;
        }
    }
}
