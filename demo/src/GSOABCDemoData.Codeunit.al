namespace GMSoft.ABCInventoryAnalysis.Demo;

using GMSoft.ABCInventoryAnalysis;
using Microsoft.Inventory.Counting.Journal;

/// <summary>
/// Prepares a demo company for ABC Inventory Analysis: setup with class D and counting codes switched on,
/// monthly, quarterly and yearly counting periods mapped in the counting policy, and a first applied
/// Revenue run so the worksheet, history and reports have data. Only fills in what is empty; existing
/// setup, mappings and history are never overwritten.
/// </summary>
codeunit 60000 "GSO ABC Demo Data"
{
    Access = Public;

    var
        Mgt: Codeunit "GSO ABC Analysis Mgt.";
        MonthlyTok: Label 'ABC-M', Locked = true;
        QuarterlyTok: Label 'ABC-Q', Locked = true;
        YearlyTok: Label 'ABC-Y', Locked = true;
        MonthlyLbl: Label 'ABC class A - monthly count';
        QuarterlyLbl: Label 'ABC class B - quarterly count';
        YearlyLbl: Label 'ABC class C and D - yearly count';

    trigger OnRun()
    var
        Setup: Record "GSO ABC Analysis Setup";
    begin
        PrepareSetup(Setup);
        CreateCountingPeriod(MonthlyTok, MonthlyLbl, 12);
        CreateCountingPeriod(QuarterlyTok, QuarterlyLbl, 4);
        CreateCountingPeriod(YearlyTok, YearlyLbl, 1);
        MapCountingPolicy(Setup);
        RunFirstRevenueAnalysis();
    end;

    local procedure PrepareSetup(var Setup: Record "GSO ABC Analysis Setup")
    begin
        Mgt.EnsureSetup(Setup);
        // A setup that has been used already belongs to the customer; leave it alone.
        if Setup."Last Run" <> 0DT then
            exit;

        Setup."Zero Consumption as D" := true;
        Setup."Update Counting Codes" := true;
        Setup."Update SKU" := true;
        Setup.Modify(true);
    end;

    local procedure CreateCountingPeriod(PeriodCode: Code[10]; PeriodDescription: Text; CountsPerYear: Integer)
    var
        CountingPeriod: Record "Phys. Invt. Counting Period";
    begin
        if CountingPeriod.Get(PeriodCode) then
            exit;

        CountingPeriod.Init();
        CountingPeriod.Code := PeriodCode;
        CountingPeriod.Description := CopyStr(PeriodDescription, 1, MaxStrLen(CountingPeriod.Description));
        CountingPeriod."Count Frequency per Year" := CountsPerYear;
        CountingPeriod.Insert(true);
    end;

    local procedure MapCountingPolicy(Setup: Record "GSO ABC Analysis Setup")
    var
        PolicyLine: Record "GSO ABC Counting Policy Line";
    begin
        if not Mgt.EnsurePolicyExists(Setup."Counting Code Mapping ID") then
            exit;

        PolicyLine.SetRange("Header Code", Setup."Counting Code Mapping ID");
        PolicyLine.SetRange("Counting Period Code", '');
        if PolicyLine.FindSet(true) then
            repeat
                PolicyLine."Counting Period Code" := PeriodForClass(PolicyLine.Class);
                PolicyLine.Modify(true);
            until PolicyLine.Next() = 0;
    end;

    local procedure PeriodForClass(Class: Enum "GSO ABC Class"): Code[10]
    begin
        case Class of
            Class::A:
                exit(MonthlyTok);
            Class::B:
                exit(QuarterlyTok);
            else
                exit(YearlyTok);
        end;
    end;

    local procedure RunFirstRevenueAnalysis()
    var
        HistoryHeader: Record "GSO ABC History Header";
        TempPreview: Record "GSO ABC Preview Line" temporary;
        StartDate: Date;
        EndDate: Date;
    begin
        HistoryHeader.SetRange(Model, Enum::"GSO ABC Model"::Revenue);
        if not HistoryHeader.IsEmpty() then
            exit;

        Mgt.GetDefaultDates(Enum::"GSO ABC Model"::Revenue, StartDate, EndDate);
        Mgt.CalculatePreview(Enum::"GSO ABC Model"::Revenue, StartDate, EndDate, TempPreview);
        if not TempPreview.IsEmpty() then
            Mgt.ApplyPreview(TempPreview, Enum::"GSO ABC Model"::Revenue, StartDate, EndDate);
    end;
}
