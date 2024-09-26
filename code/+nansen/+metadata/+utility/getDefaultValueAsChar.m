function defaultValue = getDefaultValueAsChar(dataType)
%getDefaultValueAsChar Get default value of data type as a char value
    
    switch dataType
        case 'logical (true)'
            defaultValue = 'true';
        case {'logical', 'logical (false)'}
            defaultValue = 'false';
        case 'numeric'
            defaultValue = 'nan';
        case {'char', 'text'}
            defaultValue = '{''N/A''}';
        case 'categorical'
            defaultValue = '{''N/A''}';
        case 'struct'
            defaultValue = '''struct.empty''';
        otherwise
            defaultValue = '{''N/A''}';
    end
end
