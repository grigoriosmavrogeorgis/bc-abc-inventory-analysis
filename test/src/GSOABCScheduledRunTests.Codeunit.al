namespace GMSoft.ABCInventoryAnalysis.Tests;

using GMSoft.ABCInventoryAnalysis;
using System.TestLibraries.Utilities;
using System.Threading;
using System.Upgrade;

/// <summary>
/// Tests for the scheduled recalculation: RecalculateAllModels, the job queue codeunit, the job queue helper,
/// the upgrade tag registration and the telemetry procedures.
/// The install and upgrade triggers themselves only run when the app is installed or upgraded and cannot be
/// called from a test; the procedures they call (EnsureSetup, EnsurePolicyExists) are covered in codeunit 50001.
/// </summary>
codeunit 50002 "GSO ABC Scheduled Run Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Mgt: Codeunit "GSO ABC Analysis Mgt.";
        Lib: Codeunit "GSO ABC Test Library";
        LastMessage: Text;
        ModelCheckMsg: Label '%1 for model %2', Comment = '%1 = checked value, %2 = model', Locked = true;

    [Test]
    procedure RecalculateAllModelsAppliesEveryModel()
    var
        HistHdr: Record "GSO ABC History Header";
        Model: Enum "GSO ABC Model";
        Ordinal: Integer;
        ItemNo: array[2] of Code[20];
        LastEntryNo: Integer;
    begin
        // [GIVEN] Two items with value in every model, inside the default window of every model
        Initialize();
        CreateItemsWithValueInEveryModel(ItemNo);
        LastEntryNo := Lib.LastHistoryEntryNo();

        // [WHEN] All models are recalculated with apply
        Mgt.RecalculateAllModels(true);

        // [THEN] Every model has written a class and a timestamp to both items
        foreach Ordinal in Model.Ordinals() do begin
            Model := Enum::"GSO ABC Model".FromInteger(Ordinal);
            Assert.AreNotEqual(Enum::"GSO ABC Class"::Unknown, Lib.GetItemClass(ItemNo[1], Model), StrSubstNo(ModelCheckMsg, 'Class of the first item', Model));
            Assert.AreNotEqual(Enum::"GSO ABC Class"::Unknown, Lib.GetItemClass(ItemNo[2], Model), StrSubstNo(ModelCheckMsg, 'Class of the second item', Model));
            Assert.AreNotEqual(0DT, Lib.GetItemLastCalc(ItemNo[1], Model), StrSubstNo(ModelCheckMsg, 'Timestamp', Model));
        end;

        // [THEN] Revenue 700 and 300 gives A and C
        Assert.AreEqual(Enum::"GSO ABC Class"::A, Lib.GetItemClass(ItemNo[1], Enum::"GSO ABC Model"::Revenue), 'Revenue class of the first item');
        Assert.AreEqual(Enum::"GSO ABC Class"::C, Lib.GetItemClass(ItemNo[2], Enum::"GSO ABC Model"::Revenue), 'Revenue class of the second item');

        // [THEN] One history entry per model, each for the default window of that model
        HistHdr.SetFilter("Entry No.", '>%1', LastEntryNo);
        Assert.RecordCount(HistHdr, Model.Ordinals().Count());
        foreach Ordinal in Model.Ordinals() do begin
            HistHdr.SetRange(Model, Enum::"GSO ABC Model".FromInteger(Ordinal));
            Assert.RecordCount(HistHdr, 1);
            HistHdr.FindFirst();
            Assert.AreEqual(Lib.GetTestDate() - 1, HistHdr."Start Date", 'History start date');
            Assert.AreEqual(Lib.GetTestDate(), HistHdr."End Date", 'History end date');
            Assert.AreEqual(2, HistHdr."Items Count", 'History items count');
        end;

        Lib.RestoreWorkDate();
    end;

    [Test]
    procedure RecalculateAllModelsWithoutApplyChangesNothing()
    var
        ItemNo: array[2] of Code[20];
        LastEntryNo: Integer;
    begin
        // [GIVEN] Two items with value in every model
        Initialize();
        CreateItemsWithValueInEveryModel(ItemNo);
        LastEntryNo := Lib.LastHistoryEntryNo();

        // [WHEN] All models are recalculated without apply
        Mgt.RecalculateAllModels(false);

        // [THEN] No class is written and no history entry is created
        Assert.AreEqual(Enum::"GSO ABC Class"::Unknown, Lib.GetItemClass(ItemNo[1], Enum::"GSO ABC Model"::Revenue), 'Revenue class');
        Assert.AreEqual(Enum::"GSO ABC Class"::Unknown, Lib.GetItemClass(ItemNo[1], Enum::"GSO ABC Model"::"Pick Frequency"), 'Pick Frequency class');
        Assert.AreEqual(LastEntryNo, Lib.LastHistoryEntryNo(), 'No history entry may be created');

        Lib.RestoreWorkDate();
    end;

    [Test]
    procedure RecalculateAllModelsSkipsModelsWithoutValue()
    var
        HistHdr: Record "GSO ABC History Header";
        LastEntryNo: Integer;
    begin
        // [GIVEN] No item has any activity in the default window, and class D is off
        Initialize();
        LastEntryNo := Lib.LastHistoryEntryNo();

        // [WHEN] All models are recalculated with apply
        Mgt.RecalculateAllModels(true);

        // [THEN] Nothing is applied and the run does not stop on the empty previews
        HistHdr.SetFilter("Entry No.", '>%1', LastEntryNo);
        Assert.RecordIsEmpty(HistHdr);

        Lib.RestoreWorkDate();
    end;

    [Test]
    procedure JobRunsWhenEnabled()
    var
        HistHdr: Record "GSO ABC History Header";
        Model: Enum "GSO ABC Model";
        ItemNo: array[2] of Code[20];
        LastEntryNo: Integer;
    begin
        // [GIVEN] The analysis is enabled in setup and two items have value in every model
        Initialize();
        CreateItemsWithValueInEveryModel(ItemNo);
        LastEntryNo := Lib.LastHistoryEntryNo();

        // [WHEN] The job queue codeunit runs
        Codeunit.Run(Codeunit::"GSO ABC Analysis Job");

        // [THEN] All models are applied
        Assert.AreEqual(Enum::"GSO ABC Class"::A, Lib.GetItemClass(ItemNo[1], Enum::"GSO ABC Model"::Revenue), 'Revenue class');
        HistHdr.SetFilter("Entry No.", '>%1', LastEntryNo);
        Assert.RecordCount(HistHdr, Model.Ordinals().Count());

        Lib.RestoreWorkDate();
    end;

    [Test]
    procedure JobIsSkippedWhenDisabled()
    var
        Setup: Record "GSO ABC Analysis Setup";
        ItemNo: array[2] of Code[20];
        LastEntryNo: Integer;
    begin
        // [GIVEN] The analysis is disabled in setup and two items have value in every model
        Initialize();
        CreateItemsWithValueInEveryModel(ItemNo);
        Mgt.EnsureSetup(Setup);
        Setup.Enabled := false;
        Setup.Modify(false);
        LastEntryNo := Lib.LastHistoryEntryNo();

        // [WHEN] The job queue codeunit runs
        Codeunit.Run(Codeunit::"GSO ABC Analysis Job");

        // [THEN] Nothing is calculated or applied
        Assert.AreEqual(Enum::"GSO ABC Class"::Unknown, Lib.GetItemClass(ItemNo[1], Enum::"GSO ABC Model"::Revenue), 'Revenue class');
        Assert.AreEqual(LastEntryNo, Lib.LastHistoryEntryNo(), 'No history entry may be created');

        Lib.RestoreWorkDate();
    end;

    [Test]
    [HandlerFunctions('MessageHandler')]
    procedure JobQueueHelperCreatesADailyEntry()
    var
        JobQueueEntry: Record "Job Queue Entry";
        Helper: Codeunit "GSO ABC Job Queue Helper";
        Subscribers: Codeunit "GSO ABC Test Subscribers";
    begin
        // [GIVEN] No job queue entry for the ABC job
        Initialize();
        DeleteABCJobQueueEntries();
        BindSubscription(Subscribers);

        // [WHEN] The job queue entry is created
        Helper.CreateOrEnableJob();

        // [THEN] One recurring entry runs the ABC job once a day and is ready
        FilterABCJobQueueEntries(JobQueueEntry);
        Assert.RecordCount(JobQueueEntry, 1);
        JobQueueEntry.FindFirst();
        Assert.IsTrue(JobQueueEntry."Recurring Job", 'Recurring job');
        Assert.AreEqual(1440, JobQueueEntry."No. of Minutes between Runs", 'Minutes between runs');
        Assert.AreNotEqual('', JobQueueEntry.Description, 'Description');
        Assert.AreEqual(JobQueueEntry.Status::Ready, JobQueueEntry.Status, 'Status');
        Assert.AreEqual(1, Subscribers.GetTasksScheduled(), 'Tasks scheduled');

        // [THEN] The user is told that an entry was created
        Assert.IsTrue(LastMessage.Contains('created'), 'Message: ' + LastMessage);
    end;

    [Test]
    [HandlerFunctions('MessageHandler')]
    procedure JobQueueHelperReusesAnExistingEntry()
    var
        JobQueueEntry: Record "Job Queue Entry";
        Helper: Codeunit "GSO ABC Job Queue Helper";
        Subscribers: Codeunit "GSO ABC Test Subscribers";
        EntryId: Guid;
    begin
        // [GIVEN] An ABC job queue entry that is on hold, not recurring and has no interval
        Initialize();
        DeleteABCJobQueueEntries();
        JobQueueEntry.Init();
        JobQueueEntry.ID := CreateGuid();
        JobQueueEntry."Object Type to Run" := JobQueueEntry."Object Type to Run"::Codeunit;
        JobQueueEntry."Object ID to Run" := Codeunit::"GSO ABC Analysis Job";
        JobQueueEntry.Status := JobQueueEntry.Status::"On Hold";
        JobQueueEntry.Insert(false);
        EntryId := JobQueueEntry.ID;
        BindSubscription(Subscribers);

        // [WHEN] The job queue entry is created or enabled
        Helper.CreateOrEnableJob();

        // [THEN] The same entry is made recurring, daily and ready; no second entry is created
        FilterABCJobQueueEntries(JobQueueEntry);
        Assert.RecordCount(JobQueueEntry, 1);
        JobQueueEntry.FindFirst();
        Assert.AreEqual(EntryId, JobQueueEntry.ID, 'Entry ID');
        Assert.IsTrue(JobQueueEntry."Recurring Job", 'Recurring job');
        Assert.AreEqual(1440, JobQueueEntry."No. of Minutes between Runs", 'Minutes between runs');
        Assert.AreNotEqual(0DT, JobQueueEntry."Earliest Start Date/Time", 'Earliest start');
        Assert.AreEqual(JobQueueEntry.Status::Ready, JobQueueEntry.Status, 'Status');

        // [THEN] The user is told that the existing entry was scheduled
        Assert.IsTrue(LastMessage.Contains('existing'), 'Message: ' + LastMessage);
    end;

    [Test]
    procedure DefaultPolicyUpgradeTagIsRegistered()
    var
        UpgradeTag: Codeunit "Upgrade Tag";
        PerCompanyUpgradeTags: List of [Code[250]];
    begin
        // [WHEN] The per-company upgrade tags are collected
        UpgradeTag.GetPerCompanyUpgradeTags(PerCompanyUpgradeTags);

        // [THEN] The default counting policy tag is one of them, so new companies skip that upgrade step
        Assert.IsTrue(PerCompanyUpgradeTags.Contains('GSO-ABC-DefaultCountingPolicy-1.29'), 'Default counting policy upgrade tag');
    end;

    [Test]
    procedure TelemetryProceduresRunWithoutError()
    var
        Telemetry: Codeunit "GSO ABC Telemetry";
    begin
        // [WHEN] [THEN] Every telemetry signal can be emitted, for every model
        Telemetry.LogInstalled();
        Telemetry.LogUpgraded(Version.Create(1, 29, 3, 0));
        Telemetry.LogClassesApplied(Enum::"GSO ABC Model"::Revenue, 10, 8, true);
        Telemetry.LogClassesApplied(Enum::"GSO ABC Model"::"Pick Frequency", 0, 0, false);
        Telemetry.LogApplyFailed(Enum::"GSO ABC Model"::GMROII);
        Telemetry.LogScheduledRun(6, true);
        Telemetry.LogScheduledSkipped();
    end;

    // ---- helpers ----

    local procedure Initialize()
    begin
        Lib.Initialize(2097);
        Lib.UseDefaultWindowOnTestDate();
        Clear(LastMessage);
    end;

    /// <summary>
    /// Two units in stock at 100, one sold for 700 and 300. Revenue 700/300, gross profit 600/200,
    /// COGS and usage value 100/100, GMROII 600 %/200 %, pick frequency 1/1.
    /// </summary>
    local procedure CreateItemsWithValueInEveryModel(var ItemNo: array[2] of Code[20])
    begin
        ItemNo[1] := Lib.CreateItemWithStockAndSale(2, 100, 700);
        ItemNo[2] := Lib.CreateItemWithStockAndSale(2, 100, 300);
    end;

    local procedure FilterABCJobQueueEntries(var JobQueueEntry: Record "Job Queue Entry")
    begin
        JobQueueEntry.Reset();
        JobQueueEntry.SetRange("Object Type to Run", JobQueueEntry."Object Type to Run"::Codeunit);
        JobQueueEntry.SetRange("Object ID to Run", Codeunit::"GSO ABC Analysis Job");
    end;

    local procedure DeleteABCJobQueueEntries()
    var
        JobQueueEntry: Record "Job Queue Entry";
    begin
        FilterABCJobQueueEntries(JobQueueEntry);
        JobQueueEntry.DeleteAll(false);
    end;

    [MessageHandler]
    procedure MessageHandler(Message: Text[1024])
    begin
        LastMessage := Message;
    end;
}
