namespace AllyClicker.App;

/// <summary>
/// Application entry point.
/// </summary>
/// <remarks>
/// Scaffold only (W0). W3 turns this into the real startup path: create the
/// borderless top-most panel, start the dwell loop on its own dedicated thread,
/// and install the tray icon. Deliberately no StartupUri — the app owns a panel,
/// not a main window, and must not steal focus when it appears.
/// </remarks>
public partial class App : System.Windows.Application
{
}
