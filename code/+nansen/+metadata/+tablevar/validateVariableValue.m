function [isValid, newValue] = validateVariableValue(defaultValue, newValue)
% validateVariableValue - Validate that a new value is type-compatible with a default value
%
%   [isValid, newValue] = validateVariableValue(defaultValue, newValue)
%
%   Checks whether newValue is type-compatible with defaultValue, using the
%   type of defaultValue to determine what is acceptable. string values are
%   converted to char, since the MetaTable does not support the string type.
%   For unassigned character placeholders (e.g. {'N/A'}, {'<undefined>'}),
%   a scalar cell containing a char is also accepted and unwrapped.
%
%   Supported default types: char (unassigned placeholder), numeric,
%   logical, struct, categorical, datetime.
%
%   Input Arguments:
%       defaultValue - Reference value defining the expected type
%       newValue     - Value to validate
%
%   Output Arguments:
%       isValid  - true if newValue is type-compatible with defaultValue
%       newValue - Validated value, with any type conversions applied

    arguments
        defaultValue
        newValue
    end

    % String values need to be converted to char as the table
    % currently does not support string type.
    if isa(newValue, 'string')
        newValue = char(newValue);
    end

    isValid = false;

    validExactMatchTypes = {'logical', 'struct', 'categorical', 'datetime'};

    if nansen.metadata.utility.isUnassignedCharValue(defaultValue) % Character vectors should be in a scalar cell
        if iscell(newValue) && isscalar(newValue) && ischar(newValue{1})
            newValue = newValue{1};
            isValid = true;
        elseif isa(newValue, 'char')
            isValid = true;
        end
    elseif isnumeric(defaultValue)
        isValid = isnumeric(newValue);
    elseif ismember(class(defaultValue), validExactMatchTypes)
        isValid = isa(newValue, class(defaultValue));
    end
end
