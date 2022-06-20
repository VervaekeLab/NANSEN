function label = varname2label(varname, includePackageName)
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

if nargin < 2
    includePackageName = false;
end

% If variable is passed, get the variable name:
if ~ischar(varname); varname = inputname(1); end

% Special case if varname is a package name
if contains(varname, '.') 
    splitVarname = strsplit(varname, '.');
    if includePackageName
        splitVarname = cellfun(@(c) utility.string.varname2label(c), splitVarname, 'uni', 0);
        label = strjoin(splitVarname, '-');
        return
    else
        varname = splitVarname{end}; % select last item of package name
    end
end


% Insert spaces
if issnakecase(varname)

    label = strrep(varname, '_', ' ');
    
    [strInd] = regexp(label, ' ');
    strInd = [0, strInd] + 1;
    
    for i = strInd
        label(i) = upper(label(i));
    end
    
elseif iscapitalized(varname)
    label = varname;

elseif iscamelcase(varname)
    
    % Insert space after a uppercase letter preceded by a lowercase letter
    % OR before a uppercase letter succeded by a lowercase letter
    % ie aB = 'a B' and AAb = A Ab
    
    expression = '((?<=[a-z])[A-Z])|([A-Z](?=[a-z]))';
    varname = regexprep(varname, expression, ' $0');
    
% % %     capLetterStrInd = regexp(varname, '[A-Z, 1-9]');
% % %     prevI = [];
% % %     for i = fliplr(capLetterStrInd)
% % %         if i ~= 1 %Skip space before first letter if PascalCase
% % %             varname = insertBefore(varname, i , ' ');
% % %         end
% % %         prevI = i;
% % %     end

    varname(1) = upper(varname(1));
    label = varname;
    
else
    varname(1) = upper(varname(1));
    label = varname;
end

label = strtrim(label);


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

function isCapitalized = iscapitalized(varname)
    isCapitalized = strcmp(varname, upper(varname)); %#ok<STCI>
end

