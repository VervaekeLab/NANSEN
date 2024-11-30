function [S, value] = popfield(S, fieldName, warnIfMissing)
    % Todo: Support array of fields
    % Todo: Support struct arrays
    if nargin < 3; warnIfMissing = true; end
    value = [];
        
    if isfield(S, fieldName)
        value = S.(fieldName);
        S = rmfield(S, fieldName);
    else
        if warnIfMissing
            warning('Field ''%s'' not present in struct', fieldName)
        end
    end

    if nargout == 1
        clear value
    end
end
