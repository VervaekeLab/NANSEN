function [fileNameExpression, fileType, isConverted] = convertFilePatternToWildcard(dsmPattern, sessionTokens)
%convertFilePatternToWildcard Convert a file pattern regex to a NANSEN file name expression
%
%   Syntax:
%       [fileNameExpression, fileType, isConverted] = ...
%           convertFilePatternToWildcard(dsmPattern, sessionTokens)
%
%   A Dataset Structure Model file pattern is a regular expression that may
%   contain {token} references to an entity's metadata. NANSEN's
%   FileNameExpression is a wildcard pattern anchored with ^ and $, applied
%   in the session folder. NANSEN already restricts a virtual session
%   folder to the files that contain the session id, so tokens naming the
%   session's identity become *:
%
%       ^{recording_id}\.ABF$   ->   ^*.ABF$   with file type .ABF
%
%   Escaped punctuation becomes literal and .* becomes *. Any other regex
%   construct, or a token that does not name the session identity, has no
%   wildcard equivalent; isConverted is then false.
%
%   Input arguments:
%       dsmPattern    - The file pattern from the Dataset Structure Model.
%       sessionTokens - Names of the metadata fields that identify a session.

    arguments
        dsmPattern (1,1) string
        sessionTokens (1,:) string
    end

    fileNameExpression = "";
    fileType = "";
    isConverted = false;

    extension = regexp(dsmPattern, "\\\.([A-Za-z0-9]+)\$$", "tokens", "once");
    if ~isempty(extension)
        fileType = "." + extension{1};
    end

    tokens = regexp(dsmPattern, "\{([A-Za-z_][A-Za-z0-9_]*)\}", "tokens");
    pattern = dsmPattern;
    for i = 1:numel(tokens)
        if ~ismember(tokens{i}{1}, sessionTokens)
            return
        end
        pattern = replace(pattern, "{" + tokens{i}{1} + "}", "*");
    end

    pattern = char(pattern);
    wildcard = '';
    i = 1;
    while i <= numel(pattern)
        c = pattern(i);
        if c == '\'
            if i == numel(pattern) || isstrprop(pattern(i+1), 'alphanum')
                return % \d, \w and the like have no wildcard equivalent
            end
            wildcard(end+1) = pattern(i+1); %#ok<AGROW>
            i = i + 2;
        elseif c == '.' && i < numel(pattern) && pattern(i+1) == '*'
            wildcard(end+1) = '*'; %#ok<AGROW>
            i = i + 2;
        elseif c == '*' || (c == '^' && i == 1) || (c == '$' && i == numel(pattern)) ...
                || ~any(c == '.[](){}+?|^$')
            wildcard(end+1) = c; %#ok<AGROW>
            i = i + 1;
        else
            return
        end
    end

    fileNameExpression = string(wildcard);
    isConverted = true;
end
