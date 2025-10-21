function arrayOut = insertIntoArray(arrayOriginal, arrayToInsert, insertIndices, insertDimension)
% insertIntoArray - Insert slices of arrayToInsert into arrayOriginal along a given dimension.
%
%   Stack arrays and then reindex the combined data to yield an array where
%   sub arrays are inserted into the original array.
%
% Syntax:
%   arrayOut = utility.insertIntoArray(arrayOriginal, arrayToInsert, insertIndices, insertDimension)
%
% Input Arguments:
%  - arrayOriginal (any) - An array
%  - arrayToInsert (any) - An array to insert
%  - insertIndices (integer) - Indices / locations where to insert array slices 
%    along insertDimension
%  - insertDimension (integer) - Which dimension to perform insertions
%
% Requirements:
%     - arrayOriginal and arrayToInsert must have identical sizes in all
%       non-insert dimensions.
%     - numel(insertIndices) == size(arrayToInsert, insertDimension)
%     - insertIndices must be unique positive integers within
%       1 : size(arrayOriginal, insertDimension) + size(arrayToInsert, insertDimension)
%
% Example:
%       A = reshape(1:12, 4, 3);             % 4x3
%       B = [100 101 102; 200 201 202];      % 2x3
%       C = utility.insertIntoArray(A, B, [2 4], 1); % Insert rows 2 and 4
%
%       A =
%   
%           1     5     9
%           2     6    10
%           3     7    11
%           4     8    12
%       B =
%   
%         100   101   102
%         200   201   202
%       C =
% 
%           1     5     9
%         100   101   102
%           2     6    10
%         200   201   202
%           3     7    11
%           4     8    12

    arguments
        arrayOriginal
        arrayToInsert
        insertIndices (:,1) {mustBeInteger, mustBePositive}
        insertDimension (1,1) {mustBeInteger, mustBePositive} = 1 % Default is to insert along 1st dimension
    end

    % ---------------------------------------------------------------------
    % Validate inputs
    % ---------------------------------------------------------------------

    % Normalize dimensionality and size
    numberOfDimensionsInput  = ndims(arrayOriginal);
    numberOfDimensionsInsert = ndims(arrayToInsert);
    numberOfDimensions       = max(numberOfDimensionsInput, numberOfDimensionsInsert);

    if insertDimension > numberOfDimensions
        error('NANSEN:InsertArray:InvalidInsertDimension', ...
            'insertDimension exceeds the number of dimensions of the inputs.');
    end
    
    sizeInput  = size(arrayOriginal);
    sizeInsert = size(arrayToInsert);

    % Pad sizes so both arrays have the same number of dimensions
    sizeInput(end+1:numberOfDimensions)  = 1;
    sizeInsert(end+1:numberOfDimensions) = 1;

    % Validate shape compatibility
    allOtherDimensions = setdiff(1:numberOfDimensions, insertDimension);
    if ~isequal(sizeInput(allOtherDimensions), sizeInsert(allOtherDimensions))
        error('NANSEN:InsertArray:IncompatibleArraySizes', ...
            ['arrayOriginal and arrayToInsert must have identical sizes ' ...
             'in all non-insert dimensions. Got size(arrayOriginal) = %s, ' ...
             'size(arrayToInsert) = %s.'], mat2str(sizeInput), mat2str(sizeInsert));
    end

    % Validate insertion indices
    numberOfSlicesInput  = sizeInput(insertDimension);
    numberOfSlicesInsert = sizeInsert(insertDimension);
    totalNumberOfSlices  = numberOfSlicesInput + numberOfSlicesInsert;

    if numel(insertIndices) ~= numberOfSlicesInsert
        error('NANSEN:InsertArray:InvalidInsertionIndices', ...
            'numel(insertIndices) (%d) must equal size(arrayToInsert, insertDimension) (%d).', ...
             numel(insertIndices), numberOfSlicesInsert);
    end
    if numel(unique(insertIndices)) ~= numel(insertIndices) || ...
       any(insertIndices < 1) || any(insertIndices > totalNumberOfSlices)
        error('NANSEN:InsertArray:NonUniqueInsertionIndices', ...
            'insertIndices must be unique integers within 1:%d.', totalNumberOfSlices);
    end

    % ---------------------------------------------------------------------
    % Permute so that the insertion dimension is first
    % ---------------------------------------------------------------------
    dimensionOrder = [insertDimension, allOtherDimensions];
    arrayOriginalPermuted  = permute(arrayOriginal, dimensionOrder);
    arrayInsertPermuted = permute(arrayToInsert, dimensionOrder);

    % Collapse remaining dimensions
    arrayOriginal2D  = reshape(arrayOriginalPermuted,  numberOfSlicesInput,  []);
    arrayInsert2D = reshape(arrayInsertPermuted, numberOfSlicesInsert, []);

    % ---------------------------------------------------------------------
    % Stack and reorder (no preallocation)
    % ---------------------------------------------------------------------
    stackedArrays = [arrayOriginal2D; arrayInsert2D];  % combine once

    % Build mapping from output positions to source rows
    sourceRowIndices = zeros(totalNumberOfSlices, 1);  % integer index vector only
    existingPositions = setdiff(1:totalNumberOfSlices, insertIndices(:).', 'stable');
    sourceRowIndices(existingPositions) = 1:numberOfSlicesInput;
    sourceRowIndices(insertIndices)     = numberOfSlicesInput + (1:numberOfSlicesInsert);

    % Reorder the stacked array rows into the desired output order
    arrayCombined2D = stackedArrays(sourceRowIndices, :);

    % ---------------------------------------------------------------------
    % Reshape back to the original dimensionality
    % ---------------------------------------------------------------------
    outputSize = sizeInput;
    outputSize(insertDimension) = totalNumberOfSlices;

    arrayCombinedND = reshape(arrayCombined2D, ...
                              [outputSize(insertDimension), outputSize(allOtherDimensions)]);

    arrayOut = ipermute(arrayCombinedND, dimensionOrder);
end
