function defaultValue = getDefaultValue(dataType)
%getDefaultValue Get default value of data type
    
    switch dataType
        case 'logical (true)'
            defaultValue = true;
        case {'logical', 'logical (false)'}
            defaultValue = false;
        case 'numeric'
            defaultValue = nan;
        case 'text'
            defaultValue = {'N/A'};
    end
end
