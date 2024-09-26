function arrayOut = insertIntoArray(arrayIn, arrayToInsert, ind, dim)

    % Currently only supports 2 dimension.
    if nargin < 4
        if numel(arrayIn) > 1 && iscolumn(arrayIn)
            dim = 1;
        elseif numel(arrayIn) > 1 && isrow(arrayIn)
            dim = 2;
        elseif numel(arrayToInsert) > 1 && iscolumn(arrayToInsert)
            dim = 1;
        elseif numel(arrayToInsert) > 1 && isrow(arrayToInsert)
            dim = 2;
        else
            dim = 1;
        end
    end
    
    if iscolumn(arrayIn) && ~isrow(arrayIn) && isrow(arrayToInsert) && ~iscolumn(arrayToInsert)
        arrayToInsert = arrayToInsert';
        warning('Dimensions of inputs are not matching')
    end
    
    if isrow(arrayIn) && ~iscolumn(arrayIn) && iscolumn(arrayToInsert) && ~isrow(arrayToInsert)
        arrayToInsert = arrayToInsert';
        warning('Dimensions of inputs are not matching')
    end
    
    nDim = ndims(arrayIn);
    if nDim > 3; error('Not implemented for nd-arrays'); end
    
    [nRowsA, nColsA, nPlanesA] = size(arrayIn);
    [nRowsB, nColsB, nPlanesB] = size(arrayToInsert);
    
    if dim == 1
        arrayOut(nRowsA+nRowsB, nColsA) = arrayIn(1); % Preallocate
        colInd = 1:nColsB;
        rowIndNew = ind;
        rowIndOld = setdiff(1:nRowsA+nRowsB, rowIndNew);
        arrayOut(rowIndOld, colInd) = arrayIn;
        arrayOut(rowIndNew, colInd) = arrayToInsert;
    elseif dim == 2
        arrayOut(nRowsA, nColsA+nColsB) = arrayIn(1); % Preallocate
        rowInd = 1:nRowsB;
        colIndNew = ind;
        colIndOld = setdiff(1:nColsA+nColsB, colIndNew);
        arrayOut(rowInd, colIndOld) = arrayIn;
        arrayOut(rowInd, colIndNew) = arrayToInsert;
    elseif dim == 3
        arrayOut(nRowsA, nColsA, nPlanesA+nPlanesB) = arrayIn(1); % Preallocate
        rowInd = 1:nRowsA;
        colInd = 1:nColsA;
        planeIndNew = ind;
        planeIndOld = setdiff(1:nPlanesA+nPlanesB, planeIndNew);
        arrayOut(rowInd, colInd, planeIndOld) = arrayIn;
        arrayOut(rowInd, colInd, planeIndNew) = arrayToInsert;
    end
    
    return
    
    % Need to test this:
    % for ndimensional: I wonder what the real matlab function for this is.....
    numDim = ndims(arrayIn);
    
    % Permute so that dimension to work on is the first one.
    dimOrder = [dim, setdiff(1:numDim, dim)];
    
    arrayIn = permute(arrayIn, dimOrder);
    arrayToInsert = permute(arrayToInsert, dimOrder);
    
    szA = size(arrayIn);
    szB = size(arrayToInsert);
    
    % Reshape so that the rest of the dimensions are collected in the second
    % dimension.
    arrayIn = reshape(arrayIn, szA(1), []);
    arrayToInsert = reshape(arrayToInsert, szB(1), []);
    
    % Preallocate array out.
    arrayOut( szA(1)+szB(1), prod(szA(2:end)) ) = arrayIn(1);
    
    % Add data along the row (1st) dimension
    indNew = ind;
    indOld = setdiff(1:szA(1)+szB(1), indNew);
    
    arrayOut(indOld, :) = arrayIn;
    arrayOut(indNew, :) = arrayToInsert;
    
    % Reshape and inverse permute result to match the dimensions of the
    % input.
    arrayOut = reshape(arrayOut2, [szA(1)+szB(1), szA(2:end)] );
    arrayOut = ipermute(arrayOut, dimOrder);
    
end
