classdef tableDark < uim.style.tableTheme
    
    properties (Constant)
        
        HeaderBackgroundColor = [0.15, 0.15, 0.15]
        HeaderForegroundColor = [0.95, 0.95, 0.95] 
        TableBackgroundColor = [0.05, 0.05, 0.05]
        TableForegroundColor = [0.85, 0.85, 0.85] 
        TableBackgroundColorSelected = [48,62,76]/255; %[240,171,15] ./ 255
        TableForegroundColorSelected = [0.95, 0.95, 0.95]
        TableBackgroundColorDisabled = [0.15, 0.15, 0.15]
        TableForegroundColorDisabled = [0.75, 0.75, 0.75]
        CellColorUnmodified = [0.15, 0.15, 0.15]
        CellColorModified = [0.15, 0.15, 0.15]
        GridColor = [0.3, 0.3, 0.3]
        BorderColor = [240,171,15] ./ 255
        BorderWidth = 0
        SortArrowForeground = [240,171,15] ./ 255
        SortOrderForeground = [240,171,15] ./ 255
    end

end