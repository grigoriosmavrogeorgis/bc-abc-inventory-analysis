namespace GMSoft.ABCInventoryAnalysis.Demo;

/// <summary>
/// Schedules the demo data for every company when the demo app is installed. The work runs as a
/// background task after the install has committed, so a failure in one company (for example a
/// company without items) cannot stop the installation. Codeunit.Run is not allowed here because
/// the install trigger already holds a write transaction.
/// </summary>
codeunit 60001 "GSO ABC Demo Install"
{
    Subtype = Install;
    Access = Internal;

    trigger OnInstallAppPerCompany()
    begin
        TaskScheduler.CreateTask(Codeunit::"GSO ABC Demo Data", 0, true, CompanyName(), CurrentDateTime());
    end;
}
