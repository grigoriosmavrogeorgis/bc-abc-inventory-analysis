namespace GMSoft.ABCInventoryAnalysis.Tests;

using GMSoft.ABCInventoryAnalysis;
using Microsoft.Finance.GeneralLedger.Setup;
using Microsoft.Inventory.Counting.Journal;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Location;
using System.Security.User;

/// <summary>
/// Shared test data helpers for the ABC test codeunits.
/// Every test codeunit posts in a year of its own and every test on a day of its own, three days apart,
/// so entries from earlier tests never fall inside the analysis window of a later test.
/// </summary>
codeunit 50010 "GSO ABC Test Library"
{
    var
        Mgt: Codeunit "GSO ABC Analysis Mgt.";
        LibraryInventory: Codeunit "Library - Inventory";
        TestDate: Date;
        SavedWorkDate: Date;
        TestCounter: Integer;
        LocationCodeTok: Label 'ABCTLOC', Locked = true;
        DefaultPolicyTok: Label 'DEFAULT', Locked = true;

    /// <summary>
    /// Starts a test: picks the posting day, lifts the allowed posting date range and resets the setup to
    /// A 80 %, B 95 %, 365 days for every model, with class D, non-inventory exclusion and counting codes off.
    /// </summary>
    procedure Initialize(BaseYear: Integer)
    var
        GeneralLedgerSetup: Record "General Ledger Setup";
        UserSetup: Record "User Setup";
    begin
        if SavedWorkDate = 0D then
            SavedWorkDate := WorkDate();
        WorkDate(SavedWorkDate);

        TestCounter += 1;
        TestDate := DMY2Date(1, 1, BaseYear) + TestCounter * 3;

        GeneralLedgerSetup.Get();
        GeneralLedgerSetup."Allow Posting From" := 0D;
        GeneralLedgerSetup."Allow Posting To" := 0D;
        GeneralLedgerSetup.Modify(false);
        if UserSetup.Get(UserId()) then begin
            UserSetup."Allow Posting From" := 0D;
            UserSetup."Allow Posting To" := 0D;
            UserSetup.Modify(false);
        end;

        ResetSetup();
    end;

    procedure ResetSetup()
    var
        Setup: Record "GSO ABC Analysis Setup";
    begin
        Mgt.EnsureSetup(Setup);
        Setup.Enabled := true;
        Setup."Zero Consumption as D" := false;
        Setup."Exclude Non-Inventory" := false;
        Setup."Update Counting Codes" := false;
        Setup."Update SKU" := false;
        Setup."Counting Code Mapping ID" := DefaultPolicyTok;
        Setup.Modify(false);
        SetAllThresholds(80, 95);
        SetAllPeriods(365);
    end;

    procedure SetAllThresholds(APct: Decimal; BPct: Decimal)
    var
        Model: Enum "GSO ABC Model";
        Ordinal: Integer;
    begin
        foreach Ordinal in Model.Ordinals() do
            SetThresholds(Enum::"GSO ABC Model".FromInteger(Ordinal), APct, BPct);
    end;

    procedure SetThresholds(Model: Enum "GSO ABC Model"; APct: Decimal; BPct: Decimal)
    var
        Setup: Record "GSO ABC Analysis Setup";
    begin
        Mgt.EnsureSetup(Setup);
        case Model of
            Model::Revenue:
                begin
                    Setup."Rev A %" := APct;
                    Setup."Rev B %" := BPct;
                end;
            Model::"Gross Profit":
                begin
                    Setup."GP A %" := APct;
                    Setup."GP B %" := BPct;
                end;
            Model::COGS:
                begin
                    Setup."COGS A %" := APct;
                    Setup."COGS B %" := BPct;
                end;
            Model::"Usage Value":
                begin
                    Setup."Usage Value A %" := APct;
                    Setup."Usage Value B %" := BPct;
                end;
            Model::GMROII:
                begin
                    Setup."GMROII A %" := APct;
                    Setup."GMROII B %" := BPct;
                end;
            Model::"Pick Frequency":
                begin
                    Setup."Pick Freq A %" := APct;
                    Setup."Pick Freq B %" := BPct;
                end;
        end;
        Setup.Modify(false);
    end;

    procedure SetAllPeriods(Days: Integer)
    var
        Model: Enum "GSO ABC Model";
        Ordinal: Integer;
    begin
        foreach Ordinal in Model.Ordinals() do
            SetPeriod(Enum::"GSO ABC Model".FromInteger(Ordinal), Days);
    end;

    procedure SetPeriod(Model: Enum "GSO ABC Model"; Days: Integer)
    var
        Setup: Record "GSO ABC Analysis Setup";
    begin
        Mgt.EnsureSetup(Setup);
        case Model of
            Model::Revenue:
                Setup."Rev Period (Days)" := Days;
            Model::"Gross Profit":
                Setup."GP Period (Days)" := Days;
            Model::COGS:
                Setup."COGS Period (Days)" := Days;
            Model::"Usage Value":
                Setup."Usage Value Period (Days)" := Days;
            Model::GMROII:
                Setup."GMROII Period (Days)" := Days;
            Model::"Pick Frequency":
                Setup."Pick Freq Period (Days)" := Days;
        end;
        Setup.Modify(false);
    end;

    /// <summary>
    /// Makes the default analysis window of every model the day before the test date up to the test date,
    /// for code that takes its dates from the work date and the setup (job queue, reports, parameter dialog).
    /// </summary>
    procedure UseDefaultWindowOnTestDate()
    begin
        WorkDate(TestDate);
        SetAllPeriods(1);
    end;

    procedure RestoreWorkDate()
    begin
        if SavedWorkDate <> 0D then
            WorkDate(SavedWorkDate);
    end;

    procedure GetTestDate(): Date
    begin
        exit(TestDate);
    end;

    procedure CreateItem(UnitCost: Decimal): Code[20]
    var
        Item: Record Item;
    begin
        LibraryInventory.CreateItemSimple(Item, Enum::"Costing Method"::FIFO, UnitCost);
        exit(Item."No.");
    end;

    /// <summary>
    /// Creates an item, brings one unit into stock at the given cost and sells it at the given price.
    /// </summary>
    procedure CreateItemWithSale(SalesAmount: Decimal; UnitCost: Decimal): Code[20]
    begin
        exit(CreateItemWithStockAndSale(1, UnitCost, SalesAmount));
    end;

    /// <summary>
    /// Creates an item, brings the given quantity into stock at the given cost and sells one unit at the given price.
    /// </summary>
    procedure CreateItemWithStockAndSale(StockQty: Decimal; UnitCost: Decimal; SalesAmount: Decimal): Code[20]
    var
        ItemNo: Code[20];
    begin
        ItemNo := CreateItem(UnitCost);
        PostEntry(ItemNo, Enum::"Item Ledger Entry Type"::"Positive Adjmt.", StockQty, UnitCost);
        PostEntry(ItemNo, Enum::"Item Ledger Entry Type"::Sale, 1, SalesAmount);
        exit(ItemNo);
    end;

    procedure PostEntry(ItemNo: Code[20]; EntryType: Enum "Item Ledger Entry Type"; Qty: Decimal; UnitAmount: Decimal)
    var
        Item: Record Item;
        ItemJournalTemplate: Record "Item Journal Template";
    begin
        Item.Get(ItemNo);
        LibraryInventory.PostItemJournalLine(
            ItemJournalTemplate.Type::Item, EntryType, Item, '', '', '', Qty, TestDate, UnitAmount);
    end;

    procedure CreateSKU(ItemNo: Code[20])
    var
        Location: Record Location;
        SKU: Record "Stockkeeping Unit";
    begin
        if not Location.Get(LocationCodeTok) then begin
            Location.Init();
            Location.Code := LocationCodeTok;
            Location.Insert(false);
        end;
        SKU.Init();
        SKU."Location Code" := LocationCodeTok;
        SKU."Item No." := ItemNo;
        SKU.Insert(false);
    end;

    procedure CreateCountingPeriod(PeriodCode: Code[10]): Code[10]
    var
        CountingPeriod: Record "Phys. Invt. Counting Period";
    begin
        if CountingPeriod.Get(PeriodCode) then
            exit(PeriodCode);
        CountingPeriod.Init();
        CountingPeriod.Code := PeriodCode;
        CountingPeriod.Description := 'ABC test counting period';
        CountingPeriod."Count Frequency per Year" := 12;
        CountingPeriod.Insert(false);
        exit(PeriodCode);
    end;

    procedure AddPreviewLine(var TempPreview: Record "GSO ABC Preview Line" temporary; ItemNo: Code[20]; Value: Decimal; Class: Enum "GSO ABC Class")
    var
        LineNo: Integer;
    begin
        TempPreview.Reset();
        if TempPreview.FindLast() then
            LineNo := TempPreview."Line No.";
        TempPreview.Init();
        TempPreview."Line No." := LineNo + 10000;
        TempPreview."Item No." := ItemNo;
        TempPreview.Value := Value;
        TempPreview.Class := Class;
        TempPreview.Insert(false);
    end;

    /// <summary>
    /// Calculates the preview for the test date and applies it. Returns the number of items updated.
    /// </summary>
    procedure CalculateAndApply(Model: Enum "GSO ABC Model"): Integer
    var
        TempPreview: Record "GSO ABC Preview Line" temporary;
    begin
        Mgt.CalculatePreview(Model, TestDate, TestDate, TempPreview);
        exit(Mgt.ApplyPreview(TempPreview, Model, TestDate, TestDate));
    end;

    procedure GetItemClass(ItemNo: Code[20]; Model: Enum "GSO ABC Model"): Enum "GSO ABC Class"
    var
        Item: Record Item;
    begin
        Item.Get(ItemNo);
        case Model of
            Model::Revenue:
                exit(Item."GSO Class (Revenue)");
            Model::"Gross Profit":
                exit(Item."GSO Class (Gross Profit)");
            Model::COGS:
                exit(Item."GSO Class (COGS)");
            Model::"Usage Value":
                exit(Item."GSO Class (Usage Value)");
            Model::GMROII:
                exit(Item."GSO Class (GMROII)");
            Model::"Pick Frequency":
                exit(Item."GSO Class (Pick Frequency)");
        end;
    end;

    procedure GetItemLastCalc(ItemNo: Code[20]; Model: Enum "GSO ABC Model"): DateTime
    var
        Item: Record Item;
    begin
        Item.Get(ItemNo);
        case Model of
            Model::Revenue:
                exit(Item."GSO Last Calc (Revenue)");
            Model::"Gross Profit":
                exit(Item."GSO Last Calc (GP)");
            Model::COGS:
                exit(Item."GSO Last Calc (COGS)");
            Model::"Usage Value":
                exit(Item."GSO Last Calc (Usage Value)");
            Model::GMROII:
                exit(Item."GSO Last Calc (GMROII)");
            Model::"Pick Frequency":
                exit(Item."GSO Last Calc (Pick Freq)");
        end;
    end;

    procedure GetSKUClass(ItemNo: Code[20]; Model: Enum "GSO ABC Model"): Enum "GSO ABC Class"
    var
        SKU: Record "Stockkeeping Unit";
    begin
        SKU.SetRange("Item No.", ItemNo);
        SKU.FindFirst();
        case Model of
            Model::Revenue:
                exit(SKU."GSO Class (Revenue)");
            Model::"Gross Profit":
                exit(SKU."GSO Class (Gross Profit)");
            Model::COGS:
                exit(SKU."GSO Class (COGS)");
            Model::"Usage Value":
                exit(SKU."GSO Class (Usage Value)");
            Model::GMROII:
                exit(SKU."GSO Class (GMROII)");
            Model::"Pick Frequency":
                exit(SKU."GSO Class (Pick Frequency)");
        end;
    end;

    /// <summary>
    /// Returns the entry number of the newest history entry, 0 when there is none.
    /// Used to count the entries a test creates.
    /// </summary>
    procedure LastHistoryEntryNo(): Integer
    var
        HistHdr: Record "GSO ABC History Header";
    begin
        if HistHdr.FindLast() then
            exit(HistHdr."Entry No.");
        exit(0);
    end;
}
