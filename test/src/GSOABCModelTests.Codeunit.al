namespace GMSoft.ABCInventoryAnalysis.Tests;

using GMSoft.ABCInventoryAnalysis;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Location;
using System.TestLibraries.Utilities;

/// <summary>
/// Tests for the parts of the calculation engine that codeunit 50000 does not reach: the Usage Value and
/// GMROII models, the thresholds and periods of every model, the item filters, setup defaults,
/// apply for every model and history deletion.
/// </summary>
codeunit 50001 "GSO ABC Model Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Mgt: Codeunit "GSO ABC Analysis Mgt.";
        Lib: Codeunit "GSO ABC Test Library";
        LibraryInventory: Codeunit "Library - Inventory";
        ModelCheckMsg: Label '%1 for model %2', Comment = '%1 = checked value, %2 = model', Locked = true;

    // ---- values ----

    [Test]
    procedure UsageValueSumsOutboundCost()
    var
        ItemNo: Code[20];
    begin
        // [GIVEN] Three units in stock at 100 each; one is sold and one is written off
        Initialize();
        ItemNo := Lib.CreateItem(100);
        Lib.PostEntry(ItemNo, Enum::"Item Ledger Entry Type"::"Positive Adjmt.", 3, 100);
        Lib.PostEntry(ItemNo, Enum::"Item Ledger Entry Type"::Sale, 1, 900);
        Lib.PostEntry(ItemNo, Enum::"Item Ledger Entry Type"::"Negative Adjmt.", 1, 0);

        // [WHEN] [THEN] The Usage Value is the cost of the two units that left stock
        Assert.AreEqual(200, Mgt.CalcItemValue(Enum::"GSO ABC Model"::"Usage Value", Lib.GetTestDate(), Lib.GetTestDate(), ItemNo), 'Usage value');
    end;

    [Test]
    procedure GMROIIIsMarginOverInventoryValue()
    var
        ItemNo: Code[20];
    begin
        // [GIVEN] Three units in stock at 100 each; one is sold for 300, so margin 200 and inventory value 200
        Initialize();
        ItemNo := Lib.CreateItemWithStockAndSale(3, 100, 300);

        // [WHEN] [THEN] GMROII is margin divided by inventory value, as a percentage
        Assert.AreEqual(100, Mgt.CalcItemValue(Enum::"GSO ABC Model"::GMROII, Lib.GetTestDate(), Lib.GetTestDate(), ItemNo), 'GMROII');
    end;

    [Test]
    procedure GMROIIIsZeroWithoutInventory()
    var
        ItemNo: Code[20];
    begin
        // [GIVEN] An item that was sold out, so there is no inventory value to divide by
        Initialize();
        ItemNo := Lib.CreateItemWithSale(300, 100);

        // [WHEN] [THEN] GMROII is 0
        Assert.AreEqual(0, Mgt.CalcItemValue(Enum::"GSO ABC Model"::GMROII, Lib.GetTestDate(), Lib.GetTestDate(), ItemNo), 'GMROII without inventory');
    end;

    [Test]
    procedure GMROIIIsZeroForUnknownItem()
    begin
        // [GIVEN] An item number that does not exist
        Initialize();

        // [WHEN] [THEN] GMROII is 0 and nothing fails
        Assert.AreEqual(0, Mgt.CalcItemValue(Enum::"GSO ABC Model"::GMROII, Lib.GetTestDate(), Lib.GetTestDate(), 'ABCT-NOITEM'), 'GMROII for unknown item');
    end;

    [Test]
    procedure ValueOutsideThePeriodIsIgnored()
    var
        ItemNo: Code[20];
    begin
        // [GIVEN] An item sold for 500 on the test date
        Initialize();
        ItemNo := Lib.CreateItemWithSale(500, 0);

        // [WHEN] [THEN] The day before has no revenue; an open start or end date includes the sale
        Assert.AreEqual(0, Mgt.CalcItemValue(Enum::"GSO ABC Model"::Revenue, Lib.GetTestDate() - 1, Lib.GetTestDate() - 1, ItemNo), 'Revenue the day before');
        Assert.AreEqual(500, Mgt.CalcItemValue(Enum::"GSO ABC Model"::Revenue, Lib.GetTestDate(), 0D, ItemNo), 'Revenue with open end date');
        Assert.AreEqual(500, Mgt.CalcItemValue(Enum::"GSO ABC Model"::Revenue, 0D, Lib.GetTestDate(), ItemNo), 'Revenue with open start date');
        Assert.AreEqual(0, Mgt.CalcItemValue(Enum::"GSO ABC Model"::Revenue, 0D, Lib.GetTestDate() - 1, ItemNo), 'Revenue up to the day before');
    end;

    // ---- thresholds per model ----

    [Test]
    procedure GrossProfitUsesItsOwnThresholds()
    var
        ItemNo: array[3] of Code[20];
    begin
        // [GIVEN] Three items with gross profit 600, 300 and 100
        Initialize();
        ItemNo[1] := Lib.CreateItemWithSale(700, 100);
        ItemNo[2] := Lib.CreateItemWithSale(400, 100);
        ItemNo[3] := Lib.CreateItemWithSale(200, 100);

        // [WHEN] [THEN] The classes follow the Gross Profit thresholds
        VerifyModelUsesItsOwnThresholds(Enum::"GSO ABC Model"::"Gross Profit", ItemNo);
    end;

    [Test]
    procedure COGSUsesItsOwnThresholds()
    var
        ItemNo: array[3] of Code[20];
    begin
        // [GIVEN] Three items with cost of goods sold 600, 300 and 100
        Initialize();
        ItemNo[1] := Lib.CreateItemWithSale(0, 600);
        ItemNo[2] := Lib.CreateItemWithSale(0, 300);
        ItemNo[3] := Lib.CreateItemWithSale(0, 100);

        // [WHEN] [THEN] The classes follow the COGS thresholds
        VerifyModelUsesItsOwnThresholds(Enum::"GSO ABC Model"::COGS, ItemNo);
    end;

    [Test]
    procedure UsageValueUsesItsOwnThresholds()
    var
        ItemNo: array[3] of Code[20];
    begin
        // [GIVEN] Three items with usage value 600, 300 and 100
        Initialize();
        ItemNo[1] := Lib.CreateItemWithSale(0, 600);
        ItemNo[2] := Lib.CreateItemWithSale(0, 300);
        ItemNo[3] := Lib.CreateItemWithSale(0, 100);

        // [WHEN] [THEN] The classes follow the Usage Value thresholds
        VerifyModelUsesItsOwnThresholds(Enum::"GSO ABC Model"::"Usage Value", ItemNo);
    end;

    [Test]
    procedure GMROIIUsesItsOwnThresholds()
    var
        ItemNo: array[3] of Code[20];
    begin
        // [GIVEN] Three items with one unit left at cost 100 and margin 600, 300 and 100, so GMROII 600 %, 300 % and 100 %
        Initialize();
        ItemNo[1] := Lib.CreateItemWithStockAndSale(2, 100, 700);
        ItemNo[2] := Lib.CreateItemWithStockAndSale(2, 100, 400);
        ItemNo[3] := Lib.CreateItemWithStockAndSale(2, 100, 200);

        // [WHEN] [THEN] The classes follow the GMROII thresholds
        VerifyModelUsesItsOwnThresholds(Enum::"GSO ABC Model"::GMROII, ItemNo);
    end;

    [Test]
    procedure PickFrequencyUsesItsOwnThresholds()
    var
        ItemNo: array[3] of Code[20];
    begin
        // [GIVEN] Three items with 6, 3 and 1 sales entries
        Initialize();
        ItemNo[1] := CreateItemWithSalesEntries(6);
        ItemNo[2] := CreateItemWithSalesEntries(3);
        ItemNo[3] := CreateItemWithSalesEntries(1);

        // [WHEN] [THEN] The classes follow the Pick Frequency thresholds
        VerifyModelUsesItsOwnThresholds(Enum::"GSO ABC Model"::"Pick Frequency", ItemNo);
    end;

    // ---- which items take part ----

    [Test]
    procedure LossMakingItemIsLeftOutOrClassD()
    var
        Setup: Record "GSO ABC Analysis Setup";
        TempPreview: Record "GSO ABC Preview Line" temporary;
        ItemNo: Code[20];
    begin
        // [GIVEN] An item sold for 100 at a cost of 300, so the gross profit is negative
        Initialize();
        Lib.CreateItemWithSale(500, 100);
        ItemNo := Lib.CreateItemWithSale(100, 300);

        // [WHEN] The Gross Profit preview is calculated without class D
        Mgt.CalculatePreview(Enum::"GSO ABC Model"::"Gross Profit", Lib.GetTestDate(), Lib.GetTestDate(), TempPreview);

        // [THEN] The item is left out
        TempPreview.SetRange("Item No.", ItemNo);
        Assert.RecordIsEmpty(TempPreview);

        // [WHEN] The preview is calculated with "Zero Consumption as D"
        Mgt.EnsureSetup(Setup);
        Setup."Zero Consumption as D" := true;
        Setup.Modify(false);
        Mgt.CalculatePreview(Enum::"GSO ABC Model"::"Gross Profit", Lib.GetTestDate(), Lib.GetTestDate(), TempPreview);

        // [THEN] The item is class D with value 0, never a negative value
        TempPreview.SetRange("Item No.", ItemNo);
        Assert.IsTrue(TempPreview.FindFirst(), 'Loss-making item must be in the preview');
        Assert.AreEqual(Enum::"GSO ABC Class"::D, TempPreview.Class, 'Loss-making item class');
        Assert.AreEqual(0, TempPreview.Value, 'Loss-making item value');
    end;

    [Test]
    procedure NonInventoryItemFollowsSetup()
    var
        Item: Record Item;
        Setup: Record "GSO ABC Analysis Setup";
        TempPreview: Record "GSO ABC Preview Line" temporary;
    begin
        // [GIVEN] A service item, and "Zero Consumption as D" on so that items without value are listed
        Initialize();
        LibraryInventory.CreateServiceTypeItem(Item);
        Mgt.EnsureSetup(Setup);
        Setup."Zero Consumption as D" := true;
        Setup."Exclude Non-Inventory" := false;
        Setup.Modify(false);

        // [WHEN] The preview is calculated with non-inventory items included
        Mgt.CalculatePreview(Enum::"GSO ABC Model"::Revenue, Lib.GetTestDate(), Lib.GetTestDate(), TempPreview);

        // [THEN] The service item is in the preview
        TempPreview.SetRange("Item No.", Item."No.");
        Assert.RecordIsNotEmpty(TempPreview);

        // [WHEN] "Exclude Non-Inventory" is switched on
        Setup."Exclude Non-Inventory" := true;
        Setup.Modify(false);
        Mgt.CalculatePreview(Enum::"GSO ABC Model"::Revenue, Lib.GetTestDate(), Lib.GetTestDate(), TempPreview);

        // [THEN] The service item is left out
        TempPreview.SetRange("Item No.", Item."No.");
        Assert.RecordIsEmpty(TempPreview);
    end;

    [Test]
    procedure BlockedItemIsLeftOut()
    var
        Item: Record Item;
        TempPreview: Record "GSO ABC Preview Line" temporary;
        ItemNo: Code[20];
    begin
        // [GIVEN] An item with sales that is blocked
        Initialize();
        Lib.CreateItemWithSale(500, 0);
        ItemNo := Lib.CreateItemWithSale(300, 0);
        Item.Get(ItemNo);
        Item.Blocked := true;
        Item.Modify(false);

        // [WHEN] The Revenue preview is calculated
        Mgt.CalculatePreview(Enum::"GSO ABC Model"::Revenue, Lib.GetTestDate(), Lib.GetTestDate(), TempPreview);

        // [THEN] The blocked item is not in the preview
        TempPreview.SetRange("Item No.", ItemNo);
        Assert.RecordIsEmpty(TempPreview);
    end;

    [Test]
    procedure PreviewIsRebuiltOnEveryCalculation()
    var
        TempPreview: Record "GSO ABC Preview Line" temporary;
    begin
        // [GIVEN] A preview with two lines
        Initialize();
        Lib.CreateItemWithSale(700, 0);
        Lib.CreateItemWithSale(300, 0);
        Mgt.CalculatePreview(Enum::"GSO ABC Model"::Revenue, Lib.GetTestDate(), Lib.GetTestDate(), TempPreview);
        Assert.RecordCount(TempPreview, 2);

        // [WHEN] The preview is calculated again for a day without activity
        Mgt.CalculatePreview(Enum::"GSO ABC Model"::Revenue, Lib.GetTestDate() - 1, Lib.GetTestDate() - 1, TempPreview);

        // [THEN] The old lines are gone
        Assert.RecordIsEmpty(TempPreview);
    end;

    // ---- periods ----

    [Test]
    procedure DefaultDatesUseThePeriodOfEachModel()
    var
        Model: Enum "GSO ABC Model";
        Ordinal: Integer;
        Days: Integer;
        StartDt: Date;
        EndDt: Date;
    begin
        // [GIVEN] A different period for every model: 10, 20, 30, 40, 50 and 60 days
        Initialize();
        foreach Ordinal in Model.Ordinals() do begin
            Days += 10;
            Lib.SetPeriod(Enum::"GSO ABC Model".FromInteger(Ordinal), Days);
        end;

        // [WHEN] [THEN] Every model ends on the work date and starts its own number of days earlier
        Days := 0;
        foreach Ordinal in Model.Ordinals() do begin
            Days += 10;
            Model := Enum::"GSO ABC Model".FromInteger(Ordinal);
            Mgt.GetDefaultDates(Model, StartDt, EndDt);
            Assert.AreEqual(WorkDate(), EndDt, StrSubstNo(ModelCheckMsg, 'End date', Model));
            Assert.AreEqual(WorkDate() - Days, StartDt, StrSubstNo(ModelCheckMsg, 'Start date', Model));
        end;
    end;

    [Test]
    procedure DefaultDatesFallBackToOneYear()
    var
        StartDt: Date;
        EndDt: Date;
    begin
        // [GIVEN] A Revenue period of 0 days
        Initialize();
        Lib.SetPeriod(Enum::"GSO ABC Model"::Revenue, 0);

        // [WHEN] The default dates are requested
        Mgt.GetDefaultDates(Enum::"GSO ABC Model"::Revenue, StartDt, EndDt);

        // [THEN] The window is 365 days
        Assert.AreEqual(WorkDate() - 365, StartDt, 'Start date');
    end;

    // ---- setup and policy ----

    [Test]
    procedure GetSetupReturnsDefaultsWithoutInserting()
    var
        Setup: Record "GSO ABC Analysis Setup";
        StoredSetup: Record "GSO ABC Analysis Setup";
    begin
        // [GIVEN] No setup record
        Initialize();
        StoredSetup.DeleteAll(false);

        // [WHEN] The setup is read
        Mgt.GetSetup(Setup);

        // [THEN] The defaults are returned and nothing is inserted
        Assert.AreEqual(80, Setup."Rev A %", 'Default Revenue A %');
        Assert.AreEqual(95, Setup."Pick Freq B %", 'Default Pick Frequency B %');
        Assert.AreEqual(365, Setup."GMROII Period (Days)", 'Default GMROII period');
        Assert.AreEqual('DEFAULT', Setup."Counting Code Mapping ID", 'Default counting policy code');
        Assert.RecordIsEmpty(StoredSetup);
    end;

    [Test]
    procedure EnsureSetupInsertsDefaults()
    var
        Setup: Record "GSO ABC Analysis Setup";
        StoredSetup: Record "GSO ABC Analysis Setup";
    begin
        // [GIVEN] No setup record
        Initialize();
        StoredSetup.DeleteAll(false);

        // [WHEN] The setup is ensured
        Mgt.EnsureSetup(Setup);

        // [THEN] One record exists with the defaults and the installed version
        Assert.RecordCount(StoredSetup, 1);
        StoredSetup.FindFirst();
        Assert.IsTrue(StoredSetup.Enabled, 'Enabled by default');
        Assert.IsTrue(StoredSetup."Zero Consumption as D", 'Class D by default');
        Assert.AreEqual('DEFAULT', StoredSetup."Counting Code Mapping ID", 'Default counting policy code');
        Assert.AreNotEqual('', StoredSetup."Last Upgraded To", 'Installed version');
    end;

    [Test]
    procedure EnsurePolicyWithoutCodeDoesNothing()
    var
        PolicyHeader: Record "GSO ABC Counting Policy Header";
        HeadersBefore: Integer;
    begin
        // [GIVEN] The existing policies
        Initialize();
        HeadersBefore := PolicyHeader.Count();

        // [WHEN] [THEN] A blank code returns false and creates nothing
        Assert.IsFalse(Mgt.EnsurePolicyExists(''), 'Blank policy code');
        Assert.RecordCount(PolicyHeader, HeadersBefore);
    end;

    [Test]
    procedure EnsurePolicyKeepsExistingLines()
    var
        PolicyHeader: Record "GSO ABC Counting Policy Header";
        PolicyLine: Record "GSO ABC Counting Policy Line";
        PeriodCode: Code[10];
    begin
        // [GIVEN] A policy whose Revenue class A line has a counting period, and whose class D line was deleted
        Initialize();
        PeriodCode := Lib.CreateCountingPeriod('ABCT-K');
        Mgt.EnsurePolicyExists('ABCTKEEP');
        PolicyLine.Get('ABCTKEEP', Enum::"GSO ABC Model"::Revenue, Enum::"GSO ABC Class"::A);
        PolicyLine."Counting Period Code" := PeriodCode;
        PolicyLine.Modify(false);
        PolicyLine.Get('ABCTKEEP', Enum::"GSO ABC Model"::Revenue, Enum::"GSO ABC Class"::D);
        PolicyLine.Delete(false);

        // [WHEN] The policy is ensured again
        Mgt.EnsurePolicyExists('ABCTKEEP');

        // [THEN] The header has a description, the edited line is kept and the missing line is back
        PolicyHeader.Get('ABCTKEEP');
        Assert.AreNotEqual('', PolicyHeader.Description, 'Policy description');
        PolicyLine.Get('ABCTKEEP', Enum::"GSO ABC Model"::Revenue, Enum::"GSO ABC Class"::A);
        Assert.AreEqual(PeriodCode, PolicyLine."Counting Period Code", 'Edited line must be kept');
        PolicyLine.Reset();
        PolicyLine.SetRange("Header Code", 'ABCTKEEP');
        Assert.RecordCount(PolicyLine, 24);
    end;

    // ---- apply ----

    [Test]
    procedure ApplyWritesClassForEveryModel()
    var
        TempPreview: Record "GSO ABC Preview Line" temporary;
        Model: Enum "GSO ABC Model";
        Ordinal: Integer;
        ItemNo: Code[20];
    begin
        // [GIVEN] An item with a stockkeeping unit and a preview line with class B
        Initialize();
        ItemNo := Lib.CreateItem(0);
        Lib.CreateSKU(ItemNo);
        Lib.AddPreviewLine(TempPreview, ItemNo, 100, Enum::"GSO ABC Class"::B);

        foreach Ordinal in Model.Ordinals() do begin
            Model := Enum::"GSO ABC Model".FromInteger(Ordinal);

            // [WHEN] The preview is applied for the model
            Assert.AreEqual(1, Mgt.ApplyPreview(TempPreview, Model, Lib.GetTestDate(), Lib.GetTestDate()), StrSubstNo(ModelCheckMsg, 'Items updated', Model));

            // [THEN] The class and timestamp of that model are set on the item and the class on the SKU
            Assert.AreEqual(Enum::"GSO ABC Class"::B, Lib.GetItemClass(ItemNo, Model), StrSubstNo(ModelCheckMsg, 'Item class', Model));
            Assert.AreNotEqual(0DT, Lib.GetItemLastCalc(ItemNo, Model), StrSubstNo(ModelCheckMsg, 'Item timestamp', Model));
            Assert.AreEqual(Enum::"GSO ABC Class"::B, Lib.GetSKUClass(ItemNo, Model), StrSubstNo(ModelCheckMsg, 'SKU class', Model));
        end;
    end;

    [Test]
    procedure ApplyOnlyTouchesTheAppliedModel()
    var
        TempPreview: Record "GSO ABC Preview Line" temporary;
        ItemNo: Code[20];
    begin
        // [GIVEN] An item and a preview line with class A
        Initialize();
        ItemNo := Lib.CreateItem(0);
        Lib.AddPreviewLine(TempPreview, ItemNo, 100, Enum::"GSO ABC Class"::A);

        // [WHEN] The preview is applied for Usage Value
        Mgt.ApplyPreview(TempPreview, Enum::"GSO ABC Model"::"Usage Value", Lib.GetTestDate(), Lib.GetTestDate());

        // [THEN] Only the Usage Value class is set
        Assert.AreEqual(Enum::"GSO ABC Class"::A, Lib.GetItemClass(ItemNo, Enum::"GSO ABC Model"::"Usage Value"), 'Usage Value class');
        Assert.AreEqual(Enum::"GSO ABC Class"::Unknown, Lib.GetItemClass(ItemNo, Enum::"GSO ABC Model"::Revenue), 'Revenue class');
        Assert.AreEqual(Enum::"GSO ABC Class"::Unknown, Lib.GetItemClass(ItemNo, Enum::"GSO ABC Model"::GMROII), 'GMROII class');
    end;

    [Test]
    procedure ApplyLeavesSKUCountingPeriodWhenUpdateSKUIsOff()
    var
        Item: Record Item;
        SKU: Record "Stockkeeping Unit";
        Setup: Record "GSO ABC Analysis Setup";
        PolicyLine: Record "GSO ABC Counting Policy Line";
        ItemNo: array[2] of Code[20];
        PeriodCode: Code[10];
    begin
        // [GIVEN] A policy that maps Revenue class A to a counting period, with "Update SKU" off
        Initialize();
        PeriodCode := Lib.CreateCountingPeriod('ABCT-M');
        Mgt.EnsureSetup(Setup);
        Setup."Counting Code Mapping ID" := 'ABCTPOL2';
        Setup."Update Counting Codes" := true;
        Setup."Update SKU" := false;
        Setup.Modify(false);
        Mgt.EnsurePolicyExists('ABCTPOL2');
        PolicyLine.Get('ABCTPOL2', Enum::"GSO ABC Model"::Revenue, Enum::"GSO ABC Class"::A);
        PolicyLine."Counting Period Code" := PeriodCode;
        PolicyLine.Modify(false);

        // [GIVEN] A class A item with a stockkeeping unit and a class C item
        ItemNo[1] := Lib.CreateItemWithSale(700, 0);
        ItemNo[2] := Lib.CreateItemWithSale(300, 0);
        Lib.CreateSKU(ItemNo[1]);

        // [WHEN] The Revenue preview is applied
        Lib.CalculateAndApply(Enum::"GSO ABC Model"::Revenue);

        // [THEN] The class A item gets the counting period, its SKU gets the class but not the period
        Item.Get(ItemNo[1]);
        Assert.AreEqual(PeriodCode, Item."Phys Invt Counting Period Code", 'Item counting period');
        SKU.SetRange("Item No.", ItemNo[1]);
        SKU.FindFirst();
        Assert.AreEqual(Enum::"GSO ABC Class"::A, SKU."GSO Class (Revenue)", 'SKU class');
        Assert.AreEqual('', SKU."Phys Invt Counting Period Code", 'SKU counting period must stay blank');

        // [THEN] The class C item, whose policy line has no period, keeps a blank counting period
        Item.Get(ItemNo[2]);
        Assert.AreEqual('', Item."Phys Invt Counting Period Code", 'Counting period of a class without mapping');
    end;

    [Test]
    procedure ApplyStampsLastRunOnSetup()
    var
        Setup: Record "GSO ABC Analysis Setup";
    begin
        // [GIVEN] A setup without a last run
        Initialize();
        Mgt.EnsureSetup(Setup);
        Setup."Last Run" := 0DT;
        Setup.Modify(false);
        Lib.CreateItemWithSale(500, 0);

        // [WHEN] The Revenue preview is applied
        Lib.CalculateAndApply(Enum::"GSO ABC Model"::Revenue);

        // [THEN] The setup shows when classes were last applied
        Setup.Get(Setup."Primary Key");
        Assert.AreNotEqual(0DT, Setup."Last Run", 'Last run');
    end;

    [Test]
    procedure HistoryRecordsThePeriodAndTheLines()
    var
        HistHdr: Record "GSO ABC History Header";
        HistLine: Record "GSO ABC History Line";
        ItemNo: Code[20];
        LastEntryNo: Integer;
    begin
        // [GIVEN] Two items with gross profit 600 and 400
        Initialize();
        ItemNo := Lib.CreateItemWithSale(700, 100);
        Lib.CreateItemWithSale(500, 100);
        LastEntryNo := Lib.LastHistoryEntryNo();

        // [WHEN] The Gross Profit preview is applied
        Lib.CalculateAndApply(Enum::"GSO ABC Model"::"Gross Profit");

        // [THEN] The history entry carries model, period, user and totals
        HistHdr.SetFilter("Entry No.", '>%1', LastEntryNo);
        Assert.RecordCount(HistHdr, 1);
        HistHdr.FindFirst();
        Assert.AreEqual(Enum::"GSO ABC Model"::"Gross Profit", HistHdr.Model, 'History model');
        Assert.AreEqual(Lib.GetTestDate(), HistHdr."Start Date", 'History start date');
        Assert.AreEqual(Lib.GetTestDate(), HistHdr."End Date", 'History end date');
        Assert.AreEqual(UpperCase(UserId()), UpperCase(HistHdr."Created By"), 'History user');
        Assert.AreEqual(1000, HistHdr."Total Amount", 'History total amount');

        // [THEN] The line of the first item carries value, share, cumulative share and class
        HistLine.SetRange("Entry No.", HistHdr."Entry No.");
        HistLine.SetRange("Item No.", ItemNo);
        HistLine.FindFirst();
        Assert.AreEqual(600, HistLine.Value, 'History line value');
        Assert.AreNearlyEqual(60, HistLine."Value %", 0.001, 'History line value %');
        Assert.AreNearlyEqual(60, HistLine."Cum. %", 0.001, 'History line cumulative %');
        Assert.AreEqual(Enum::"GSO ABC Class"::A, HistLine.Class, 'History line class');
    end;

    [Test]
    procedure DeletingAHistoryEntryDeletesItsLines()
    var
        HistHdr: Record "GSO ABC History Header";
        HistLine: Record "GSO ABC History Line";
        KeptEntryNo: Integer;
    begin
        // [GIVEN] Two history entries with two lines each
        Initialize();
        Lib.CreateItemWithSale(700, 0);
        Lib.CreateItemWithSale(300, 0);
        Lib.CalculateAndApply(Enum::"GSO ABC Model"::Revenue);
        KeptEntryNo := Lib.LastHistoryEntryNo();
        Lib.CalculateAndApply(Enum::"GSO ABC Model"::Revenue);
        HistHdr.Get(Lib.LastHistoryEntryNo());

        // [WHEN] The second entry is deleted
        HistHdr.Delete(true);

        // [THEN] Its lines are gone and the lines of the first entry are still there
        HistLine.SetRange("Entry No.", HistHdr."Entry No.");
        Assert.RecordIsEmpty(HistLine);
        HistLine.SetRange("Entry No.", KeptEntryNo);
        Assert.RecordCount(HistLine, 2);
    end;

    // ---- helpers ----

    local procedure Initialize()
    begin
        Lib.Initialize(2098);
    end;

    local procedure CreateItemWithSalesEntries(NoOfSales: Integer): Code[20]
    var
        ItemNo: Code[20];
        i: Integer;
    begin
        ItemNo := Lib.CreateItem(10);
        Lib.PostEntry(ItemNo, Enum::"Item Ledger Entry Type"::"Positive Adjmt.", NoOfSales, 10);
        for i := 1 to NoOfSales do
            Lib.PostEntry(ItemNo, Enum::"Item Ledger Entry Type"::Sale, 1, 20);
        exit(ItemNo);
    end;

    /// <summary>
    /// The three items have a 60 %, 30 % and 10 % share. With thresholds 80/95 that is A, B, C and with 50/90
    /// it is B, B, C. The other models are set to 10/20, which would give C, C, C.
    /// </summary>
    local procedure VerifyModelUsesItsOwnThresholds(Model: Enum "GSO ABC Model"; ItemNo: array[3] of Code[20])
    var
        TempPreview: Record "GSO ABC Preview Line" temporary;
    begin
        Lib.SetAllThresholds(10, 20);
        Lib.SetThresholds(Model, 80, 95);
        Mgt.CalculatePreview(Model, Lib.GetTestDate(), Lib.GetTestDate(), TempPreview);
        Assert.RecordCount(TempPreview, 3);
        VerifyPreviewClass(TempPreview, ItemNo[1], 60, Enum::"GSO ABC Class"::A);
        VerifyPreviewClass(TempPreview, ItemNo[2], 90, Enum::"GSO ABC Class"::B);
        VerifyPreviewClass(TempPreview, ItemNo[3], 100, Enum::"GSO ABC Class"::C);

        Lib.SetThresholds(Model, 50, 90);
        Mgt.CalculatePreview(Model, Lib.GetTestDate(), Lib.GetTestDate(), TempPreview);
        VerifyPreviewClass(TempPreview, ItemNo[1], 60, Enum::"GSO ABC Class"::B);
        VerifyPreviewClass(TempPreview, ItemNo[2], 90, Enum::"GSO ABC Class"::B);
        VerifyPreviewClass(TempPreview, ItemNo[3], 100, Enum::"GSO ABC Class"::C);
    end;

    local procedure VerifyPreviewClass(var TempPreview: Record "GSO ABC Preview Line" temporary; ItemNo: Code[20]; ExpectedCumPct: Decimal; ExpectedClass: Enum "GSO ABC Class")
    begin
        TempPreview.Reset();
        TempPreview.SetRange("Item No.", ItemNo);
        Assert.IsTrue(TempPreview.FindFirst(), 'Preview line of item ' + ItemNo);
        Assert.AreNearlyEqual(ExpectedCumPct, TempPreview."Cum. %", 0.001, 'Cumulative % of item ' + ItemNo);
        Assert.AreEqual(ExpectedClass, TempPreview.Class, 'Class of item ' + ItemNo);
        TempPreview.Reset();
    end;
}
