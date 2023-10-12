function S = renamefield(S, oldNames, newNames)
%renamefield Rename field(s) in a struct
%
%   Syntax:
%       S = renamefield(S, oldNames, newNames)
%
%   Input arguments:
%       S - a struct
%
%       oldNames - character, cell array of character vectors or a string
%           array
%
%       newNames - character, cell array of character vectors or a string
%           array. (Must match type and size of oldNames)
%
%   Output arguments:
%       S


    assert( strcmp( class(oldNames), class(newNames) ), ...
        'Old names and new names must be same data type')

    if ~isa(oldNames, 'cell') && isa(oldNames, 'char')
        oldNames = {oldNames};
        newNames = {newNames};
    end
    
    fieldOrder = fieldnames(S);
    
    % Find indices of oldNames in the fieldOrder cell array
    [~, ~, replacementIdx] = intersect(oldNames, fieldOrder, 'stable');

    % Add values for new names
    for i = 1:numel(oldNames)
        S.(newNames{i}) = S.(oldNames{i});
    end

    S = rmfield(S, oldNames);
    
    fieldOrder(replacementIdx) = newNames;
    S = orderfields(S, fieldOrder);
end