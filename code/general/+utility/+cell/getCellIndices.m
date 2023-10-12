function varargout = getCellIndices(cellArray)
% GETCELLINDICES determines a vector of cell indices for each object in a cell array.
%
%   cellIndices = GETCELLINDICES(cellArray) takes a 2D cell array as input, and
%   returns a vector of cell indices that corresponds to the cell each object
%   belongs to. The length of the output vector is equal to the total number
%   of objects across all cells.
%
%   Example:
%
%       cellArray = {[1, 2], [3, 4, 5], [], [6]};
%       cellIndices = getCellIndices(cellArray)
%
%   Output:
%       cellIndices = [1, 1, 2, 2, 2, 4]
%
%   In this example, the first two elements belong to the first cell, the next
%   three elements belong to the second cell, and the last element belongs to
%   the fourth cell.

if ~isa(cellArray, 'cell')
    cellArray = num2cell(cellArray);
end

% Initialize an empty vector to store cell indices
cellIndices = [];

cellArraySize = size(cellArray);
cellArrayFlat = cellArray(:);

% Loop through each cell
for i = 1:numel(cellArray)
    % Get the current cell
    thisCell = cellArrayFlat{i};
    
    % Assign the cell index to each element in the cell
    cellIndices = [cellIndices, ones(1, length(thisCell)) * i]; %#ok<AGROW> 
end

if nargout == 1
    varargout = {cellIndices};
else
    assert( nargout == ndims(cellArray), ['Number of outputs should match the ' ...
        'number of dimensions of the cell array'] )
    varargout = cell(1,nargout);
    [varargout{1:nargout}] = ind2sub(cellArraySize, cellIndices);
end
