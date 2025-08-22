function strValue = getStringRepresentationForValue(value)
% getStringRepresentationForValue - Get a value formatted as a string

    import nansen.internal.templating.getStringRepresentationForValue
    
    if isa(value, 'char') || isa(value, 'string')
        strValue = value;
    elseif isnumeric(value)
        strValue = num2str(value);
    elseif islogical(value)
        if value
            strValue = 'true';
        else
            strValue = 'false';
        end
    elseif isa(value, 'cell')
        value = cellfun(@(v) getStringRepresentationForValue(v), value, 'uni', 0);
        strValue = cellArrayToTextString(value);
    else
        error('Value of type %s is not supported', class(value));
    end
end

function textStr = cellArrayToTextString(cellArray)
%cellArrayToTextString Create a text string representing the cell array
    cellOfPaddedStrings = cellfun(@(c) c, cellArray, 'UniformOutput', false);
    textStr = sprintf('{%s}', strjoin(cellOfPaddedStrings, ', '));
end
