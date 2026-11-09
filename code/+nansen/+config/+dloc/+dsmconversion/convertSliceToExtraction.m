function [mode, input, isConverted, reason] = convertSliceToExtraction(slice)
%convertSliceToExtraction Convert a 0-based slice to a NANSEN ind or expr rule
%
%   Syntax:
%       [mode, input, isConverted, reason] = convertSliceToExtraction(slice)
%
%   A Dataset Structure Model substring rule is a Python style slice,
%   "start:stop", 0-based and half-open, where either bound may be omitted
%   and a negative bound counts from the end. A Python slice is clamped to
%   the text: on a text shorter than a bound, it returns the characters
%   that are there, or "". NANSEN's ind mode takes a 1-based MATLAB index
%   expression and raises an error for an index past the end of the text,
%   so only the whole range becomes an ind rule:
%       :      ->  ind   1:end
%   Every other slice becomes an expr rule whose repetition counts give
%   the same clamping. A lookbehind or lookahead that the text is too
%   short for matches nothing, and NANSEN then returns '':
%       0:6    ->  expr  ^.{0,6}
%       7:9    ->  expr  (?<=^.{7}).{0,2}
%       9:     ->  expr  (?<=^.{9}).*
%       :-4    ->  expr  ^.*(?=.{4}$)
%       7:-4   ->  expr  (?<=^.{7}).*(?=.{4}$)
%       -3:    ->  expr  .{0,3}$
%       -4:-1  ->  expr  .{0,3}(?=.{1}$)
%
%   Two kinds of slice are not converted; isConverted is then false, mode
%   and input are empty and reason says why:
%     - a slice whose stop is at or before its start, both counted from
%       the same end, as 5:3 or -1:-3, is empty for every text
%     - a slice with a negative start and a non-negative stop, as -3:5,
%       selects characters by both ends of the text at once
%
%   Output arguments:
%       mode        - "ind" or "expr", "" when not converted.
%       input       - The NANSEN extraction input, "" when not converted.
%       isConverted - True when the slice was converted.
%       reason      - Why the slice was not converted, "" when it was.

    arguments
        slice (1,1) string
    end

    mode = "";
    input = "";
    isConverted = false;
    reason = "";

    bounds = split(slice, ":");
    if numel(bounds) ~= 2
        reason = "it is not of the form start:stop";
        return
    end

    start = parseBound(bounds(1));
    stop = parseBound(bounds(2));

    if isnan(start); start = 0; end

    if isnan(stop) && start == 0
        mode = "ind";
        input = "1:end";
        isConverted = true;
        return
    end

    isStartNonNegative = start >= 0;
    if isnan(stop) && isStartNonNegative
        input = afterStart(start) + ".*";
    elseif isnan(stop)
        input = sprintf(".{0,%d}$", -start);
    elseif isStartNonNegative == (stop >= 0) && stop <= start
        reason = "the slice is empty for every text";
        return
    elseif isStartNonNegative && stop >= 0
        input = afterStart(start) + sprintf(".{0,%d}", stop - start);
    elseif isStartNonNegative
        input = afterStart(start) + sprintf(".*(?=.{%d}$)", -stop);
    elseif stop < 0
        input = sprintf(".{0,%d}(?=.{%d}$)", stop - start, -stop);
    else
        reason = "a slice from a position counted from the end to one counted from " + ...
            "the start depends on the length of the text";
        return
    end

    mode = "expr";
    isConverted = true;
end

function value = parseBound(bound)
%parseBound An integer bound, or NaN when the bound is omitted
    arguments
        bound (1,1) string
    end

    if strlength(strtrim(bound)) == 0
        value = NaN;
    else
        value = str2double(bound);
    end
end

function pattern = afterStart(start)
%afterStart Pattern anchoring a match at a position counted from the start
    arguments
        start (1,1) double
    end

    if start == 0
        pattern = "^";
    else
        pattern = sprintf("(?<=^.{%d})", start);
    end
end
