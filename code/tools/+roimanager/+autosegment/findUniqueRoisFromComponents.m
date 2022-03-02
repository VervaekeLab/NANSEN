function roisOut = findUniqueRoisFromComponents(imageSize, S, varargin)
%findUniqueRoisFromComponents Find unique rois from all components
%
%   roisOut = findUniqueRoisFromComponents(imageSize, S, varargin)
%
%   imageSize   : [h,w] Size of image data
%   S           : All detected connected components from an image stack
%                 (S is a struct array of stats)
%
%   This function picks out highly overlapping spatial components one at the
%   time, starting with those that are present across most temporal samples,
%   thereby minimizing risk of picking partially overlapping cells as one.
%
%   See also getAllComponents



% Todo: make two versions, depending on how many components are found. One
% optimized for 100ks of components and one optimized for 1-10ks of
% components

    global fprintf % Use highjacked fprintf if available
    if isempty(fprintf); fprintf = str2func('fprintf'); end
    
    % Get the roimanager as a local package (2 folders up)
    rootPath = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    %roitools = tools.path2module(rootPath);
    
    def = struct('debug', false, 'filterByArea', false, 'numCandidateAbort', 1, 'nRoisToFind', 1000, 'roiClass', 'soma');
    opt = utility.parsenvpairs(def, [], varargin);

    warning('off', 'stats:linkage:NonMonotonicTree')

    imageSize = imageSize(1:2); % In case imageSize is size of stack   

    % Assign output
    roisOut = RoI.empty(0,1);

    if opt.filterByArea
        % Get rid of obviously large outliers to minimize overlapping candidates:
        medianArea = median([S.Area]);
        medianRadius = sqrt(medianArea/pi);

        areaCutoff = pi * (1.5*medianRadius)^2;
        keep = [S.Area] < areaCutoff;
        S = S(keep);

        % Use a 2 STD cutoff for the rest:
        areaCutoff = median([S.Area])+2*std([S.Area]);
        keep = [S.Area] < areaCutoff;
        S = S(keep);
    end
    
    
    % Compute two vectors to quickly identify overlapping components later
    allPixelIndices = cat(1, S.PixelIdxList); 
    regionInd = zeros(size(allPixelIndices));
    
    lastInd = 0;
    for i = 1:numel(S)
        IND = lastInd + (1:numel(S(i).PixelIdxList));
        regionInd(IND) = i;
        lastInd = IND(end);
    end
    
    % Boolean for all remaining components that wasn't taken care of yet
    remaining = true(numel(S), 1);

    
    % Create a "sum projection" image of all components. 
    uniquePixelList = unique(allPixelIndices);
      
    componentImage = zeros(imageSize);
    % Using a histogram here is faster than a for loop.      % (Maybe only if there are 100ks of components...)
    [N,E] = histcounts(allPixelIndices, uniquePixelList);
    componentImage(E(1:end-1)) = N;
    
    %imviewer(componentImage) % Todo: return this as part of summart
    
    mask = false(imageSize);
    
    nRois = 0;
    nIter = 0;
    finished = false;
    
    if opt.debug
        allIndividualComponents = zeros([imageSize, 0]);
    end
    

    while ~finished
        
        % Find peak in the summed component image. This will be the most 
        % active roi among candidates
        [~, peakInd] = max(componentImage(:));

        % Find all components that contain this peak
        containsPeak = regionInd(allPixelIndices==peakInd);
        containsPeak = intersect(containsPeak, find(remaining));
        
        if isempty(containsPeak) % It happened once:(
            componentImage(peakInd) = 0;
            continue
        end
        
        % Find all centroids and the center position
        currentCentroids = cat(1, S(containsPeak).Centroid);
        center = median(currentCentroids, 1);
        
        % Get rid of centers that are more than 3 pixels away. Default test
        % is to find all centroids that are less than 3 pixels away from the
        % median centroid position. In rare cases, where there might be two
        % or more clusters of centroids and the median centroid position
        % falls between these, use linkage to find and pick the biggest 
        % cluster
        keep = find(  all( abs( cat(1, S(containsPeak).Centroid ) - center ) < 3, 2) );
        if ~isempty(keep)
            containsPeak = containsPeak(keep);
        else
            % Find cluster of center positions using linkage
            Z = linkage(currentCentroids, 'centroid', 'euclidean');
            T = cluster(Z, 'Cutoff', 3, 'Criterion', 'distance');
            nClusters = max(T);

            nPointsinCluster = arrayfun(@(j) sum(T==j), 1:nClusters);
            [~, maxTind] = max(nPointsinCluster);
            keepB = T == maxTind;

            containsPeak = containsPeak(keepB);
        end
        
        
        if numel(containsPeak) <= opt.numCandidateAbort
            finished = true;
        end
        
        % Create image only containing the currently selected components.
        currentComponentImage = zeros(imageSize);

        % Histogram method is slower here so use a for loop instead.
        for i = 1:numel(containsPeak)
            currentComponentImage(S(containsPeak(i)).PixelIdxList) = currentComponentImage(S(containsPeak(i)).PixelIdxList)+1;
        end
        
        if opt.debug
            allIndividualComponents(:,:,end+1) = currentComponentImage;
        end
        
        % Get coords for a small crop around current center position
        x = round(center(1)); y = round(center(2));
        marginX = [x-1, imageSize(2)-x];
        marginY = [y-1, imageSize(1)-y];
        
        w = min([15, min(marginX), min(marginY)]);
        xInd = x + (-w:w); yInd = y + (-w:w);

        % Crop image around current center
        imSmall = currentComponentImage(yInd, xInd);
        
        % Find roi mask from this image:
        maskSmall = roimanager.binarize.getRoiMaskFromImage(imSmall, opt.roiClass);
        
        mask(yInd, xInd) = maskSmall;

        
        % Add a test here:
        % Test if mask cover completely (e.g 0.9) another mask, but still
        % contain a significant amount of area on its own. If true, do an
        % maskA & ~maskB ...
        % Current function for overlap calculation does so with respect to
        % the smallest roi. Make a script that can test this with regards
        % to the oldest roi.
        
        % Create roi
        newRoi = RoI('Mask', mask, imageSize);
        
        
        % Update component image by removing the last identified component.
        componentImage = componentImage - currentComponentImage;
        componentImage(mask) = 0;
        
        
        mask(yInd, xInd) = 0;
        
        if ~isempty(roisOut) && ~isempty(newRoi)
            [iA, iB] = roimanager.utilities.findOverlappingRois(roisOut, newRoi, 0.75);
            newRoi(iB) = [];
        end


        % Add roi
        if ~isempty(newRoi)
            nRois = nRois+1;
            roisOut(nRois) = newRoi;
        end
        

        % Add current segment numbers to the ignore list.
        remaining(containsPeak) = false;

        if sum(remaining) == 0; finished = true; end
        if sum(componentImage) <= 0; finished = true; end
        
        if numel(roisOut) == opt.nRoisToFind
             finished = true; 
        end
        
        if mod(numel(roisOut), 10)==0
            str = sprintf('Detected %d rois...\n', numel(roisOut));
            fprintf(str)
        end
        
        nIter = nIter+1;
        
    end
    
    warning('on', 'stats:linkage:NonMonotonicTree')
    fprintf('\n')
    
end