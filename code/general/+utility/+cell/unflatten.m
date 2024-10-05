function unflatCellArray = unflatten(flatCellArray, numElementsPerCell)
%UNFLATTEN Unflatten a previously flattened cell array
%
%   unflatCellArray = unflatten(flatCellArray, numElementsPerCell)
%
%   See also utility.cell.flatten

    cellArrayShape = size(numElementsPerCell);

    unflatCellArray = mat2cell(flatCellArray, 1, numElementsPerCell(:) );
    unflatCellArray = reshape(unflatCellArray, cellArrayShape);
end
