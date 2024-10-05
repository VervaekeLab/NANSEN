classdef tableLight < uim.style.tableTheme
    
    properties (Constant)
        
        HeaderBackgroundColor = [0.95, 0.95, 0.95]
        HeaderForegroundColor = [0.05, 0.05, 0.05]
        TableBackgroundColor = [0.95, 0.95, 0.95]
        TableForegroundColor = [0.05, 0.05, 0.05]
        TableBackgroundColorSelected = [240,171,15] ./ 255
        TableForegroundColorSelected = [0.95, 0.95, 0.95]
        TableBackgroundColorDisabled = [0.85, 0.85, 0.85]
        TableForegroundColorDisabled = [0.15, 0.15, 0.15]
        CellColorUnmodified = [1, 1, 1]
        CellColorModified = [1, 1, 1]
        GridColor = [0.9, 0.9, 0.9]
        BorderColor = [240,171,15] ./ 255
        BorderWidth = 0
        SortArrowForeground = [240,171,15] ./ 255
        SortOrderForeground = [240,171,15] ./ 255
        
    end
end
