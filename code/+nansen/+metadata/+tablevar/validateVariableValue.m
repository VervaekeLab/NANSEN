function [isValid, newValue] = validateVariableValue(defaultValue, newValue)
% validateVariableValue - Validate a table variable value
    
    arguments
        defaultValue 
        newValue 
    end

    % Todo: 
    % Maintain a list of valid types and if the value is
    % valid, just check that the defaultValue and the newValue is
    % of same class instead of having an "if check" for each type

    % String values need to be converted to char as the table
    % currently does not support string type.
    if isa(newValue, 'string')
        newValue = char(newValue); 
    end

    isValid = false;

    if isequal(defaultValue, {'N/A'}) || isequal(defaultValue, {'<undefined>'}) % Character vectors should be in a scalar cell
        if iscell(newValue) && numel(newValue)==1 && ischar(newValue{1})
            newValue = newValue{1};
            isValid = true;
        elseif isa(newValue, 'char')
            isValid = true;
        end

    elseif isa(defaultValue, 'double')
        isValid = isnumeric(newValue);

    elseif isa(defaultValue, 'logical')
        isValid = islogical(newValue);
        
    elseif isa(defaultValue, 'struct')
        isValid = isstruct(newValue);

    elseif isa(defaultValue, 'categorical')
        isValid = isa(newValue, 'categorical');

    else
        % Invalid;
    end
end
