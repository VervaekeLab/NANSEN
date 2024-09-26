function value = getnvparametervalue(cellOfNvPairs, name)
%getnvparametervalue Get value of parameter with given name
%
%   value = getnvparametervalue(name)

% If varargin was directly passed from another function's inputs to this
% function's input, the cell array must be unpacked.
if numel(cellOfNvPairs) == 1 && isa(cellOfNvPairs{1}, 'cell')
    cellOfNvPairs = cellOfNvPairs{1};
end

names = cellOfNvPairs(1:2:end);

isMatched = find( strcmp(names, name) );

if isempty(isMatched)
    value = [];
elseif numel(isMatched) == 1
    value = cellOfNvPairs{isMatched*2};
else
    error('Multiple matches found for parameter %s', name)
end
end
