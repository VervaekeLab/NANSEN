function [nansenPattern, isConverted] = convertRegexToWholeMatch(dsmPattern)
%convertRegexToWholeMatch Rewrite a capture group regex so its whole match is the value
%
%   Syntax:
%       [nansenPattern, isConverted] = convertRegexToWholeMatch(dsmPattern)
%
%   A Dataset Structure Model extracts the first capture group of a regular
%   expression. NANSEN's expr mode returns the whole match instead. The
%   text before and after the first capture group is moved into lookbehind
%   and lookahead assertions, so that the whole match is the group:
%
%       ^(\d{6}_\d+)[a-z]\.ABF$   ->   (?<=^)\d{6}_\d+(?=[a-z]\.ABF$)
%
%   A pattern without a capture group is returned unchanged. A pattern
%   whose group is quantified, or whose surrounding text has a top level
%   alternation, can not be rewritten this way; isConverted is then false
%   and nansenPattern is empty.

    arguments
        dsmPattern (1,1) string
    end

    nansenPattern = "";
    isConverted = false;

    [groupStart, groupEnd] = findFirstCaptureGroup(char(dsmPattern));

    if isempty(groupStart)
        nansenPattern = dsmPattern;
        isConverted = true;
        return
    end

    pattern = char(dsmPattern);
    prefix = pattern(1:groupStart-1);
    group = pattern(groupStart+1:groupEnd-1);
    suffix = pattern(groupEnd+1:end);

    isQuantified = ~isempty(suffix) && any(suffix(1) == '*+?{');
    if isQuantified || hasTopLevelAlternation(prefix) || hasTopLevelAlternation(suffix)
        return
    end

    if hasTopLevelAlternation(group)
        group = ['(?:', group, ')'];
    end

    nansenPattern = string(group);
    if ~isempty(prefix)
        nansenPattern = "(?<=" + prefix + ")" + nansenPattern;
    end
    if ~isempty(suffix)
        nansenPattern = nansenPattern + "(?=" + suffix + ")";
    end
    isConverted = true;
end

function [groupStart, groupEnd] = findFirstCaptureGroup(pattern)
%findFirstCaptureGroup Indices of the parentheses of the first capturing group
    groupStart = [];
    groupEnd = [];
    depth = 0;
    inClass = false;
    i = 1;
    while i <= numel(pattern)
        c = pattern(i);
        if c == '\'
            i = i + 2;
            continue
        elseif inClass
            inClass = c ~= ']';
        elseif c == '['
            inClass = true;
        elseif c == '('
            isCapturing = ~(i < numel(pattern) && pattern(i+1) == '?');
            if isempty(groupStart) && isCapturing
                groupStart = i;
                depth = 1;
            elseif ~isempty(groupStart)
                depth = depth + 1;
            end
        elseif c == ')' && ~isempty(groupStart)
            depth = depth - 1;
            if depth == 0
                groupEnd = i;
                return
            end
        end
        i = i + 1;
    end
    groupStart = [];
end

function tf = hasTopLevelAlternation(pattern)
%hasTopLevelAlternation True when | appears outside groups and character classes
    tf = false;
    depth = 0;
    inClass = false;
    i = 1;
    while i <= numel(pattern)
        c = pattern(i);
        if c == '\'
            i = i + 2;
            continue
        elseif inClass
            inClass = c ~= ']';
        elseif c == '['
            inClass = true;
        elseif c == '('
            depth = depth + 1;
        elseif c == ')'
            depth = depth - 1;
        elseif c == '|' && depth == 0
            tf = true;
            return
        end
        i = i + 1;
    end
end
