classdef tableTheme < handle
    
    properties (Abstract, Constant)
        
        HeaderBackgroundColor
        HeaderForegroundColor
        TableBackgroundColor
        TableForegroundColor
        TableBackgroundColorSelected
        TableForegroundColorSelected
        CellColorUnmodified
        CellColorModified
        GridColor
        BorderColor
        BorderWidth
        SortArrowForeground
        SortOrderForeground
    end
end
