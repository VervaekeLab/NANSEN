function [flagsOut, vararginCell] = splitvararginflags(vararginCell, flagsIn)        

    flagsOut = {};
    
    % Convert flags to name/value pairs
    hasFlag = @(c, name) ischar(c) && strcmp(c, name);

    for i = 1:numel(flagsIn)

        isFlag = cellfun(@(c) hasFlag(c, flagsIn{i}), vararginCell);
        if any(isFlag)
            flagsOut = [flagsOut, flagsIn{i}]; %#ok<AGROW> 
            vararginCell(isFlag) = [];
        end
    end
end