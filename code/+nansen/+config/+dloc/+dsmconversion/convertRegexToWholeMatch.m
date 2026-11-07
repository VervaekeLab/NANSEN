function [nansenPattern, isConverted, reason] = convertRegexToWholeMatch(dsmPattern)
%convertRegexToWholeMatch Rewrite a capture group regex so its whole match is the value
%
%   Syntax:
%       [nansenPattern, isConverted, reason] = convertRegexToWholeMatch(dsmPattern)
%
%   A Dataset Structure Model extracts the first capture group of a regular
%   expression. NANSEN's expr mode returns the whole match instead. The
%   text before and after the first capture group is moved into lookbehind
%   and lookahead assertions, so that the whole match is the group:
%
%       ^(\d{6}_\d+)[a-z]\.ABF$   ->   (?<=^)\d{6}_\d+(?=[a-z]\.ABF$)
%
%   A leading (?i), the one inline flag a model may use, is kept at the
%   front of the result. MATLAB applies a flag inside a lookbehind to the
%   lookbehind only, so it is not moved into it:
%
%       (?i)^sub-([a-z]+)   ->   (?i)(?<=^sub-)[a-z]+
%
%   A pattern without a capture group is returned unchanged.
%
%   Some patterns can not be rewritten this way. isConverted is then false,
%   nansenPattern is empty and reason says why:
%     - the first capture group is inside another group, as in
%       ^run(?:-(\d+))?$, so it can not be moved out of that group
%     - the capture group is quantified, as in ^(\d)+_
%     - the text before or after the group has a top level alternation
%     - the text before the group repeats an element without an upper
%       bound (*, + or {n,}), as in ^.*_(\d+). The model's regex search
%       repeats it as often as it can, while NANSEN's search takes the
%       first position where the lookbehind matches, so the two can return
%       different text: '1' and '2' for 170518_1_2.
%
%   Output arguments:
%       nansenPattern - The expr pattern for NANSEN, "" when not converted.
%       isConverted   - True when the pattern was converted.
%       reason        - Why the pattern was not converted, "" when it was.

    arguments
        dsmPattern (1,1) string
    end

    nansenPattern = "";
    isConverted = false;
    reason = "";

    flag = "";
    pattern = char(dsmPattern);
    if startsWith(dsmPattern, "(?i)")
        flag = "(?i)";
        pattern = pattern(5:end);
    end

    [groupStart, groupEnd, isNested] = findFirstCaptureGroup(pattern);

    if isempty(groupStart)
        nansenPattern = dsmPattern;
        isConverted = true;
        return
    end

    prefix = pattern(1:groupStart-1);
    group = pattern(groupStart+1:groupEnd-1);
    suffix = pattern(groupEnd+1:end);

    if isNested
        reason = "its first capture group is inside another group";
        return
    elseif ~isempty(suffix) && any(suffix(1) == '*+?{')
        reason = "its capture group is quantified";
        return
    elseif hasTopLevelAlternation(prefix) || hasTopLevelAlternation(suffix)
        reason = "the text around its capture group has a top level alternation";
        return
    elseif hasUnboundedRepetition(prefix)
        reason = "the text before its capture group repeats an element without an upper bound " + ...
            "(*, + or {n,}), which a lookbehind matches differently";
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
    nansenPattern = flag + nansenPattern;
    isConverted = true;
end

function [groupStart, groupEnd, isNested] = findFirstCaptureGroup(pattern)
%findFirstCaptureGroup Indices of the parentheses of the first capturing group
%
%   isNested is true when the group opens inside another group.
    groupStart = [];
    groupEnd = [];
    isNested = false;
    depth = 0;
    groupDepth = 0;
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
                isNested = depth > 0;
                groupDepth = depth;
            end
            depth = depth + 1;
        elseif c == ')'
            depth = depth - 1;
            if ~isempty(groupStart) && depth == groupDepth
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

function tf = hasUnboundedRepetition(pattern)
%hasUnboundedRepetition True when *, + or {n,} quantifies an element outside character classes
    tf = false;
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
        elseif c == '*' || c == '+' || (c == '{' && ~isempty(regexp(pattern(i:end), '^\{\d+,\}', 'once')))
            tf = true;
            return
        end
        i = i + 1;
    end
end
