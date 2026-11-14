namespace GMSoft.ABCInventoryAnalysis;

using Microsoft.Inventory.Location;

tableextension 73031396 "GSO ABC SKU Ext." extends "Stockkeeping Unit"
{
    fields
    {
        // Per-model ABC classification fields
        field(73031395; "GSO Class (Revenue)"; Enum "GSO ABC Class") { Caption = 'ABC Class (Revenue)'; DataClassification = CustomerContent; Editable = false; }
        field(73031396; "GSO Class (Gross Profit)"; Enum "GSO ABC Class") { Caption = 'ABC Class (Gross Profit)'; DataClassification = CustomerContent; Editable = false; }
        field(73031397; "GSO Class (COGS)"; Enum "GSO ABC Class") { Caption = 'ABC Class (Value/COGS)'; DataClassification = CustomerContent; Editable = false; }
        field(73031401; "GSO Class (Usage Value)"; Enum "GSO ABC Class") { Caption = 'ABC Class (Usage Value)'; DataClassification = CustomerContent; Editable = false; }
        field(73031403; "GSO Class (GMROII)"; Enum "GSO ABC Class") { Caption = 'ABC Class (GMROII)'; DataClassification = CustomerContent; Editable = false; }
        field(73031405; "GSO Class (Pick Frequency)"; Enum "GSO ABC Class") { Caption = 'ABC Class (Pick Frequency)'; DataClassification = CustomerContent; Editable = false; }

        // Last calculation timestamp fields
        field(73031398; "GSO Last Calc (Revenue)"; DateTime) { Caption = 'ABC Last Calculated (Revenue)'; Editable = false; DataClassification = SystemMetadata; }
        field(73031399; "GSO Last Calc (GP)"; DateTime) { Caption = 'ABC Last Calculated (Gross Profit)'; Editable = false; DataClassification = SystemMetadata; }
        field(73031400; "GSO Last Calc (COGS)"; DateTime) { Caption = 'ABC Last Calculated (COGS)'; Editable = false; DataClassification = SystemMetadata; }
        field(73031402; "GSO Last Calc (Usage Value)"; DateTime) { Caption = 'ABC Last Calculated (Usage Value)'; Editable = false; DataClassification = SystemMetadata; }
        field(73031404; "GSO Last Calc (GMROII)"; DateTime) { Caption = 'ABC Last Calculated (GMROII)'; Editable = false; DataClassification = SystemMetadata; }
        field(73031406; "GSO Last Calc (Pick Freq)"; DateTime) { Caption = 'ABC Last Calculated (Pick Frequency)'; Editable = false; DataClassification = SystemMetadata; }
    }
}
