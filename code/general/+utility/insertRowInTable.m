function T = insertRowInTable(T, rowData, insertInd)
%utility.insertRowInTable Insert rows into table at specified row indices
%
%   T = utility.insertRowInTable(T, ROWDATA, INSERTIND)

    % Concatenate tables and count rows
    T = cat(1, T, rowData);
    numRows = size(T, 1);    
    
    % Determine how to reorder the rows to get them in the right order
    newRowInd = 1:numRows;
    rowIndForOriginalData = setdiff(newRowInd, insertInd);
    reorderedInd = [rowIndForOriginalData, insertInd];
    
    % Reorder rows before returning
    T(reorderedInd, :) = T;

end