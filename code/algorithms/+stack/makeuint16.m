function imArray = makeuint16(imArray, bLims, tolerance, cropAmount)
%MAKEUINT16 - Rescale image intensities to the uint16 range
%   B = stack.makeuint16(A) linearly rescales the intensities of A
%   to the range [0,65535] and casts the result to UINT16. The
%   rescaling limits are estimated from A as the 0.05th and 99.95th
%   percentiles, ignoring NaN values.
%
%   B = stack.makeuint16(A,BLIMS) rescales using the explicit limits
%   BLIMS instead of estimating them from A. BLIMS is a two-element
%   vector [MINVAL,MAXVAL] for a 3-D array A, or a 1-by-2-by-N array
%   for a 4-D array A with N color channels. Pass [] to estimate
%   limits from A.
%
%   B = stack.makeuint16(A,[],TOLERANCE) also specifies the
%   percentile used to estimate limits from A, as a fraction
%   excluded from each end of the distribution. TOLERANCE is ignored
%   when BLIMS is non-empty. Pass [] to use the default of 0.0005.
%
%   B = stack.makeuint16(A,[],[],CROPAMOUNT) also crops CROPAMOUNT
%   pixels from each edge of every spatial dimension of A before
%   estimating limits, to exclude border artifacts such as
%   registration padding.
%
%   See also makeuint8, stack.reshape.imcropcenter

arguments
    imArray
    bLims = []
    tolerance = []
    cropAmount (1,1) double {mustBeNonnegative} = 0
end

imArray = normalizeIntensity(imArray, "uint16", bLims, tolerance, cropAmount);
end
