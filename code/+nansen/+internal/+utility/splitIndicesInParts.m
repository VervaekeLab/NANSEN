function partitionedIndices = splitIndicesInParts(indices, numParts)
%splitIndicesInParts Split a vector of indices into subparts.
%
%   partitionedIndices = splitIndicesInParts(indices, numParts) returns a
%   cell array of partitioned indices. The size of cell array should
%   be 1 x numParts, but the number of parts may be smaller than the
%   provided value if it is not possible to divide into the specified
%   number.

    % Count frames per part and number of parts
    numIndices = numel(indices);
    numFramesPerPart = ceil(numIndices / numParts);
    numParts = numFramesPerPart * numParts;
    
    % Adjust number of parts in case some would be empty
    numParts = sum( (1:numParts) * numFramesPerPart < numIndices ) + 1;
    
    % Split into cell array
    keep = 1:numFramesPerPart*(numParts-1);
    partitionedIndices = mat2cell(indices(keep), 1, repmat(numFramesPerPart, 1, numParts-1));

    % Add the last part (which might not be same size as other parts)
    if ~isempty(indices(keep(end)+1:end))
        partitionedIndices{end+1} = indices(keep(end)+1:end);
    end
end
