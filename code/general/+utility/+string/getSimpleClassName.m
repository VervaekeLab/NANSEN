function className = getSimpleClassName(className)
    
    if isa(className, 'cell')
        className = cellfun(@(c) utility.string.getSimpleClassName(c), ...
            className, 'UniformOutput', false);
    else
        if ~isempty(className)
            className = strsplit(className, '.');
            className = className{end};
        end
    end
end