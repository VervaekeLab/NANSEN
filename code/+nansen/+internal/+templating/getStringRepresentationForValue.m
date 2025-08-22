function strValue = getStringRepresentationForValue(value, wrapString)
% getStringRepresentationForValue - Get a value formatted as a string

    import nansen.internal.templating.getStringRepresentationForValue

    if nargin < 2 || isempty(wrapString); wrapString = false; end
    
    if isa(value, 'char') || isa(value, 'string')
        if wrapString
            strValue = sprintf('''%s''', value);
        else
            strValue = value;
        end
    elseif isnumeric(value)
        strValue = num2str(value);
    elseif islogical(value)
        if value
            strValue = 'true';
        else
            strValue = 'false';
        end
    elseif isa(value, 'cell')
        value = cellfun(@(v) getStringRepresentationForValue(v, true), value, 'uni', 0);
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
