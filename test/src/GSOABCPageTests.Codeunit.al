namespace GMSoft.ABCInventoryAnalysis.Tests;

using GMSoft.ABCInventoryAnalysis;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Location;
using System.TestLibraries.Utilities;
using System.Threading;

/// <summary>
/// Tests for the pages: the worksheet with its parameter dialog, statistics and Excel export, the setup page,
/// the history pages, the counting policy pages and the ABC fields on the item and stockkeeping unit pages.
/// </summary>
codeunit 50004 "GSO ABC Page Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Mgt: Codeunit "GSO ABC Analysis Mgt.";
        Lib: Codeunit "GSO ABC Test Library";
        ParamModel: Enum "GSO ABC Model";
        ParamStartDate: Date;
        ParamEndDate: Date;
        ParamBlankDates: Boolean;
        ParamCancel: Boolean;
        SeenStartDateOnOpen: Date;
        SeenStartDateAfterModel: Date;
        ConfirmReply: Boolean;
        LastMessage: Text;
        ExpectedHistoryEntryNo: Integer;
        NoPreviewLinesErr: Label 'There are no preview lines. Choose Calculate first.';
        DateOrderErr: Label 'Start Date must not be after End Date.';
        SelectPolicyErr: Label 'Select a Counting Policy Code first.';
        NoHistoryLinesErr: Label 'There are no lines to export.';

    // ---- worksheet ----

    [Test]
    [HandlerFunctions('ParamsHandler,MessageHandler')]
    procedure WorksheetCalculateShowsPreviewAndStatistics()
    var
        Worksheet: TestPage "GSO ABC Worksheet";
        ItemNo: array[2] of Code[20];
    begin
        // [GIVEN] Two items with revenue 700 and 300
        Initialize();
        CreateRevenueItems(ItemNo);

        // [WHEN] Calculate is chosen for Revenue on the test date
        Worksheet.OpenView();
        Worksheet.Calc.Invoke();

        // [THEN] The user is told how many lines were calculated
        Assert.IsTrue(LastMessage.Contains('2'), 'Message: ' + LastMessage);

        // [THEN] The lines are listed by value with their class, and the parameters are shown
        Assert.IsTrue(Worksheet.First(), 'First preview line');
        Assert.AreEqual(ItemNo[1], Worksheet."Item No.".Value(), 'First item');
        Assert.AreEqual(700, Worksheet.Value.AsDecimal(), 'First value');
        Assert.IsTrue(Worksheet.ClassDisplay.Value().EndsWith('A'), 'First class');
        Assert.IsTrue(Worksheet.Next(), 'Second preview line');
        Assert.AreEqual(ItemNo[2], Worksheet."Item No.".Value(), 'Second item');
        Assert.IsTrue(Worksheet.ClassDisplay.Value().EndsWith('C'), 'Second class');
        Assert.IsFalse(Worksheet.Next(), 'Only two preview lines');
        Assert.AreEqual(Lib.GetTestDate(), Worksheet.LastStartDateField.AsDate(), 'Start date of the preview');
        Assert.AreEqual(Lib.GetTestDate(), Worksheet.LastEndDateField.AsDate(), 'End date of the preview');

        // [THEN] The statistics factbox has one line per class, starting with A
        Assert.IsTrue(Worksheet.StatsPart.First(), 'First statistics line');
        Assert.AreEqual(1, Worksheet.StatsPart."Item Count".AsInteger(), 'Class A item count');
        Assert.AreEqual(700, Worksheet.StatsPart.Amount.AsDecimal(), 'Class A amount');
        Assert.AreEqual(70, Worksheet.StatsPart."Amount %".AsDecimal(), 'Class A amount %');
        Worksheet.Close();
    end;

    [Test]
    [HandlerFunctions('ParamsHandler,MessageHandler,ConfirmHandler')]
    procedure WorksheetApplyWritesClassesAfterConfirmation()
    var
        Worksheet: TestPage "GSO ABC Worksheet";
        ItemNo: array[2] of Code[20];
        LastEntryNo: Integer;
    begin
        // [GIVEN] A calculated Revenue preview with two items
        Initialize();
        CreateRevenueItems(ItemNo);
        LastEntryNo := Lib.LastHistoryEntryNo();
        Worksheet.OpenView();
        Worksheet.Calc.Invoke();

        // [WHEN] Apply is chosen and confirmed
        ConfirmReply := true;
        Worksheet.Apply.Invoke();

        // [THEN] The classes are on the items, a history entry exists and the user is told how many items were updated
        Assert.AreEqual(Enum::"GSO ABC Class"::A, Lib.GetItemClass(ItemNo[1], Enum::"GSO ABC Model"::Revenue), 'First item class');
        Assert.AreEqual(Enum::"GSO ABC Class"::C, Lib.GetItemClass(ItemNo[2], Enum::"GSO ABC Model"::Revenue), 'Second item class');
        Assert.AreNotEqual(LastEntryNo, Lib.LastHistoryEntryNo(), 'History entry');
        Assert.IsTrue(LastMessage.Contains('2'), 'Message: ' + LastMessage);
        Worksheet.Close();
    end;

    [Test]
    [HandlerFunctions('ParamsHandler,MessageHandler,ConfirmHandler')]
    procedure WorksheetApplyDoesNothingWhenNotConfirmed()
    var
        Worksheet: TestPage "GSO ABC Worksheet";
        ItemNo: array[2] of Code[20];
        LastEntryNo: Integer;
    begin
        // [GIVEN] A calculated Revenue preview with two items
        Initialize();
        CreateRevenueItems(ItemNo);
        LastEntryNo := Lib.LastHistoryEntryNo();
        Worksheet.OpenView();
        Worksheet.Calc.Invoke();

        // [WHEN] Apply is chosen and the confirmation is answered with No
        ConfirmReply := false;
        Worksheet.Apply.Invoke();

        // [THEN] Nothing is written
        Assert.AreEqual(Enum::"GSO ABC Class"::Unknown, Lib.GetItemClass(ItemNo[1], Enum::"GSO ABC Model"::Revenue), 'Item class');
        Assert.AreEqual(LastEntryNo, Lib.LastHistoryEntryNo(), 'No history entry may be created');
        Worksheet.Close();
    end;

    [Test]
    procedure WorksheetApplyNeedsAPreview()
    var
        Worksheet: TestPage "GSO ABC Worksheet";
    begin
        // [GIVEN] A worksheet without a preview
        Initialize();
        Worksheet.OpenView();

        // [WHEN] Apply is chosen
        asserterror Worksheet.Apply.Invoke();

        // [THEN] The user is asked to calculate first
        Assert.ExpectedError(NoPreviewLinesErr);
    end;

    [Test]
    procedure WorksheetExportNeedsAPreview()
    var
        Worksheet: TestPage "GSO ABC Worksheet";
    begin
        // [GIVEN] A worksheet without a preview
        Initialize();
        Worksheet.OpenView();

        // [WHEN] Export to Excel is chosen
        asserterror Worksheet.ExportExcel.Invoke();

        // [THEN] The user is asked to calculate first
        Assert.ExpectedError(NoPreviewLinesErr);
    end;

    [Test]
    [HandlerFunctions('ParamsHandler,MessageHandler')]
    procedure WorksheetExportCreatesAWorkbook()
    var
        Subscribers: Codeunit "GSO ABC Test Subscribers";
        Worksheet: TestPage "GSO ABC Worksheet";
        ItemNo: array[2] of Code[20];
    begin
        // [GIVEN] A calculated Revenue preview with two items
        Initialize();
        CreateRevenueItems(ItemNo);
        Worksheet.OpenView();
        Worksheet.Calc.Invoke();
        BindSubscription(Subscribers);

        // [WHEN] Export to Excel is chosen
        Worksheet.ExportExcel.Invoke();

        // [THEN] One workbook with the preview and statistics sheets is written and handed to the user
        Assert.AreEqual(1, Subscribers.GetWorkbooksOpened(), 'Workbooks opened');
        Worksheet.Close();
    end;

    // ---- parameter dialog ----

    [Test]
    [HandlerFunctions('ParamsHandler')]
    procedure CancellingTheParametersCalculatesNothing()
    var
        Worksheet: TestPage "GSO ABC Worksheet";
        ItemNo: array[2] of Code[20];
    begin
        // [GIVEN] Two items with revenue
        Initialize();
        CreateRevenueItems(ItemNo);

        // [WHEN] Calculate is chosen and the parameter dialog is cancelled
        ParamCancel := true;
        Worksheet.OpenView();
        Worksheet.Calc.Invoke();

        // [THEN] The worksheet stays empty
        Assert.IsFalse(Worksheet.First(), 'The worksheet must stay empty');
        Worksheet.Close();
    end;

    [Test]
    [HandlerFunctions('ParamsHandler')]
    procedure ParametersDefaultToThePeriodOfTheModel()
    var
        Worksheet: TestPage "GSO ABC Worksheet";
    begin
        // [GIVEN] A Revenue period of 30 days and a Gross Profit period of 60 days
        Initialize();
        Lib.SetPeriod(Enum::"GSO ABC Model"::Revenue, 30);
        Lib.SetPeriod(Enum::"GSO ABC Model"::"Gross Profit", 60);

        // [WHEN] The parameter dialog opens and the model is changed to Gross Profit
        ParamModel := Enum::"GSO ABC Model"::"Gross Profit";
        ParamCancel := true;
        Worksheet.OpenView();
        Worksheet.Calc.Invoke();

        // [THEN] The dialog opens with the Revenue period and switches to the Gross Profit period
        Assert.AreEqual(WorkDate() - 30, SeenStartDateOnOpen, 'Start date when the dialog opens');
        Assert.AreEqual(WorkDate() - 60, SeenStartDateAfterModel, 'Start date after choosing Gross Profit');
        Worksheet.Close();
    end;

    [Test]
    [HandlerFunctions('ParamsHandler,MessageHandler')]
    procedure BlankParameterDatesFallBackToTheDefaults()
    var
        Worksheet: TestPage "GSO ABC Worksheet";
        ItemNo: array[2] of Code[20];
    begin
        // [GIVEN] Two items with revenue inside the default Revenue window
        Initialize();
        CreateRevenueItems(ItemNo);
        Lib.UseDefaultWindowOnTestDate();

        // [WHEN] Calculate is chosen and both dates are cleared in the dialog
        ParamBlankDates := true;
        Worksheet.OpenView();
        Worksheet.Calc.Invoke();

        // [THEN] The preview is calculated for the default window
        Assert.AreEqual(Lib.GetTestDate() - 1, Worksheet.LastStartDateField.AsDate(), 'Start date of the preview');
        Assert.AreEqual(Lib.GetTestDate(), Worksheet.LastEndDateField.AsDate(), 'End date of the preview');
        Assert.IsTrue(Worksheet.First(), 'Preview lines');
        Worksheet.Close();
        Lib.RestoreWorkDate();
    end;

    [Test]
    [HandlerFunctions('ParamsHandler')]
    procedure StartDateAfterEndDateIsRejected()
    var
        Worksheet: TestPage "GSO ABC Worksheet";
    begin
        // [GIVEN] A start date one day after the end date
        Initialize();
        ParamStartDate := Lib.GetTestDate() + 1;
        ParamEndDate := Lib.GetTestDate();

        // [WHEN] The parameter dialog is closed with OK
        Worksheet.OpenView();
        asserterror Worksheet.Calc.Invoke();

        // [THEN] The dates are rejected
        Assert.ExpectedError(DateOrderErr);
    end;

    // ---- setup ----

    [Test]
    procedure SetupPageCreatesSetupAndDefaultPolicy()
    var
        Setup: Record "GSO ABC Analysis Setup";
        PolicyHeader: Record "GSO ABC Counting Policy Header";
        PolicyLine: Record "GSO ABC Counting Policy Line";
        SetupPage: TestPage "GSO ABC Analysis Setup";
    begin
        // [GIVEN] No setup record and no DEFAULT counting policy
        Initialize();
        Setup.DeleteAll(false);
        PolicyLine.SetRange("Header Code", 'DEFAULT');
        PolicyLine.DeleteAll(false);
        if PolicyHeader.Get('DEFAULT') then
            PolicyHeader.Delete(false);

        // [WHEN] The setup page is opened
        SetupPage.OpenEdit();

        // [THEN] The page shows the defaults
        Assert.AreEqual(80, SetupPage."Rev A %".AsDecimal(), 'Revenue A %');
        Assert.AreEqual('DEFAULT', SetupPage."Counting Code Mapping ID".Value(), 'Counting policy code');
        SetupPage.Close();

        // [THEN] The setup record and the DEFAULT policy with a line per model and class exist
        Assert.RecordCount(Setup, 1);
        Assert.IsTrue(PolicyHeader.Get('DEFAULT'), 'Default policy header');
        Assert.RecordCount(PolicyLine, 24);
    end;

    [Test]
    [HandlerFunctions('MessageHandler')]
    procedure SetupPageResetsThresholdsToDefaults()
    var
        Setup: Record "GSO ABC Analysis Setup";
        SetupPage: TestPage "GSO ABC Analysis Setup";
    begin
        // [GIVEN] Thresholds 10/20 and a period of 7 days for every model
        Initialize();
        Lib.SetAllThresholds(10, 20);
        Lib.SetAllPeriods(7);

        // [WHEN] "Reset Thresholds to Defaults" is chosen
        SetupPage.OpenEdit();
        SetupPage.FillDefaultThresholds.Invoke();
        SetupPage.Close();

        // [THEN] Every model is back at A 80 %, B 95 % and 365 days
        Mgt.EnsureSetup(Setup);
        Assert.AreEqual(80, Setup."Rev A %", 'Revenue A %');
        Assert.AreEqual(95, Setup."Rev B %", 'Revenue B %');
        Assert.AreEqual(365, Setup."Rev Period (Days)", 'Revenue period');
        Assert.AreEqual(80, Setup."GP A %", 'Gross Profit A %');
        Assert.AreEqual(95, Setup."GP B %", 'Gross Profit B %');
        Assert.AreEqual(365, Setup."GP Period (Days)", 'Gross Profit period');
        Assert.AreEqual(80, Setup."COGS A %", 'COGS A %');
        Assert.AreEqual(95, Setup."COGS B %", 'COGS B %');
        Assert.AreEqual(365, Setup."COGS Period (Days)", 'COGS period');
        Assert.AreEqual(80, Setup."Usage Value A %", 'Usage Value A %');
        Assert.AreEqual(95, Setup."Usage Value B %", 'Usage Value B %');
        Assert.AreEqual(365, Setup."Usage Value Period (Days)", 'Usage Value period');
        Assert.AreEqual(80, Setup."GMROII A %", 'GMROII A %');
        Assert.AreEqual(95, Setup."GMROII B %", 'GMROII B %');
        Assert.AreEqual(365, Setup."GMROII Period (Days)", 'GMROII period');
        Assert.AreEqual(80, Setup."Pick Freq A %", 'Pick Frequency A %');
        Assert.AreEqual(95, Setup."Pick Freq B %", 'Pick Frequency B %');
        Assert.AreEqual(365, Setup."Pick Freq Period (Days)", 'Pick Frequency period');
        Assert.AreNotEqual('', LastMessage, 'Confirmation message');
    end;

    [Test]
    procedure SetupPageCreatesThePolicyThatIsEntered()
    var
        PolicyHeader: Record "GSO ABC Counting Policy Header";
        PolicyLine: Record "GSO ABC Counting Policy Line";
        SetupPage: TestPage "GSO ABC Analysis Setup";
    begin
        // [GIVEN] No policy with code ABCTPAGE
        Initialize();

        // [WHEN] The code is entered as Counting Policy Code
        SetupPage.OpenEdit();
        SetupPage."Counting Code Mapping ID".SetValue('ABCTPAGE');
        SetupPage.Close();

        // [THEN] The policy exists with a line per model and class
        Assert.IsTrue(PolicyHeader.Get('ABCTPAGE'), 'Policy header');
        PolicyLine.SetRange("Header Code", 'ABCTPAGE');
        Assert.RecordCount(PolicyLine, 24);
    end;

    [Test]
    procedure SetupPageNeedsAPolicyCodeToOpenThePolicy()
    var
        SetupPage: TestPage "GSO ABC Analysis Setup";
    begin
        // [GIVEN] A blank Counting Policy Code
        Initialize();
        SetupPage.OpenEdit();
        SetupPage."Counting Code Mapping ID".SetValue('');

        // [WHEN] Counting Policy is chosen
        asserterror SetupPage.OpenCountingPolicy.Invoke();

        // [THEN] The user is asked to select a code first
        Assert.ExpectedError(SelectPolicyErr);
    end;

    [Test]
    [HandlerFunctions('MessageHandler')]
    procedure SetupPageCreatesTheJobQueueEntry()
    var
        JobQueueEntry: Record "Job Queue Entry";
        Subscribers: Codeunit "GSO ABC Test Subscribers";
        SetupPage: TestPage "GSO ABC Analysis Setup";
    begin
        // [GIVEN] No job queue entry for the ABC job
        Initialize();
        JobQueueEntry.SetRange("Object Type to Run", JobQueueEntry."Object Type to Run"::Codeunit);
        JobQueueEntry.SetRange("Object ID to Run", Codeunit::"GSO ABC Analysis Job");
        JobQueueEntry.DeleteAll(false);
        BindSubscription(Subscribers);

        // [WHEN] "Create/Enable Job Queue" is chosen
        SetupPage.OpenEdit();
        SetupPage.CreateJobQueue.Invoke();
        SetupPage.Close();

        // [THEN] The entry exists
        Assert.RecordCount(JobQueueEntry, 1);
    end;

    // ---- history ----

    [Test]
    procedure HistoryCardShowsTheSharePerClass()
    var
        HistHdr: Record "GSO ABC History Header";
        HistoryCard: TestPage "GSO ABC History Card";
    begin
        // [GIVEN] A Revenue run with 700 in class A, 200 in class B and 60 + 40 in class C
        Initialize();
        Lib.CreateItemWithSale(700, 0);
        Lib.CreateItemWithSale(200, 0);
        Lib.CreateItemWithSale(60, 0);
        Lib.CreateItemWithSale(40, 0);
        Lib.CalculateAndApply(Enum::"GSO ABC Model"::Revenue);
        HistHdr.Get(Lib.LastHistoryEntryNo());

        // [WHEN] The history card is opened
        HistoryCard.OpenView();
        HistoryCard.GoToRecord(HistHdr);

        // [THEN] The header and the amounts, counts and shares per class are shown
        Assert.AreEqual(4, HistoryCard."Items Count".AsInteger(), 'Items count');
        Assert.AreEqual(1000, HistoryCard."Total Amount".AsDecimal(), 'Total amount');
        Assert.AreEqual(700, HistoryCard.AmtA.AsDecimal(), 'Class A amount');
        Assert.AreEqual(200, HistoryCard.AmtB.AsDecimal(), 'Class B amount');
        Assert.AreEqual(100, HistoryCard.AmtC.AsDecimal(), 'Class C amount');
        Assert.AreEqual(1, HistoryCard.CntA.AsInteger(), 'Class A count');
        Assert.AreEqual(2, HistoryCard.CntC.AsInteger(), 'Class C count');
        Assert.AreEqual(70, HistoryCard.ShareA.AsDecimal(), 'Class A share');
        Assert.AreEqual(20, HistoryCard.ShareB.AsDecimal(), 'Class B share');
        Assert.AreEqual(10, HistoryCard.ShareC.AsDecimal(), 'Class C share');

        // [THEN] The lines of the run are listed
        Assert.IsTrue(HistoryCard.Lines.First(), 'History lines');
        HistoryCard.Close();
    end;

    [Test]
    [HandlerFunctions('HistoryCardHandler')]
    procedure HistoryListOpensTheCardOfTheEntry()
    var
        HistHdr: Record "GSO ABC History Header";
        History: TestPage "GSO ABC History";
    begin
        // [GIVEN] A history entry
        Initialize();
        Lib.CreateItemWithSale(500, 0);
        Lib.CalculateAndApply(Enum::"GSO ABC Model"::Revenue);
        HistHdr.Get(Lib.LastHistoryEntryNo());
        ExpectedHistoryEntryNo := HistHdr."Entry No.";

        // [WHEN] Open is chosen on the entry in the history list
        History.OpenView();
        History.GoToRecord(HistHdr);
        Assert.AreEqual(500, History."Total Amount".AsDecimal(), 'Total amount in the list');
        History.OpenCard.Invoke();

        // [THEN] The card of that entry opens (checked in HistoryCardHandler)
        History.Close();
    end;

    [Test]
    procedure HistoryCardExportCreatesAWorkbook()
    var
        HistHdr: Record "GSO ABC History Header";
        Subscribers: Codeunit "GSO ABC Test Subscribers";
        HistoryCard: TestPage "GSO ABC History Card";
    begin
        // [GIVEN] A history entry with lines
        Initialize();
        Lib.CreateItemWithSale(700, 0);
        Lib.CreateItemWithSale(300, 0);
        Lib.CalculateAndApply(Enum::"GSO ABC Model"::Revenue);
        HistHdr.Get(Lib.LastHistoryEntryNo());
        HistoryCard.OpenView();
        HistoryCard.GoToRecord(HistHdr);
        BindSubscription(Subscribers);

        // [WHEN] "Export Lines to Excel" is chosen
        HistoryCard.ExportToExcel.Invoke();

        // [THEN] One workbook is written and handed to the user
        Assert.AreEqual(1, Subscribers.GetWorkbooksOpened(), 'Workbooks opened');
        HistoryCard.Close();
    end;

    [Test]
    procedure HistoryCardExportNeedsLines()
    var
        HistHdr: Record "GSO ABC History Header";
        HistoryCard: TestPage "GSO ABC History Card";
    begin
        // [GIVEN] A history entry without lines
        Initialize();
        HistHdr.Init();
        HistHdr.Model := Enum::"GSO ABC Model"::Revenue;
        HistHdr.Insert(true);
        HistoryCard.OpenView();
        HistoryCard.GoToRecord(HistHdr);

        // [WHEN] "Export Lines to Excel" is chosen
        asserterror HistoryCard.ExportToExcel.Invoke();

        // [THEN] The export stops because there is nothing to export
        Assert.ExpectedError(NoHistoryLinesErr);
    end;

    // ---- counting policy ----

    [Test]
    procedure CountingPolicyCardEditsTheCountingPeriodOfALine()
    var
        PolicyHeader: Record "GSO ABC Counting Policy Header";
        PolicyLine: Record "GSO ABC Counting Policy Line";
        PolicyCard: TestPage "GSO ABC Counting Policy Card";
        PolicyList: TestPage "GSO ABC Counting Policy List";
        PeriodCode: Code[10];
    begin
        // [GIVEN] A counting policy and a counting period
        Initialize();
        PeriodCode := Lib.CreateCountingPeriod('ABCT-P');
        Mgt.EnsurePolicyExists('ABCTCARD');
        PolicyHeader.Get('ABCTCARD');

        // [WHEN] The counting period is entered on the first line of the policy card
        PolicyCard.OpenEdit();
        PolicyCard.GoToRecord(PolicyHeader);
        Assert.IsTrue(PolicyCard.Lines.First(), 'Policy lines');
        PolicyCard.Lines."Counting Period Code".SetValue(PeriodCode);
        PolicyCard.Close();

        // [THEN] Exactly one line of the policy has the counting period
        PolicyLine.SetRange("Header Code", 'ABCTCARD');
        PolicyLine.SetRange("Counting Period Code", PeriodCode);
        Assert.RecordCount(PolicyLine, 1);

        // [THEN] The policy is in the policy list
        PolicyList.OpenView();
        PolicyList.GoToRecord(PolicyHeader);
        Assert.AreEqual('ABCTCARD', PolicyList.Code.Value(), 'Policy code in the list');
        PolicyList.Close();
    end;

    // ---- item and stockkeeping unit pages ----

    [Test]
    procedure ItemPagesShowTheClassAndTakeTheControlFields()
    var
        Item: Record Item;
        ItemCard: TestPage "Item Card";
        ItemList: TestPage "Item List";
        ItemNo: array[2] of Code[20];
    begin
        // [GIVEN] An item applied as Revenue class A
        Initialize();
        CreateRevenueItems(ItemNo);
        Lib.CalculateAndApply(Enum::"GSO ABC Model"::Revenue);
        Item.Get(ItemNo[1]);

        // [WHEN] The item list and the item card are opened
        ItemList.OpenView();
        ItemList.GoToRecord(Item);
        Assert.AreEqual('A', ItemList."GSO Class (Revenue)".Value(), 'Class in the item list');
        ItemList.Close();

        ItemCard.OpenEdit();
        ItemCard.GoToRecord(Item);

        // [THEN] The card shows the class and the calculation time, and both cannot be edited
        Assert.AreEqual('A', ItemCard."GSO Class (Revenue)".Value(), 'Class on the item card');
        Assert.AreNotEqual('', ItemCard."GSO Last Calc (Revenue)".Value(), 'Calculation time on the item card');
        Assert.IsFalse(ItemCard."GSO Class (Revenue)".Editable(), 'The class must not be editable');

        // [WHEN] "Manual Override" and "Exclude" are switched on
        ItemCard."GSO Manual Override".SetValue(true);
        ItemCard."GSO Exclude".SetValue(true);
        ItemCard.Close();

        // [THEN] Both are saved on the item
        Item.Get(ItemNo[1]);
        Assert.IsTrue(Item."GSO Manual Override", 'Manual override');
        Assert.IsTrue(Item."GSO Exclude", 'Exclude');
    end;

    [Test]
    procedure SKUCardShowsTheClass()
    var
        SKU: Record "Stockkeeping Unit";
        SKUCard: TestPage "Stockkeeping Unit Card";
        ItemNo: array[2] of Code[20];
    begin
        // [GIVEN] An item with a stockkeeping unit, applied as Revenue class A
        Initialize();
        CreateRevenueItems(ItemNo);
        Lib.CreateSKU(ItemNo[1]);
        Lib.CalculateAndApply(Enum::"GSO ABC Model"::Revenue);
        SKU.SetRange("Item No.", ItemNo[1]);
        SKU.FindFirst();

        // [WHEN] The stockkeeping unit card is opened
        SKUCard.OpenView();
        SKUCard.GoToRecord(SKU);

        // [THEN] It shows the class
        Assert.AreEqual('A', SKUCard."GSO Class (Revenue)".Value(), 'Class on the SKU card');
        SKUCard.Close();
    end;

    // ---- helpers ----

    local procedure Initialize()
    begin
        Lib.Initialize(2095);
        ParamModel := Enum::"GSO ABC Model"::Revenue;
        ParamStartDate := Lib.GetTestDate();
        ParamEndDate := Lib.GetTestDate();
        ParamBlankDates := false;
        ParamCancel := false;
        SeenStartDateOnOpen := 0D;
        SeenStartDateAfterModel := 0D;
        ConfirmReply := false;
        ExpectedHistoryEntryNo := 0;
        Clear(LastMessage);
    end;

    local procedure CreateRevenueItems(var ItemNo: array[2] of Code[20])
    begin
        ItemNo[1] := Lib.CreateItemWithSale(700, 0);
        ItemNo[2] := Lib.CreateItemWithSale(300, 0);
    end;

    // ---- handlers ----

    [ModalPageHandler]
    procedure ParamsHandler(var Params: TestPage "GSO ABC Worksheet Params")
    begin
        SeenStartDateOnOpen := Params.StartDate.AsDate();
        Params.Model.SetValue(ParamModel);
        SeenStartDateAfterModel := Params.StartDate.AsDate();

        if ParamCancel then begin
            Params.Cancel().Invoke();
            exit;
        end;

        if ParamBlankDates then begin
            Params.StartDate.SetValue('');
            Params.EndDate.SetValue('');
        end else begin
            Params.StartDate.SetValue(ParamStartDate);
            Params.EndDate.SetValue(ParamEndDate);
        end;
        Params.OK().Invoke();
    end;

    [PageHandler]
    procedure HistoryCardHandler(var HistoryCard: TestPage "GSO ABC History Card")
    begin
        Assert.AreEqual(ExpectedHistoryEntryNo, HistoryCard."Entry No.".AsInteger(), 'Entry opened from the history list');
        HistoryCard.Close();
    end;

    [MessageHandler]
    procedure MessageHandler(Message: Text[1024])
    begin
        LastMessage := Message;
    end;

    [ConfirmHandler]
    procedure ConfirmHandler(Question: Text[1024]; var Reply: Boolean)
    begin
        Reply := ConfirmReply;
    end;
}
