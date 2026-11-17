namespace GMSoft.ABCInventoryAnalysis.Tests;

using GMSoft.ABCInventoryAnalysis;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Ledger;
using System.TestLibraries.Utilities;
using System.Utilities;

/// <summary>
/// Tests for the six reports. Every report is run through its request page and saved as XML, and the tests
/// read the dataset rows, so they check what the layouts receive without depending on the RDLC rendering.
/// </summary>
codeunit 50003 "GSO ABC Report Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Lib: Codeunit "GSO ABC Test Library";
        ReqModel: Enum "GSO ABC Model";
        ReqClassFilter: Enum "GSO ABC Class";
        ReqStartDate: Date;
        ReqEndDate: Date;
        ReqCompareDate: Date;
        ReqItemFilter: Text;
        ReqInventoryThreshold: Decimal;
        DataItemXPathTok: Label '//*[local-name()="DataItem" and @name="%1"]', Comment = '%1 = data item name', Locked = true;
        ColumnXPathTok: Label '*[local-name()="Columns"]/*[local-name()="Column" and @name="%1"]', Comment = '%1 = column name', Locked = true;
        CompareDateErr: Label 'Please specify a comparison date.';

    // ---- ABC Inventory Analysis ----

    [Test]
    [HandlerFunctions('AnalysisRequestPageHandler')]
    procedure AnalysisReportListsItemsByValue()
    var
        Rows: XmlNodeList;
        ItemNo: array[2] of Code[20];
    begin
        // [GIVEN] Two items with revenue 300 and 700
        Initialize();
        ItemNo[2] := Lib.CreateItemWithSale(300, 0);
        ItemNo[1] := Lib.CreateItemWithSale(700, 0);

        // [WHEN] The report runs for Revenue on the test date
        RunReport(Report::"GSO ABC Analysis", 'PreviewABC', Rows);

        // [THEN] Two rows, highest value first, with share and cumulative share
        Assert.AreEqual(2, Rows.Count(), 'Rows');
        Assert.AreEqual(ItemNo[1], ColumnText(Rows, 1, 'Item_No_'), 'First item');
        Assert.AreEqual(700, ColumnDecimal(Rows, 1, 'Value'), 'First value');
        Assert.AreNearlyEqual(70, ColumnDecimal(Rows, 1, 'CumPct'), 0.001, 'First cumulative %');
        Assert.AreEqual(ItemNo[2], ColumnText(Rows, 2, 'Item_No_'), 'Second item');
        Assert.AreNearlyEqual(30, ColumnDecimal(Rows, 2, 'ValuePct'), 0.001, 'Second value %');
        Assert.AreNearlyEqual(100, ColumnDecimal(Rows, 2, 'CumPct'), 0.001, 'Second cumulative %');
    end;

    [Test]
    [HandlerFunctions('AnalysisRequestPageHandler')]
    procedure AnalysisReportUsesTheSetupPeriodWhenDatesAreBlank()
    var
        Rows: XmlNodeList;
        ItemNo: Code[20];
    begin
        // [GIVEN] An item with revenue inside the default Revenue window, and blank dates on the request page
        Initialize();
        ItemNo := Lib.CreateItemWithSale(500, 0);
        Lib.UseDefaultWindowOnTestDate();
        ReqStartDate := 0D;
        ReqEndDate := 0D;

        // [WHEN] The report runs
        RunReport(Report::"GSO ABC Analysis", 'PreviewABC', Rows);

        // [THEN] The item is found through the default window
        Assert.AreEqual(1, Rows.Count(), 'Rows');
        Assert.AreEqual(ItemNo, ColumnText(Rows, 1, 'Item_No_'), 'Item');

        Lib.RestoreWorkDate();
    end;

    // ---- ABC Detail by Class ----

    [Test]
    [HandlerFunctions('DetailByClassRequestPageHandler')]
    procedure DetailByClassShowsTheFullRanking()
    var
        Rows: XmlNodeList;
        ItemNo: array[2] of Code[20];
    begin
        // [GIVEN] Two items with revenue 700 and 300, applied as class A and C
        Initialize();
        CreateAndApplyRevenueItems(ItemNo);

        // [WHEN] The report runs without filters
        RunReport(Report::"GSO ABC Detail by Class", 'PreviewLine', Rows);

        // [THEN] Both items are listed by value with the class from the item
        Assert.AreEqual(2, Rows.Count(), 'Rows');
        Assert.AreEqual(ItemNo[1], ColumnText(Rows, 1, 'ItemNo'), 'First item');
        Assert.AreEqual('A', ColumnText(Rows, 1, 'ABCClass'), 'First class');
        Assert.AreEqual(700, ColumnDecimal(Rows, 1, 'ItemValue'), 'First value');
        Assert.AreNearlyEqual(70, ColumnDecimal(Rows, 1, 'ValuePercent'), 0.001, 'First value %');
        Assert.AreEqual(ItemNo[2], ColumnText(Rows, 2, 'ItemNo'), 'Second item');
        Assert.AreEqual('C', ColumnText(Rows, 2, 'ABCClass'), 'Second class');
        Assert.AreNotEqual('', ColumnText(Rows, 2, 'LastCalculated'), 'Last calculated');
    end;

    [Test]
    [HandlerFunctions('DetailByClassRequestPageHandler')]
    procedure DetailByClassFiltersOnClass()
    var
        Rows: XmlNodeList;
        ItemNo: array[2] of Code[20];
    begin
        // [GIVEN] Two items applied as class A and C, and a class filter C
        Initialize();
        CreateAndApplyRevenueItems(ItemNo);
        ReqClassFilter := Enum::"GSO ABC Class"::C;

        // [WHEN] The report runs
        RunReport(Report::"GSO ABC Detail by Class", 'PreviewLine', Rows);

        // [THEN] Only the class C item is printed, with its cumulative share from the full ranking
        Assert.AreEqual(1, Rows.Count(), 'Rows');
        Assert.AreEqual(ItemNo[2], ColumnText(Rows, 1, 'ItemNo'), 'Item');
        Assert.AreNearlyEqual(100, ColumnDecimal(Rows, 1, 'CumulativePercent'), 0.001, 'Cumulative %');
        Assert.AreEqual('C', ColumnText(Rows, 1, 'ClassFilter'), 'Class filter text');
    end;

    [Test]
    [HandlerFunctions('DetailByClassRequestPageHandler')]
    procedure DetailByClassFiltersOnItem()
    var
        Rows: XmlNodeList;
        ItemNo: array[2] of Code[20];
    begin
        // [GIVEN] Two items applied as class A and C, and an item filter on the second item
        Initialize();
        CreateAndApplyRevenueItems(ItemNo);
        ReqItemFilter := ItemNo[2];

        // [WHEN] The report runs
        RunReport(Report::"GSO ABC Detail by Class", 'PreviewLine', Rows);

        // [THEN] Only that item is printed, and its shares still come from the full ranking
        Assert.AreEqual(1, Rows.Count(), 'Rows');
        Assert.AreEqual(ItemNo[2], ColumnText(Rows, 1, 'ItemNo'), 'Item');
        Assert.AreNearlyEqual(30, ColumnDecimal(Rows, 1, 'ValuePercent'), 0.001, 'Value %');
        Assert.AreNearlyEqual(100, ColumnDecimal(Rows, 1, 'CumulativePercent'), 0.001, 'Cumulative %');
    end;

    // ---- ABC Class Distribution ----

    [Test]
    [HandlerFunctions('DistributionRequestPageHandler')]
    procedure DistributionSummarisesItemsAndValuePerClass()
    var
        Item: Record Item;
        Rows: XmlNodeList;
        ItemNo: array[2] of Code[20];
    begin
        // [GIVEN] No item has a Revenue class, except two items applied as class A (700) and C (300)
        Initialize();
        Item.ModifyAll("GSO Class (Revenue)", Enum::"GSO ABC Class"::Unknown, false);
        CreateAndApplyRevenueItems(ItemNo);

        // [WHEN] The report runs for Revenue on the test date
        RunReport(Report::"GSO ABC Distribution", 'ClassGroup', Rows);

        // [THEN] One row for A, B and C; class D has no items and is not printed
        Assert.AreEqual(3, Rows.Count(), 'Rows');
        Assert.AreEqual('A', ColumnText(Rows, 1, 'ClassName'), 'First class');
        Assert.AreEqual(1, ColumnDecimal(Rows, 1, 'ItemCount'), 'Class A item count');
        Assert.AreEqual(700, ColumnDecimal(Rows, 1, 'TotalValue'), 'Class A value');
        Assert.AreNearlyEqual(70, ColumnDecimal(Rows, 1, 'ValuePercent'), 0.001, 'Class A value %');
        Assert.AreNearlyEqual(50, ColumnDecimal(Rows, 1, 'ItemPercent'), 0.001, 'Class A item %');
        Assert.AreEqual('B', ColumnText(Rows, 2, 'ClassName'), 'Second class');
        Assert.AreEqual(0, ColumnDecimal(Rows, 2, 'ItemCount'), 'Class B item count');
        Assert.AreEqual('C', ColumnText(Rows, 3, 'ClassName'), 'Third class');
        Assert.AreEqual(300, ColumnDecimal(Rows, 3, 'TotalValue'), 'Class C value');
        Assert.AreNearlyEqual(30, ColumnDecimal(Rows, 3, 'ValuePercent'), 0.001, 'Class C value %');
    end;

    // ---- ABC Multi-Model Comparison ----

    [Test]
    [HandlerFunctions('ComparisonRequestPageHandler')]
    procedure ComparisonRatesTheConsistencyOfTheClasses()
    var
        Rows: XmlNodeList;
        ItemNo: array[5] of Code[20];
        i: Integer;
    begin
        // [GIVEN] Four items with a sale of 100 and Revenue / Gross Profit classes A/A, A/B, A/C and A/blank
        Initialize();
        for i := 1 to 4 do
            ItemNo[i] := Lib.CreateItemWithSale(100, 0);
        SetClasses(ItemNo[1], Enum::"GSO ABC Class"::A, Enum::"GSO ABC Class"::A);
        SetClasses(ItemNo[2], Enum::"GSO ABC Class"::A, Enum::"GSO ABC Class"::B);
        SetClasses(ItemNo[3], Enum::"GSO ABC Class"::A, Enum::"GSO ABC Class"::C);
        SetClasses(ItemNo[4], Enum::"GSO ABC Class"::A, Enum::"GSO ABC Class"::Unknown);

        // [GIVEN] A fifth item with classes but without any value in the period
        ItemNo[5] := Lib.CreateItem(0);
        SetClasses(ItemNo[5], Enum::"GSO ABC Class"::A, Enum::"GSO ABC Class"::A);
        ReqItemFilter := StrSubstNo('%1|%2|%3|%4|%5', ItemNo[1], ItemNo[2], ItemNo[3], ItemNo[4], ItemNo[5]);

        // [WHEN] The report runs for the test date
        RunReport(Report::"GSO ABC Comparison", 'Item', Rows);

        // [THEN] The item without value is skipped; the others are rated by the spread of their classes
        Assert.AreEqual(4, Rows.Count(), 'Rows');
        Assert.AreEqual('Consistent', ColumnText(Rows, FindRow(Rows, 'ItemNo', ItemNo[1]), 'ConsistencyIndicator'), 'Same class');
        Assert.AreEqual('Minor Variance', ColumnText(Rows, FindRow(Rows, 'ItemNo', ItemNo[2]), 'ConsistencyIndicator'), 'One class apart');
        Assert.AreEqual('Inconsistent', ColumnText(Rows, FindRow(Rows, 'ItemNo', ItemNo[3]), 'ConsistencyIndicator'), 'Two classes apart');
        Assert.AreEqual('n/a', ColumnText(Rows, FindRow(Rows, 'ItemNo', ItemNo[4]), 'ConsistencyIndicator'), 'Only one class calculated');

        // [THEN] The values of the period are printed next to the classes
        Assert.AreEqual(100, ColumnDecimal(Rows, FindRow(Rows, 'ItemNo', ItemNo[1]), 'RevenueValue'), 'Revenue value');
        Assert.AreEqual(1, ColumnDecimal(Rows, FindRow(Rows, 'ItemNo', ItemNo[1]), 'PickFrequencyValue'), 'Pick frequency value');
        Assert.AreEqual('B', ColumnText(Rows, FindRow(Rows, 'ItemNo', ItemNo[2]), 'GrossProfitClass'), 'Gross profit class');
    end;

    // ---- ABC Exception Report ----

    [Test]
    [HandlerFunctions('ExceptionsRequestPageHandler')]
    procedure ExceptionsReportNamesTheFirstMatchingException()
    var
        Item: Record Item;
        Rows: XmlNodeList;
        ItemNo: array[6] of Code[20];
    begin
        // [GIVEN] The Revenue window is the day before the test date up to the test date
        Initialize();
        Lib.UseDefaultWindowOnTestDate();

        // [GIVEN] 1: never classified
        ItemNo[1] := Lib.CreateItem(0);

        // [GIVEN] 2: classified 100 days ago
        ItemNo[2] := Lib.CreateItem(0);
        SetClasses(ItemNo[2], Enum::"GSO ABC Class"::A, Enum::"GSO ABC Class"::Unknown);
        Item.Get(ItemNo[2]);
        Item."GSO Last Calc (Revenue)" := CreateDateTime(Today() - 100, 0T);
        Item.Modify(false);

        // [GIVEN] 3: classified now, Revenue A and Gross Profit C
        ItemNo[3] := Lib.CreateItem(0);
        SetClasses(ItemNo[3], Enum::"GSO ABC Class"::A, Enum::"GSO ABC Class"::C);

        // [GIVEN] 4: classified now, Revenue C, one unit in stock worth 100, above the threshold of 50
        ItemNo[4] := Lib.CreateItemWithStockAndSale(2, 100, 150);
        SetClasses(ItemNo[4], Enum::"GSO ABC Class"::C, Enum::"GSO ABC Class"::Unknown);

        // [GIVEN] 5: classified now, Revenue A, no entries in the window
        ItemNo[5] := Lib.CreateItem(0);
        SetClasses(ItemNo[5], Enum::"GSO ABC Class"::A, Enum::"GSO ABC Class"::Unknown);

        // [GIVEN] 6: classified now, Revenue A, sold in the window - nothing to report
        ItemNo[6] := Lib.CreateItemWithSale(100, 0);
        SetClasses(ItemNo[6], Enum::"GSO ABC Class"::A, Enum::"GSO ABC Class"::Unknown);

        ReqItemFilter := StrSubstNo('%1|%2|%3|%4|%5|%6', ItemNo[1], ItemNo[2], ItemNo[3], ItemNo[4], ItemNo[5], ItemNo[6]);
        ReqInventoryThreshold := 50;

        // [WHEN] The report runs
        RunReport(Report::"GSO ABC Exceptions", 'Item', Rows);

        // [THEN] Five exceptions, one per item, and the sixth item is not printed
        Assert.AreEqual(5, Rows.Count(), 'Rows');
        Assert.AreEqual('Never Calculated', ColumnText(Rows, FindRow(Rows, 'ItemNo', ItemNo[1]), 'ExceptionType'), 'Never classified');
        Assert.AreEqual('Outdated', ColumnText(Rows, FindRow(Rows, 'ItemNo', ItemNo[2]), 'ExceptionType'), 'Old classification');
        Assert.IsTrue(ColumnText(Rows, FindRow(Rows, 'ItemNo', ItemNo[2]), 'ExceptionDetails').Contains('90'), 'Default outdated threshold of 90 days');
        Assert.AreEqual('Inconsistent', ColumnText(Rows, FindRow(Rows, 'ItemNo', ItemNo[3]), 'ExceptionType'), 'Classes two steps apart');
        Assert.AreEqual('Inventory Mismatch', ColumnText(Rows, FindRow(Rows, 'ItemNo', ItemNo[4]), 'ExceptionType'), 'High inventory with class C');
        Assert.AreEqual('No Activity', ColumnText(Rows, FindRow(Rows, 'ItemNo', ItemNo[5]), 'ExceptionType'), 'No entries in the window');
        Assert.AreEqual(0, FindRow(Rows, 'ItemNo', ItemNo[6]), 'Item without exception must not be printed');

        Lib.RestoreWorkDate();
    end;

    // ---- ABC Item Movement ----

    [Test]
    [HandlerFunctions('MovementRequestPageHandler')]
    procedure MovementReportShowsItemsWhoseClassChanged()
    var
        Item: Record Item;
        Rows: XmlNodeList;
        ItemNo: array[2] of Code[20];
    begin
        // [GIVEN] Two items applied today as Revenue class A and C
        Initialize();
        Lib.UseDefaultWindowOnTestDate();
        CreateAndApplyRevenueItems(ItemNo);

        // [GIVEN] The class of the first item is C now
        Item.Get(ItemNo[1]);
        Item."GSO Class (Revenue)" := Enum::"GSO ABC Class"::C;
        Item.Modify(false);
        ReqItemFilter := StrSubstNo('%1|%2', ItemNo[1], ItemNo[2]);
        ReqCompareDate := Today();

        // [WHEN] The report compares the current classes with the last run up to today
        RunReport(Report::"GSO ABC Item Movement", 'Item', Rows);

        // [THEN] Only the first item is printed, as a move from A to C, with its value in the Revenue window
        Assert.AreEqual(1, Rows.Count(), 'Rows');
        Assert.AreEqual(ItemNo[1], ColumnText(Rows, 1, 'ItemNo'), 'Item');
        Assert.AreEqual('A', ColumnText(Rows, 1, 'PreviousClass'), 'Previous class');
        Assert.AreEqual('C', ColumnText(Rows, 1, 'CurrentClass'), 'Current class');
        Assert.AreEqual('A -> C', ColumnText(Rows, 1, 'Movement'), 'Movement');
        Assert.AreEqual(700, ColumnDecimal(Rows, 1, 'CurrentValue'), 'Current value');

        Lib.RestoreWorkDate();
    end;

    [Test]
    [HandlerFunctions('MovementRequestPageHandler')]
    procedure MovementReportNeedsAComparisonDate()
    var
        Rows: XmlNodeList;
    begin
        // [GIVEN] No comparison date on the request page
        Initialize();
        ReqItemFilter := Lib.CreateItem(0);
        ReqCompareDate := 0D;

        // [WHEN] The report runs
        asserterror RunReport(Report::"GSO ABC Item Movement", 'Item', Rows);

        // [THEN] It stops and asks for the date
        Assert.ExpectedError(CompareDateErr);
    end;

    // ---- helpers ----

    local procedure Initialize()
    begin
        Lib.Initialize(2096);
        ReqModel := Enum::"GSO ABC Model"::Revenue;
        ReqClassFilter := Enum::"GSO ABC Class"::Unknown;
        ReqStartDate := Lib.GetTestDate();
        ReqEndDate := Lib.GetTestDate();
        ReqCompareDate := 0D;
        ReqItemFilter := '';
        ReqInventoryThreshold := 0;
    end;

    local procedure CreateAndApplyRevenueItems(var ItemNo: array[2] of Code[20])
    begin
        ItemNo[1] := Lib.CreateItemWithSale(700, 0);
        ItemNo[2] := Lib.CreateItemWithSale(300, 0);
        Lib.CalculateAndApply(Enum::"GSO ABC Model"::Revenue);
    end;

    /// <summary>
    /// Sets the Revenue and Gross Profit class directly on the item, stamped as calculated now.
    /// </summary>
    local procedure SetClasses(ItemNo: Code[20]; RevenueClass: Enum "GSO ABC Class"; GrossProfitClass: Enum "GSO ABC Class")
    var
        Item: Record Item;
    begin
        Item.Get(ItemNo);
        Item."GSO Class (Revenue)" := RevenueClass;
        Item."GSO Last Calc (Revenue)" := CurrentDateTime();
        Item."GSO Class (Gross Profit)" := GrossProfitClass;
        if GrossProfitClass <> GrossProfitClass::Unknown then
            Item."GSO Last Calc (GP)" := CurrentDateTime();
        Item.Modify(false);
    end;

    /// <summary>
    /// Runs the report through its request page handler, saves the dataset as XML and returns the rows of one data item.
    /// </summary>
    local procedure RunReport(ReportId: Integer; DataItemName: Text; var Rows: XmlNodeList)
    var
        TempBlob: Codeunit "Temp Blob";
        Document: XmlDocument;
        Parameters: Text;
        OutStr: OutStream;
        InStr: InStream;
    begin
        Parameters := Report.RunRequestPage(ReportId);
        TempBlob.CreateOutStream(OutStr);
        Report.SaveAs(ReportId, Parameters, ReportFormat::Xml, OutStr);
        TempBlob.CreateInStream(InStr);
        XmlDocument.ReadFrom(InStr, Document);
        Document.SelectNodes(StrSubstNo(DataItemXPathTok, DataItemName), Rows);
    end;

    local procedure ColumnText(Rows: XmlNodeList; RowNo: Integer; ColumnName: Text): Text
    var
        Row: XmlNode;
        Column: XmlNode;
    begin
        Assert.IsTrue((RowNo >= 1) and (RowNo <= Rows.Count()), StrSubstNo('Row %1 with column %2 is not in the dataset', RowNo, ColumnName));
        Rows.Get(RowNo, Row);
        Assert.IsTrue(Row.SelectSingleNode(StrSubstNo(ColumnXPathTok, ColumnName), Column), StrSubstNo('Column %1 is not in the dataset', ColumnName));
        exit(Column.AsXmlElement().InnerText());
    end;

    local procedure ColumnDecimal(Rows: XmlNodeList; RowNo: Integer; ColumnName: Text) Result: Decimal
    var
        ValueText: Text;
    begin
        ValueText := ColumnText(Rows, RowNo, ColumnName);
        if not Evaluate(Result, ValueText, 9) then
            Evaluate(Result, ValueText);
    end;

    /// <summary>
    /// Returns the number of the first row whose column has the given value, 0 when there is none.
    /// </summary>
    local procedure FindRow(Rows: XmlNodeList; ColumnName: Text; ExpectedValue: Text): Integer
    var
        RowNo: Integer;
    begin
        for RowNo := 1 to Rows.Count() do
            if ColumnText(Rows, RowNo, ColumnName) = ExpectedValue then
                exit(RowNo);
        exit(0);
    end;

    // ---- request page handlers ----

    [RequestPageHandler]
    procedure AnalysisRequestPageHandler(var RequestPage: TestRequestPage "GSO ABC Analysis")
    begin
        RequestPage.ModelField.SetValue(ReqModel);
        RequestPage.StartDateField.SetValue(ReqStartDate);
        RequestPage.EndDateField.SetValue(ReqEndDate);
        RequestPage.OK().Invoke();
    end;

    [RequestPageHandler]
    procedure DetailByClassRequestPageHandler(var RequestPage: TestRequestPage "GSO ABC Detail by Class")
    begin
        RequestPage.ModelField.SetValue(ReqModel);
        if ReqClassFilter <> ReqClassFilter::Unknown then
            RequestPage.ClassFilterField.SetValue(ReqClassFilter);
        RequestPage.StartDateField.SetValue(ReqStartDate);
        RequestPage.EndDateField.SetValue(ReqEndDate);
        if ReqItemFilter <> '' then
            RequestPage.Item.SetFilter("No.", ReqItemFilter);
        RequestPage.OK().Invoke();
    end;

    [RequestPageHandler]
    procedure DistributionRequestPageHandler(var RequestPage: TestRequestPage "GSO ABC Distribution")
    begin
        RequestPage.ModelField.SetValue(ReqModel);
        RequestPage.StartDateField.SetValue(ReqStartDate);
        RequestPage.EndDateField.SetValue(ReqEndDate);
        RequestPage.OK().Invoke();
    end;

    [RequestPageHandler]
    procedure ComparisonRequestPageHandler(var RequestPage: TestRequestPage "GSO ABC Comparison")
    begin
        RequestPage.StartDateField.SetValue(ReqStartDate);
        RequestPage.EndDateField.SetValue(ReqEndDate);
        RequestPage.Item.SetFilter("No.", ReqItemFilter);
        RequestPage.OK().Invoke();
    end;

    [RequestPageHandler]
    procedure ExceptionsRequestPageHandler(var RequestPage: TestRequestPage "GSO ABC Exceptions")
    begin
        RequestPage.InventoryThresholdField.SetValue(ReqInventoryThreshold);
        RequestPage.Item.SetFilter("No.", ReqItemFilter);
        RequestPage.OK().Invoke();
    end;

    [RequestPageHandler]
    procedure MovementRequestPageHandler(var RequestPage: TestRequestPage "GSO ABC Item Movement")
    begin
        RequestPage.ModelField.SetValue(ReqModel);
        RequestPage.CompareDateField.SetValue(ReqCompareDate);
        RequestPage.Item.SetFilter("No.", ReqItemFilter);
        RequestPage.OK().Invoke();
    end;
}
