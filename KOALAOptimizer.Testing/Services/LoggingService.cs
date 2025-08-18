using System;
using System.Collections.ObjectModel;
using System.IO;
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
        
        public ObservableCollection<LogEntry> LogEntries { get; private set; }
        
        private LoggingService()
        {
            LogEntries = new ObservableCollection<LogEntry>();
            
            // Create log file path
            var logDirectory = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "KOALAOptimizer");
            Directory.CreateDirectory(logDirectory);
            _logFilePath = Path.Combine(logDirectory, $"koala-log-{DateTime.Now:yyyy-MM-dd}.txt");
            
            LogInfo("Logging service initialized");
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
    }
}