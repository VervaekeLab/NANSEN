function opt = parsenvpairs(def, vfun, varargin)
%parsenvpairs Parse name-value pairs
%
%   opt = parsenvpairs(def, vfun, varargin)
%       def is a struct of default name value pairs.
%       vfun is a struct of function handles to validate each parameter.
%       This input is optional, and can be left empty ([])
%       varargin is a cell of the name-value pairs. If some name-value
%       pairs are not given, default values are used.

if isempty(varargin); opt = def; return; end

% If varargin was directly passed from another function's inputs to this 
% function's input, the cell array must be unpacked.
if numel(varargin) == 1 && isa(varargin{1}, 'cell')
    varargin = varargin{1};
end

names = fieldnames(def);

% Remove config fields
isconfigfield = @(str) strcmp(str(end), '_') && any(strcmp(str(1:end-1), names));
isConfigFields = cellfun(@(str) isconfigfield(str), names);

names(isConfigFields) = [];

nvPairs = {};

% If varargin is a struct (could happen if an opt struct is passed instead
% of name, value pairs.
if ~isempty(varargin) && (isa(varargin{1}, 'struct') || isa(varargin{end}, 'struct'))
    
    if isa(varargin{1}, 'struct')
        ind = 1;
    else
        ind = numel(varargin);
    end
    
    fields = fieldnames(varargin{ind})';
    
    %In this case, only use fields which are also part of def, so that user
    % is more free in passing the opts even if it does not contain relevant 
    % fields.
    fields = intersect(fields, names)';
    values = cellfun(@(name) varargin{ind}.(name), fields, 'uni', 0 );
    nvPairs = reshape(vertcat(fields, values), 1, numel(fields)*2);

    varargin(ind) = [];
    
end


% Ignore name, value pairs that are not included in def..
if ~isempty(varargin) && isa(varargin{1}, 'char')
    
    namesIn = varargin(1:2:end);
    matchInd = find(contains(namesIn, names) )*2 - 1; % Correct for selecting every other name in line above...

    if isempty(matchInd)
        % do nothing
    else
        matchInd = [matchInd; matchInd+1];
        matchInd = reshape(matchInd, 1, []);
        nvPairs = [nvPairs, varargin(matchInd)];
    end
    
end


if isempty(vfun)
    vfun = cell2struct(cellfun(@(fn) @(x) ~isempty(x), names, 'uni', 0), names);
elseif isequal(vfun, 1)
    vfun = cell2struct(cellfun(@(fn) @(x) true, names, 'uni', 0), names);
end


% % % % Set a default validation scheme (not empty) for each parameter.
% % % vfun = cell2struct(cellfun(@(fn) @(x) ~isempty(x), names, 'uni', 0), names);
% % % vfun.method = @(x) any(validatestring(x, {'rigid', 'nonrigid'}));
% % % vfun.a = @(x) isnumeric(x) && isscalar(x) && (x > 0);


parserObj = inputParser;
parserObj.FunctionName = 'Input parser for Name, Value pairs';

for i = 1:numel(names)
    if ~isfield(vfun, names{i})
        parserObj.addParameter(names{i}, def.(names{i}))
    else
        parserObj.addParameter(names{i}, def.(names{i}), vfun.(names{i}));
    end
end

parserObj.parse(nvPairs{:});
opt = parserObj.Results;


end