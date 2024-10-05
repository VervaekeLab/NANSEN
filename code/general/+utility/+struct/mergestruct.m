function mergedStruct = mergestruct(varargin)
%MERGESTRUCT Merge two or more structs into one struct

    isStruct = cellfun(@(c) isstruct(c), varargin);
    structCellArray = varargin(isStruct);
    
    mergedStruct = structCellArray{1};
    numElements = numel(mergedStruct);
    
    structLenghths = cellfun(@(c) numel(c), structCellArray);
    assert(all(structLenghths==numElements), ...
        'Structs must have the same number or elements for merging')
    
    n = numElements;
    for i = 2:numel(structCellArray)
        
        tempStruct = structCellArray{i};
        tempFields = fieldnames(tempStruct);
                
        for j = 1:numel(tempFields)
            if isfield(mergedStruct, tempFields{j})
                warning('Field already exists, skipping %s', tempFields{j})
            else
                [mergedStruct(1:n).(tempFields{j})] = tempStruct.((tempFields{j}));
            end
        end
    end
end
