function L = multidir(name)
%multidir Same as builtin dir, but name can be a cell array
%
%   L = multidir(name)

    if isa(name, 'cell')
        L = cellfun(@(iName) dir(iName), name, 'uni', 0);
        L = cat(1, L{:});
    else
        L = dir(name);
    end
    
    L = L(~strncmp({L.name}, '.', 1));
end