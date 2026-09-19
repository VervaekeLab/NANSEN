function [fileNameExpression, fileType, isConverted, isApproximate] = convertFilePatternToWildcard(dsmPattern, identityTokens)
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
%   \.nii\.gz$ has the file type .nii.gz.
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
%   then false.
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

    % An extension may have several parts, as .nii.gz. Each part starts
    % with a letter, so that a version number before the extension, as in
    % v1\.2\.txt, is not taken for part of it.
    extension = regexp(dsmPattern, "((?:\\\.[A-Za-z][A-Za-z0-9]*)+)\$$", "tokens", "once");
    if ~isempty(extension)
        fileType = string(erase(extension{1}, "\"));
    end

    tokens = regexp(dsmPattern, "\{([A-Za-z_][A-Za-z0-9_]*)\}", "tokens");
    pattern = dsmPattern;
    for i = 1:numel(tokens)
        if ~ismember(tokens{i}{1}, identityTokens)
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
        elseif c == '*' || (c == '^' && i == 1) || (c == '$' && i == numel(pattern)) ...
                || ~any(c == '[](){}+?|^$')
            wildcard(end+1) = c; %#ok<AGROW>
            i = i + 1;
        else
            return
        end
    end

    if isApproximate && all(ismember(wildcard, '^$*.'))
        isApproximate = false;
        return % the wildcard would match every file in the folder
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
    if isempty(wildcard) || wildcard(end) ~= '*'
        wildcard(end+1) = '*';
    end
end
