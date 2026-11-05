function tf = isWrapped(value)
% isWrapped - Check if a cell value is wrapped in a nested cell array?
    tf = iscell(value) && isscalar(value) && iscell(value{1});
end
