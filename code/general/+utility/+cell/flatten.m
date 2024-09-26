function [flatCellArray, numElementsPerCell] = flatten(cellArray)
%FLATTEN Flatten a cell array by concatenating all elements of each cell
%
%   flatCellArray = flatten(cellArray) concatenates all elements of each
%       cell horizontally
%
%   [flatCellArray, numElementsPerCell] = flatten(cellArray) also returns
%       the original number of elements (numElementsPerCell) in each cell
%       of the cell array. This variable can be be used with the unflatten
%       function for reversing the flatten operation
%
%   Note1: Assume homogeneous cell array, i.e all elements in the cells are
%          same type.
%   Note2: Does not work on nested cell arrays.
    
    if isa(cellArray, 'cell')
        numElementsPerCell = cellfun(@numel, cellArray);
        flatCellArray = [cellArray{:}];
    else
        numElementsPerCell = arrayfun(@numel, cellArray);
        flatCellArray = [cellArray(:)];
        if ~isrow(flatCellArray); flatCellArray = flatCellArray'; end
    end

    if nargout <= 1
        clear numElementsPerCell
    end
end
