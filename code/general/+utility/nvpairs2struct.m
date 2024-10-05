function S = nvpairs2struct(varargin)
%nvpairs2struct Convert cell array of name-value pairs to struct
%
%   opt = parsenvpairs(def, vfun, varargin)
%       def is a struct of default name value pairs.
%       vfun is a struct of function handles to validate each parameter.
%       This input is optional, and can be left empty ([])
%       varargin is a cell of the name-value pairs. If some name-value
%       pairs are not given, default values are used.

if isempty(varargin); S = struct(); return; end
if numel(varargin) == 1 && isempty(varargin{1}); S = struct; return; end

% If varargin was directly passed from another function's inputs to this
% function's input, the cell array must be unpacked.
if numel(varargin) == 1 && isa(varargin{1}, 'cell')
    varargin = varargin{1};
end

names = varargin(1:2:end);
values = varargin(2:2:end);

S = cell2struct(values, names, 2);
end
