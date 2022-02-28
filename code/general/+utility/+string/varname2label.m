function label = varname2label(varname)
% Convert a camelcase variable name to a label where each word starts with
% capital letter and is separated by a space.
%
%   label = varname2label(varname) insert space before capital letters and
%   make first letter capital
%
%   Example:
%   label = varname2label('helloWorld')
%   
%   label = 
%       'Hello World'

% Todo:
%   How to format names containing . ?

% If variable is passed, get the variable name:
if ~ischar(varname); varname = inputname(1); end

% varname = strrep(varname, '.', '-');

% Insert spaces
if issnakecase(varname)

    label = strrep(varname, '_', ' ');
    
    [strInd] = regexp(label, ' ');
    strInd = [0, strInd] + 1;
    
    for i = strInd
        label(i) = upper(label(i));
    end

elseif iscamelcase(varname)
    
    capLetterStrInd = regexp(varname, '[A-Z, 1-9]');

    for i = fliplr(capLetterStrInd)
        if i ~= 1 %Skip space before first letter if PascalCase
            varname = insertBefore(varname, i , ' ');
        end
    end
    
    % Look for dots and remove everything before...
    dotLetterPos = strfind(varname, '.');
    if ~isempty(dotLetterPos)
        varname = varname(dotLetterPos(end)+1:end);
    end

    varname(1) = upper(varname(1));
    label = varname;
    
else
    varname(1) = upper(varname(1));
    label = varname;
end




end

function isCamelCase = iscamelcase(varname)
    
    capLetterStrInd = regexp(varname, '[A-Z]');
    if any(capLetterStrInd > 1)
        isCamelCase = true;
    else
        isCamelCase = false;
    end
    
end


function isSnakeCase = issnakecase(varname)
    isSnakeCase = contains(varname, '_');
end




