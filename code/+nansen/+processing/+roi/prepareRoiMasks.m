function sOut = prepareRoiMasks(roiArray, varargin)
% prepareRoiMasks Prepare roi masks for signal extraction
%
%   masks = prepareRoiMasks(roiArray) will prepare the roi masks using
%           default options.
%
%   masks = prepareRoiMasks(roiArray, paramStruct) will prepare the roi
%           masks using parameters given in a struct of parameters.
%
%   masks = prepareRoiMasks(roiArray, name, value) will prepare the roi
%           masks using parameters given as name, value pairs.
%
%   PARAMETERS:

    % Todo:
    %  [x] Output is a struct array of:
    %      - 3d array of masks where each plane (3rd dim) is a subregion.
    %        Main roi is always on 1st plane
    %      - Spatial footprint, i.e sum of all rois.
    %      - Bounding box.
    % OR
    %  [x] Cell array of sparse roi masks per subregion of roi
    %  [ ] - More explicit about available methods...
    %  [x] Function for creating sparse roi array
    
    %import roimanager.signalExtraction.prepareMasks
    import nansen.processing.roi.createMasks
    
    % Get default parameters and assertion functions.
    [P, V] = nansen.twophoton.roisignals.extract.getDefaultParameters();
    
    % Parse potential parameters from input arguments
    P = utility.parsenvpairs(P, V, varargin{:});

    % Return if roi mask format is unset
    if strcmp(P.roiMaskFormat, 'n/a')
        sOut = roiArray; return
    end

    if ischar(P.roiInd) && strcmp(P.roiInd, 'all')
        P.roiInd = 1:numel(roiArray);
    end
    
    % Convert roiArray to struct array of masks for better performance
    % during signal extraction...
    if isa(roiArray, 'RoI') || (isa(roiArray, 'struct') && isfield(roiArray, 'mask'))
        %S2 = prepareMasks(roiArray, P.Method, P.RoiInd, P.ImageMask);
        S = createMasks(roiArray, P);
    elseif isa(roiArray, 'struct') && isfield(roiArray, 'original')
        S = roiArray; clearvars roiArray
    else
        error('Unsupported input format of roiArray')
    end
    
    % Configure the output for better performance during signal extraction
    % (especially relevant when extracting in blocks)
    
    if strcmp(P.roiMaskFormat, 'sparse')
                      
        for i = 1:numel(S)
            S{i} = createWeightedSparseMatrix(S{i}); % <- Local function
        end

        sOut = struct();
        sOut.Masks = S;
        
    elseif strcmp(P.roiMaskFormat, 'struct')
        
        sOut = struct('Masks', {}, 'xInd', {}, 'yInd', {});

        for jRoi = 1:size(S{1}, 3)
            roiSlices = cellfun(@(c) c(:, :, jRoi), S, 'uni', 0);
            sOut(jRoi).Masks = cat(3, roiSlices{:});

            bwFootprint = sum(sOut(jRoi).Masks, 3) >= 1;
            
            [y, x] = find(bwFootprint);
            minX = min(x); maxX = max(x);
            minY = min(y); maxY = max(y);
            
            sOut(jRoi).xInd = minX:maxX;
            sOut(jRoi).yInd = minY:maxY;
        end
    end
end

function M = createWeightedSparseMatrix(A)
%createWeightedSparseMatrix Create sparse matrix for signal extraction
%
%   M = getWeightedSparseMatrix(A) returns the 3D logical array as a sparse
%   matrix where each pixel value is weighted by the number of pixels in a
%   mask.
%
%   INPUT:
%       A : Array of size imageHeight x imageWidth x numRois
%
%   OUTPUT :
%       M : Matrix of size numRois x numPixelsPerImage

        % Reshape to make array 2D, collapsing each image to a vector
        M = reshape(A, [], size(A, 3))';
        M = M ./ sum(M, 2);
        M = sparse(M);

end
