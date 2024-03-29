function imArray = makeuint16(imArray, bLims, tolerance, cropAmount)
% Very similar to imadjustn, but scales between 1 and 65536. 
%
%   imArray = makeuint16(imArray, bLims)
%       bLims should be a 1x2 vector for 3D arrays and a 1x2xn fo 4D arrays
%       with n colors
%
%   imArray = makeuint16(imArray, bLims, tolerance)
%
%   imArray = makeuint16(__, nvPairs)

% Todo: 
%   [ ] Adjust brightness individually per dimension
%   [ ] Combine with makeuint8


if ~isa(imArray, 'single') || ~isa(imArray, 'double')
    imArray = single(imArray);
end

if nargin < 4
    cropAmount = 0;
end

if nargin < 3 || isempty(bLims)
    tolerance = 0.0005;
end


if nargin < 2 || isempty(bLims)
    
    if cropAmount ~= 0
        imSize = size(imArray);
        imArrayCropped = stack.reshape.imcropcenter(imArray, imSize(1:2)-cropAmount);
        sorted = sort(imArrayCropped(:));
    else
        sorted = sort(imArray(:));
    end
    
    sorted(isnan(sorted)) = []; % Throw away black pixels. Usually present due to aligning...

    nSamples = numel(sorted);

    minVal = sorted(max([round(nSamples*tolerance), 1]));
    maxVal = sorted(min([round(nSamples*(1-tolerance)), nSamples]));
    
%     imMax = max(imArray, [], 3);
%     maxVal = prctile(imMax(:), 99.9);
else
    minVal = single(bLims(:, 1, :));
    maxVal = single(bLims(:, 2, :));
end

imArray = uint8((imArray - minVal) ./ (maxVal-minVal) .* 2^16-1);

end
