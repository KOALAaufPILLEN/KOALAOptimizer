using System;
using System.Collections.ObjectModel;
using System.IO;
using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Threading;
using KOALAOptimizer.Testing.Models;

namespace KOALAOptimizer.Testing.Services
{
    /// <summary>
    /// Centralized logging service for the application
    /// </summary>
    public class LoggingService
    {
        private static readonly Lazy<LoggingService> _instance = new Lazy<LoggingService>(() => new LoggingService());
        public static LoggingService Instance => _instance.Value;
        
        private readonly object _lock = new object();
        private readonly string _logFilePath;
        private readonly string _emergencyLogPath;
        private static bool _consoleAllocated = false;
        
        // Win32 API for console allocation
        [DllImport("kernel32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool AllocConsole();
        
        [DllImport("kernel32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool FreeConsole();
        
        public ObservableCollection<LogEntry> LogEntries { get; private set; }
        
        private LoggingService()
        {
            try
            {
                LogEntries = new ObservableCollection<LogEntry>();
                
                // Create emergency log file first (in temp if AppData fails)
                _emergencyLogPath = Path.Combine(Path.GetTempPath(), $"koala-emergency-{DateTime.Now:yyyy-MM-dd-HHmmss}.txt");
                
                // Try to create proper log directory
                string logDirectory;
                try
                {
                    logDirectory = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "KOALAOptimizer");
                    Directory.CreateDirectory(logDirectory);
                    _logFilePath = Path.Combine(logDirectory, $"koala-log-{DateTime.Now:yyyy-MM-dd}.txt");
                }
                catch
                {
                    // Fallback to temp directory
                    logDirectory = Path.GetTempPath();
                    _logFilePath = Path.Combine(logDirectory, $"koala-log-{DateTime.Now:yyyy-MM-dd-HHmmss}.txt");
                }
                
                // Allocate console for debug builds
                #if DEBUG
                EnsureConsoleAllocated();
                #endif
                
                // Emergency startup log
                EmergencyLog("LoggingService: Initializing...");
                EmergencyLog($"LoggingService: Log file path: {_logFilePath}");
                EmergencyLog($"LoggingService: Emergency log path: {_emergencyLogPath}");
                
                LogInfo("Logging service initialized successfully");
            }
            catch (Exception ex)
            {
                // Last resort - write to emergency log and console
                EmergencyLog($"LoggingService: CRITICAL - Failed to initialize: {ex.Message}");
                EmergencyLog($"LoggingService: Exception details: {ex}");
                throw;
            }
        }
        
        /// <summary>
        /// Log an informational message
        /// </summary>
        public void LogInfo(string message)
        {
            Log(LogLevel.Info, message);
        }
        
        /// <summary>
        /// Log a warning message
        /// </summary>
        public void LogWarning(string message)
        {
            Log(LogLevel.Warning, message);
        }
        
        /// <summary>
        /// Log an error message
        /// </summary>
        public void LogError(string message, Exception exception = null)
        {
            Log(LogLevel.Error, message, exception);
        }
        
        /// <summary>
        /// Log a debug message
        /// </summary>
        public void LogDebug(string message)
        {
            Log(LogLevel.Debug, message);
        }
        
        /// <summary>
        /// Core logging method
        /// </summary>
        private void Log(LogLevel level, string message, Exception exception = null)
        {
            var entry = new LogEntry
            {
                Timestamp = DateTime.Now,
                Level = level,
                Message = message,
                Exception = exception
            };
            
            lock (_lock)
            {
                // Add to in-memory collection (UI thread)
                if (Application.Current?.Dispatcher != null)
                {
                    Application.Current.Dispatcher.BeginInvoke(DispatcherPriority.Background, new Action(() =>
                    {
                        LogEntries.Add(entry);
                        
                        // Keep only last 1000 entries to prevent memory issues
                        while (LogEntries.Count > 1000)
                        {
                            LogEntries.RemoveAt(0);
                        }
                    }));
                }
                
                // Write to file
                WriteToFile(entry);
                
                // Write to console for debugging
                WriteToConsole(entry);
            }
        }
        
        /// <summary>
        /// Write log entry to file
        /// </summary>
        private void WriteToFile(LogEntry entry)
        {
            try
            {
                var logLine = FormatLogEntry(entry);
                File.AppendAllText(_logFilePath, logLine + Environment.NewLine);
            }
            catch
            {
                // Ignore file write errors to prevent logging loops
            }
        }
        
        /// <summary>
        /// Write log entry to console
        /// </summary>
        private void WriteToConsole(LogEntry entry)
        {
            var color = GetConsoleColor(entry.Level);
            var originalColor = Console.ForegroundColor;
            
            try
            {
                Console.ForegroundColor = color;
                Console.WriteLine(FormatLogEntry(entry));
                
                if (entry.Exception != null)
                {
                    Console.WriteLine($"Exception: {entry.Exception}");
                }
            }
            finally
            {
                Console.ForegroundColor = originalColor;
            }
        }
        
        /// <summary>
        /// Format log entry for output
        /// </summary>
        private string FormatLogEntry(LogEntry entry)
        {
            return $"[{entry.Timestamp:HH:mm:ss}] [{entry.Level}] {entry.Message}";
        }
        
        /// <summary>
        /// Get console color for log level
        /// </summary>
        private ConsoleColor GetConsoleColor(LogLevel level)
        {
            switch (level)
            {
                case LogLevel.Info:
                    return ConsoleColor.White;
                case LogLevel.Warning:
                    return ConsoleColor.Yellow;
                case LogLevel.Error:
                    return ConsoleColor.Red;
                case LogLevel.Debug:
                    return ConsoleColor.Gray;
                default:
                    return ConsoleColor.White;
            }
        }
        
        /// <summary>
        /// Clear log entries
        /// </summary>
        public void ClearLogs()
        {
            lock (_lock)
            {
                if (Application.Current?.Dispatcher != null)
                {
                    Application.Current.Dispatcher.Invoke(() => LogEntries.Clear());
                }
            }
        }
        
        /// <summary>
        /// Export logs to file
        /// </summary>
        public void ExportLogs(string filePath)
        {
            try
            {
                using (var writer = new StreamWriter(filePath))
                {
                    writer.WriteLine($"KOALA Gaming Optimizer Log Export - {DateTime.Now}");
                    writer.WriteLine(new string('=', 50));
                    writer.WriteLine();
                    
                    foreach (var entry in LogEntries)
                    {
                        writer.WriteLine(FormatLogEntry(entry));
                        if (entry.Exception != null)
                        {
                            writer.WriteLine($"Exception: {entry.Exception}");
                            writer.WriteLine();
                        }
                    }
                }
                
                LogInfo($"Logs exported to: {filePath}");
            }
            catch (Exception ex)
            {
                LogError($"Failed to export logs: {ex.Message}", ex);
            }
        }
        
        /// <summary>
        /// Emergency logging method that bypasses normal logging infrastructure
        /// Used for critical startup errors when normal logging might fail
        /// </summary>
        public static void EmergencyLog(string message)
        {
            var timestamp = DateTime.Now.ToString("HH:mm:ss.fff");
            var logMessage = $"[{timestamp}] [EMERGENCY] {message}";
            
            try
            {
                // Write to console if available
                Console.WriteLine(logMessage);
            }
            catch { /* Ignore console errors */ }
            
            try
            {
                // Write to emergency file
                var emergencyPath = Path.Combine(Path.GetTempPath(), $"koala-emergency-{DateTime.Now:yyyy-MM-dd}.txt");
                File.AppendAllText(emergencyPath, logMessage + Environment.NewLine);
            }
            catch { /* Ignore file errors */ }
        }
        
        /// <summary>
        /// Ensure console is allocated for debug output
        /// </summary>
        private static void EnsureConsoleAllocated()
        {
            if (!_consoleAllocated)
            {
                try
                {
                    AllocConsole();
                    _consoleAllocated = true;
                    Console.WriteLine("KOALA Gaming Optimizer - Debug Console Allocated");
                    Console.WriteLine($"Startup Time: {DateTime.Now:yyyy-MM-dd HH:mm:ss}");
                    Console.WriteLine("=====================================");
                }
                catch (Exception ex)
                {
                    // If console allocation fails, just continue
                    System.Diagnostics.Debug.WriteLine($"Failed to allocate console: {ex.Message}");
                }
            }
        }
        
        /// <summary>
        /// Log startup milestone with enhanced detail
        /// </summary>
        public void LogStartupMilestone(string milestone, string details = null)
        {
            var message = $"STARTUP MILESTONE: {milestone}";
            if (!string.IsNullOrEmpty(details))
            {
                message += $" - {details}";
            }
            
            LogInfo(message);
            EmergencyLog(message); // Also write to emergency log for critical tracking
        }
    }
}