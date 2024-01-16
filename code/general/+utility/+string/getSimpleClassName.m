function className = getSimpleClassName(className)
    
    if isa(className, 'cell')
        className = cellfun(@(c) utility.string.getSimpleClassName(c), ...
            className, 'UniformOutput', false);
    else
        className = strsplit(className, '.');
        className = className{end};
    end
end