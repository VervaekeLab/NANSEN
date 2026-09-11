function [mode, input, isConverted] = convertSliceToExtraction(slice)
%convertSliceToExtraction Convert a 0-based slice to a NANSEN ind or expr rule
%
%   Syntax:
%       [mode, input, isConverted] = convertSliceToExtraction(slice)
%
%   A Dataset Structure Model substring rule is a Python style slice,
%   "start:stop", 0-based and half-open, where either bound may be omitted
%   and a negative bound counts from the end. NANSEN's ind mode takes a
%   1-based MATLAB index expression.
%
%   Slices whose bounds are both known positions become ind rules:
%       0:6  ->  ind  1:6
%       :    ->  ind  1:end
%   Slices that depend on the length of the text become expr rules, so
%   that they do not rely on end appearing anywhere but in 1:end:
%       9:   ->  expr (?<=^.{9}).*
%       :-4  ->  expr ^.*(?=.{4}$)
%
%   A slice with a negative start and a non-negative stop depends on the
%   length of the text in a way neither mode can express; isConverted is
%   then false and mode and input are empty.

    arguments
        slice (1,1) string
    end

    mode = "";
    input = "";
    isConverted = false;

    bounds = split(slice, ":");
    if numel(bounds) ~= 2
        return
    end

    start = parseBound(bounds(1));
    stop = parseBound(bounds(2));

    if isnan(start); start = 0; end

    if start >= 0 && ~isnan(stop) && stop >= 0
        mode = "ind";
        input = sprintf("%d:%d", start + 1, stop);

    elseif start == 0 && isnan(stop)
        mode = "ind";
        input = "1:end";

    elseif start > 0 && isnan(stop)
        mode = "expr";
        input = sprintf("(?<=^.{%d}).*", start);

    elseif start >= 0 && stop < 0
        mode = "expr";
        if start == 0
            input = sprintf("^.*(?=.{%d}$)", -stop);
        else
            input = sprintf("(?<=^.{%d}).*(?=.{%d}$)", start, -stop);
        end

    elseif start < 0 && isnan(stop)
        mode = "expr";
        input = sprintf(".{%d}$", -start);

    elseif start < 0 && stop < 0 && stop > start
        mode = "expr";
        input = sprintf(".{%d}(?=.{%d}$)", stop - start, -stop);

    else
        return
    end

    isConverted = true;
end

function value = parseBound(bound)
%parseBound An integer bound, or NaN when the bound is omitted
    if strlength(strtrim(bound)) == 0
        value = NaN;
    else
        value = str2double(bound);
    end
end
