function [fileNameExpression, fileType, isConverted] = convertFilePatternToWildcard(dsmPattern, sessionTokens)
%convertFilePatternToWildcard Convert a file pattern regex to a NANSEN file name expression
%
%   Syntax:
%       [fileNameExpression, fileType, isConverted] = ...
%           convertFilePatternToWildcard(dsmPattern, sessionTokens)
%
%   A Dataset Structure Model file pattern is a regular expression that may
%   contain {token} references to an entity's metadata. NANSEN's
%   FileNameExpression is a wildcard pattern, anchored with ^ and $,
%   applied in the session folder. NANSEN already restricts a virtual
%   session folder to the files that contain the session id, so tokens
%   naming the session's identity become *:
%
%       ^{recording_id}\.ABF$   ->   ^*.ABF$   with file type .ABF
%
%   Escaped punctuation becomes literal and .* becomes *. Any other regex
%   construct, or a token that does not name the session identity, has no
%   wildcard equivalent; isConverted is then false. This includes a * that
%   follows a literal or a token: in a regex it repeats what precedes it,
%   so ^ab*c\.txt$ matches ac.txt and abbc.txt but not abxc.txt, which
%   the wildcard ab*c.txt would match.
%
%   A file pattern is searched for anywhere in the file name. A pattern
%   without a leading ^ needs nothing added, as NANSEN puts * before an
%   expression without ^. A pattern without a trailing $ gets *$, so that
%   the expression matches names that continue after the pattern:
%
%       ^{session_id}_raw   ->   ^*_raw*$
%       \.tif               ->   .tif*$
%
%   Without the $, VariableModel.lookForFile would end the expression with
%   * and the variable's file type, which for a variable without a file
%   type is ., and so find no file.
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

    pattern = char(dsmPattern);
    wildcard = '';
    isAnchoredAtEnd = false;
    i = 1;
    while i <= numel(pattern)
        c = pattern(i);
        if c == '{'
            token = regexp(pattern(i:end), '^\{([A-Za-z_][A-Za-z0-9_]*)\}', 'tokens', 'once');
            if isempty(token) || ~ismember(token{1}, sessionTokens)
                return % a quantifier, or a token that does not name the session identity
            end
            wildcard = appendAnyText(wildcard);
            i = i + numel(token{1}) + 2;
        elseif c == '\'
            if i == numel(pattern) || isstrprop(pattern(i+1), 'alphanum')
                return % \d, \w and the like have no wildcard equivalent
            end
            wildcard(end+1) = pattern(i+1); %#ok<AGROW>
            i = i + 2;
        elseif c == '.' && i < numel(pattern) && pattern(i+1) == '*'
            wildcard = appendAnyText(wildcard);
            i = i + 2;
        elseif (c == '^' && i == 1) || (c == '$' && i == numel(pattern)) || ~any(c == '.[](){}*+?|^$')
            isAnchoredAtEnd = c == '$' && i == numel(pattern);
            wildcard(end+1) = c; %#ok<AGROW>
            i = i + 1;
        else
            return % a quantifier, a group, a class, alternation or an inner anchor
        end
    end

    if ~isAnchoredAtEnd
        wildcard = [appendAnyText(wildcard), '$'];
    end

    fileNameExpression = string(wildcard);
    isConverted = true;
end

function wildcard = appendAnyText(wildcard)
%appendAnyText Append *, unless the wildcard already ends with one
    arguments
        wildcard char
    end

    if isempty(wildcard) || wildcard(end) ~= '*'
        wildcard(end+1) = '*';
    end
end
