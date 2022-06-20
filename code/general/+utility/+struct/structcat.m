function structArray = structcat(dim, varargin)
%structcat Concatenate a list of structs
%
%   structArray = structcat(dim, s1, s2, ..., sN) concatenates a list of
%   structs along the specified dimension. If structs does not all have the
%   same fields, fields are added as needed and initialized with an empty
%   array.

    isStruct = cellfun(@(c) isstruct(c), varargin);
    structCellArray = varargin(isStruct);
    
    numStructs = numel(structCellArray);
    
    % Determine unique fieldnames across all structs
    fieldNames = cell(numStructs, 1);
    for i = 1:numStructs
        fieldNames{i} = fieldnames(structCellArray{i});
    end
    
    uniqueFields = unique(cat(1, fieldNames{:}));

    % Add missing fields for structs with missing fields
    for i = 1:numStructs
        hasFields = isfield(structCellArray{i}, uniqueFields);
        if any(~hasFields)
            missingFields = uniqueFields(~hasFields);
            for j = 1:numel(missingFields)
                structCellArray{i}.(missingFields{j}) = [];
            end
        end
    end
    
    % Todo: Do we need to order fields?
    structArray = cat(dim, structCellArray{:});
end