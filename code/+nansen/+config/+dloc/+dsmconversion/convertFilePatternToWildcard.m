function [fileNameExpression, fileType, isConverted, isApproximate] = ...
    convertFilePatternToWildcard(dsmPattern, identityTokens)
%convertFilePatternToWildcard Convert a file pattern regex to a NANSEN file name expression
%
%   Syntax:
%       [fileNameExpression, fileType, isConverted, isApproximate] = ...
%           convertFilePatternToWildcard(dsmPattern, identityTokens)
%
%   A Dataset Structure Model file pattern is a regular expression that may
%   contain {token} references to an entity's metadata. NANSEN's
%   FileNameExpression is a wildcard pattern anchored with ^ and $, which
%   NANSEN passes to dir, so * is its only wildcard. NANSEN already
%   restricts a virtual session folder to the files that contain the
%   session id, and the files of a session belong to one subject, so tokens
%   naming the identity of the session or of an ancestor become *:
%
%       ^{recording_id}\.ABF$   ->   ^*.ABF$   with file type .ABF
%
%   An extension of several parts gives a file type of several parts:
%   \.nii\.gz$ has the file type .nii.gz. Each part but the last starts
%   with a letter, so that a version number before the extension is not
%   taken for part of it: v1\.2\.txt$ has the file type .txt, and \.7z$
%   has the file type .7z.
%
%   Escaped punctuation becomes literal and .* becomes *. A character class
%   (\d, \w, \s, [...]) or a . with its quantifier also becomes *. The
%   wildcard then matches more names than the pattern, and isApproximate
%   is true:
%
%       ^TT\d+\.ntt$   ->   ^TT*.ntt$
%
%   An approximation that keeps no literal text but dots would match every
%   file in the folder (^{session_id}\.\d$ would become ^*.*$), so it is
%   not converted. Alternation, groups, quantified literals and tokens that
%   name other fields have no wildcard equivalent either; isConverted is
%   then false. This includes a * that follows a literal or a token: in a
%   regex it repeats what precedes it, so ^ab*c\.txt$ matches ac.txt and
%   abbc.txt but not abxc.txt, which the wildcard ab*c.txt would match.
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
%       dsmPattern     - The file pattern from the Dataset Structure Model.
%       identityTokens - Names of the metadata fields that identify the
%                        session or one of its ancestors.

    arguments
        dsmPattern (1,1) string
        identityTokens (1,:) string
    end

    fileNameExpression = "";
    fileType = "";
    isConverted = false;
    isApproximate = false;

    % One or more parts, of which all but the last start with a letter
    extension = regexp(dsmPattern, "((?:\\\.[A-Za-z][A-Za-z0-9]*)*\\\.[A-Za-z0-9]+)\$$", "tokens", "once");
    if ~isempty(extension)
        fileType = string(erase(extension{1}, "\"));
    end

    pattern = char(dsmPattern);
    wildcard = '';
    isAnchoredAtEnd = false;
    i = 1;
    while i <= numel(pattern)
        c = pattern(i);
        if c == '{'
            token = regexp(pattern(i:end), '^\{([A-Za-z_][A-Za-z0-9_]*)\}', 'tokens', 'once');
            if isempty(token) || ~ismember(token{1}, identityTokens)
                return % a quantifier, or a token that names no identity field
            end
            wildcard = appendWildcard(wildcard);
            i = i + numel(token{1}) + 2;
        elseif c == '\'
            if i == numel(pattern)
                return
            end
            escaped = pattern(i+1);
            if any(escaped == 'dws')
                [wildcard, i] = appendAnyText(wildcard, pattern, i + 2);
                isApproximate = true;
            elseif isstrprop(escaped, 'alphanum')
                return % \b, \D and the like have no wildcard equivalent
            else
                wildcard(end+1) = escaped; %#ok<AGROW>
                i = i + 2;
            end
        elseif c == '['
            closing = find(pattern(i+1:end) == ']', 1);
            if isempty(closing)
                return
            end
            [wildcard, i] = appendAnyText(wildcard, pattern, i + closing + 1);
            isApproximate = true;
        elseif c == '.'
            % .* is any text, as * is; any other . is approximated
            isApproximate = isApproximate || i == numel(pattern) || pattern(i+1) ~= '*';
            [wildcard, i] = appendAnyText(wildcard, pattern, i + 1);
        elseif (c == '^' && i == 1) || (c == '$' && i == numel(pattern)) || ~any(c == '[](){}*+?|^$')
            isAnchoredAtEnd = c == '$' && i == numel(pattern);
            wildcard(end+1) = c; %#ok<AGROW>
            i = i + 1;
        else
            return % a quantifier of a literal or a token, a group, alternation or an inner anchor
        end
    end

    if isApproximate && all(ismember(wildcard, '^$*.'))
        isApproximate = false;
        return % the wildcard would match every file in the folder
    end

    if ~isAnchoredAtEnd
        wildcard = [appendWildcard(wildcard), '$'];
    end

    fileNameExpression = string(wildcard);
    isConverted = true;
end

function [wildcard, next] = appendAnyText(wildcard, pattern, next)
%appendAnyText Append * for one pattern element, skipping the quantifier that follows it
    if next <= numel(pattern)
        if any(pattern(next) == '*+?')
            next = next + 1;
        elseif pattern(next) == '{'
            closing = find(pattern(next+1:end) == '}', 1);
            if ~isempty(closing)
                next = next + closing + 1;
            end
        end
    end
    wildcard = appendWildcard(wildcard);
end

function wildcard = appendWildcard(wildcard)
%appendWildcard Append *, unless the wildcard already ends with one
    arguments
        wildcard char
    end

    if isempty(wildcard) || wildcard(end) ~= '*'
        wildcard(end+1) = '*';
    end
end
