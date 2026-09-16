function imArray = normalizeIntensity(imArray, targetClass, bLims, tolerance, cropAmount)
%normalizeIntensity - Rescale intensities and cast to an integer class
%   B = normalizeIntensity(A,TARGETCLASS,BLIMS,TOLERANCE,CROPAMOUNT)
%   linearly rescales A from the range [MINVAL,MAXVAL] to the full
%   range of TARGETCLASS, then casts the result to TARGETCLASS. The
%   range is taken from BLIMS when it is non-empty, and otherwise
%   estimated from A as the TOLERANCE and (1 - TOLERANCE) percentiles
%   of A, ignoring NaN values. When CROPAMOUNT is non-zero, that many
%   pixels are cropped from each spatial edge of A before the
%   percentiles are sampled.
%
%   This is a private helper shared by makeuint8 and makeuint16, which
%   define the public calling syntax.

arguments
    imArray
    targetClass (1,1) string {mustBeMember(targetClass, ["uint8", "uint16"])}
    bLims = []
    tolerance = []
    cropAmount (1,1) double {mustBeNonnegative} = 0
end

if ~isa(imArray, "single") && ~isa(imArray, "double")
    imArray = single(imArray);
end

if isempty(bLims)
    if isempty(tolerance)
        tolerance = 0.0005;
    end

    if cropAmount ~= 0
        imageSize = size(imArray);
        croppedArray = stack.reshape.imcropcenter(imArray, imageSize(1:2) - cropAmount);
        sortedValues = sort(croppedArray(:));
    else
        sortedValues = sort(imArray(:));
    end

    sortedValues(isnan(sortedValues)) = []; % Discard NaNs, e.g. from registration padding.
    numSamples = numel(sortedValues);

    minVal = sortedValues(max(round(numSamples * tolerance), 1));
    maxVal = sortedValues(min(round(numSamples * (1 - tolerance)), numSamples));
else
    minVal = cast(bLims(:, 1, :), class(imArray));
    maxVal = cast(bLims(:, 2, :), class(imArray));
end

scaleMax = double(intmax(targetClass));
imArray = cast((imArray - minVal) ./ (maxVal - minVal) .* scaleMax, targetClass);
end
