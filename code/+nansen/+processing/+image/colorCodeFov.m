function [projectionStack, colorcodedImage] = colorCodeFov(imageStack, ...
                        binningVector, colorMap, temporalMask, varargin)
%colorCodeFov Create colorcoded FOV image based on a binning vector
%
%   [P, C] = colorCodeFov(imageStack, binningVector) returns a binned
%   projection stack (P) and a colorcoded image (C) of an imageStack object
%   based on a binning vector. binningVector is a vector which specify how 
%   to bin the data before colorcoding it. It should be synchronized with 
%   the image data, but it is ok if its some samples too long or too short.
%
%   The binning vector could for example be the binned position on the
%   running wheels or a trial state vector with different numbers for
%   different segments of a trial.
%
%   The function accepts two optional inputs, colorMap and temporalMask:
%   [P, C] = colorCodeFov(imPointer, binningVector, colorMap, temporalMask)
%   Here the colorMap should be the same length as the number of unique 
%   bins in the binning vector. The default colormap is hsv (the colors of
%   the rainbow.
%   The temporalMask is a logical and can be used to ignore certain parts
%   of the data altogether. It should be the same length as the
%   binningVector. True values are kept, and false values are ignored when
%   doing the binning.
%
%   If you want to supply a temporalMask, but not a colorMap, just leave
%   the colorMap input empty, for example:
%   [P, C] = colorCodeFov(imPointer, binningVector, [], temporalMask)
%
%   It is also possible to give many binningVectors and receive multiple
%   colorcoded images. In that case, the binningVector input should be a
%   cell array of binningVectors. The output will then also be cell arrays
%   corresponding to each binning vector. This allows to generate multiple
%   colorcoded fovs and only load the image data once. In this case
%   colorMaps and temporalMasks can also be supplied as cell arrays, and
%   the same rules aplpy as above.

% Eivind Hennestad | Vervaeke Lab | 2019.10.11

% Todo:
%
%   Create this as subclass og ImageStackProcessor?

def = struct('BLim', []);
val = struct('BLim', @(x) true);
opt = utility.parsenvpairs(def, val, varargin);

% Is binningVector a cell?
if isa(binningVector, 'cell')
    nOutputs = numel(binningVector);
else
    binningVector = {binningVector};
    nOutputs = 1;
end

% Handle inputs
if ~exist('temporalMask', 'var') || isempty(temporalMask)
    temporalMask = cell(nOutputs, 1);
    for a = 1:nOutputs
        temporalMask{a} = true(size(binningVector{a}));
    end
elseif nOutputs == 1 && ~isa(temporalMask, 'cell')
    temporalMask = {temporalMask};
end


if  ~exist('colorMap', 'var') || isempty(colorMap)
    colorMap = cell(nOutputs, 1);
    for a = 1:nOutputs
        nBins = numel(unique(binningVector{a}(temporalMask{a})));
        colorMap{a} = hsv(nBins);
    end
elseif nOutputs == 1 && ~isa(colorMap, 'cell')
    colorMap = {colorMap};
end


% Assert that number of cells are the same for last three inputs
% Assert that number of colors match number of bins in binningVector

imH = imageStack.ImageHeight;
imW = imageStack.ImageWidth;

batchSize = imageStack.chooseChunkLength();
[IND, numParts] = imageStack.getChunkedFrameIndices(batchSize);


% Preallocate outputs...
projectionStack = cell(nOutputs, 1);
colorcodedImage = cell(nOutputs, 1);

for c = 1:nOutputs
    nBins = numel(unique(binningVector{c}(temporalMask{c})));
    projectionStack{c} = zeros([imH, imW, nBins], 'single');
    colorcodedImage{c} = zeros([imH, imW, 3], 'single');
end


% Start working on images. Because image files are typically very large,
% run this in a loop and work on substack of the whole image series.

for i = 1:numParts
    
    imdata = imageStack.getFrameSet(IND{i});

    % Bin images in projection stacks based on the binning vector
    for j = 1:nOutputs
        
        % Check that vectors are long enough, and skip frames if so
        if iLast > numel(binningVector{j})
            iLast = numel(binningVector{j});
            frameInd = iFirst:iLast;
        end
        
        nBins = numel(unique(binningVector{j}(temporalMask{j})));
        bins = unique(binningVector{j}(temporalMask{j}));
        
        for k = 1:nBins
            
            matchingFrames = binningVector{j}(frameInd) == bins(k) & temporalMask{j}(frameInd);
            tmpImdata = imdata(:, :, matchingFrames);
        
            numAllMatching = sum(binningVector{j} == bins(k) & temporalMask{j});
            
            projectionStack{j}(:, :, k) = ...
                projectionStack{j}(:, :, k) + ...
                    (sum(tmpImdata, 3) ./ numAllMatching );
        end
    end
end

% Colorcode.
for l = 1:nOutputs
    
    % make 3 dubplicates of the projection stack
    projectionStackRGB = repmat(projectionStack{l}, 1,1,1,3);
    
    % Weight each duplicate with the rgb colorcode for each bin.
    for m = 1:size(projectionStack{l}, 3)
        tmpColor = colorMap{l}(m, :);
        projectionStackRGB(:,:,m,:) = projectionStackRGB(:,:,m,:) .* reshape(tmpColor, 1, 1, 1, 3);
    end

    % Get the average of each color channel.
    colorcodedImage{l} = squeeze(nanmean(projectionStackRGB, 3));
    colorcodedImage{l} = makeuint8(colorcodedImage{l}, opt.BLim);

end

if nOutputs == 1
    projectionStack = projectionStack{1};
    colorcodedImage = colorcodedImage{1};
end

end