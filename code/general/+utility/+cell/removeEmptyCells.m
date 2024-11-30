function cellArray = removeEmptyCells(cellArray)
    isEmptyCell = cellfun(@isempty, cellArray);
    cellArray( isEmptyCell ) = [];
end
