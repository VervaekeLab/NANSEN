function [newComponents, summary] = mergeWeightedComponents(imageSize, S, varargin)

% This is based on the function findUniqueRoisFromComponents, but the
% difference being that this function works on already detected weights
% spatial weights, whereas the other works on tentative binary masks.

    assert( all( isfield(S(1), {'Centroid', 'EquivDiameter', 'PixelIdxList', 'PixelValues'}) ), ...
        'S must have the following fields: Centroid, PixelIdxList, PixelValues' )

    % Default parameters
    defaults = struct();
    defaults.NumObservationsRequired = 2;
    defaults.MaxNumRois = 2000;
    defaults.PercentOverlapForMerge = 80;
    defaults.Debug = false;

    params = utility.parsenvpairs(defaults, [], varargin);


    meanDiameter = mean( [S.EquivDiameter] );
    centroidTolerance = ceil( meanDiameter / 4 );
    
    warning('off', 'stats:linkage:NonMonotonicTree')

    imageSize = imageSize(1:2); % In case imageSize is size of stack   

    % Assign output
    roisOut = RoI.empty(0,1);
    summary = struct;


    % Compute two vectors to quickly identify overlapping components later
    allPixelIndices = cat(1, S.PixelIdxList); % 1D vector with pixel indices for all components
    regionInd = zeros(size(allPixelIndices)); % 1D vector with component number for all pixels
    
    lastInd = 0;
    for i = 1:numel(S)
        IND = lastInd + (1:numel(S(i).PixelIdxList));
        regionInd(IND) = i;
        lastInd = IND(end);
    end
    
    % Boolean for all remaining components that wasn't taken care of yet
    remaining = true(numel(S), 1);
    
    
    % Create a "sum projection" image of all components. 
    %uniquePixelList = unique(allPixelIndices);
      
    componentImage = zeros(imageSize);

    for i = 1:numel(S)
        componentImage(S(i).PixelIdxList) = ...
            componentImage(S(i).PixelIdxList) + S(i).PixelValues;
    end
    
    summary.ComponentImageInit = componentImage;
    
    numRois = 0;
    numIter = 0;
    finished = false;
    
    if params.Debug
        allIndividualComponents = zeros([imageSize, 0]);
    end
    
    newComponents = struct();

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
        
        % Get rid of centers that are more than X pixels away. Default test
        % is to find all centroids that are less than X pixels away from the
        % median centroid position. In rare cases, where there might be two
        % or more clusters of centroids and the median centroid position
        % falls between these, use linkage to find and pick the biggest 
        % cluster. X equals the centroidTolerance

        centroidOffset = abs( cat(1, S(containsPeak).Centroid ) - center );
        keep = find(  all( centroidOffset < centroidTolerance, 2) );
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
        
        
        % Create image only containing the currently selected components.
        currentComponentImage = zeros(imageSize);

        
        % Get the mean of all the pixel values for the components that are
        % detected...
        for i = 1:numel(containsPeak)
            currentComponentImage(S(containsPeak(i)).PixelIdxList) = ...
                currentComponentImage(S(containsPeak(i)).PixelIdxList) + ...
                    S(containsPeak(i)).PixelValues ;
        end
        currentComponentImage = currentComponentImage ./ numel(containsPeak);

        if params.Debug
            allIndividualComponents(:,:,end+1) = currentComponentImage;
        end
        

        % Update component image by removing the last identified component.
        for i = 1:numel(containsPeak)
            m = containsPeak(i);
            componentImage(S(m).PixelIdxList) = ...
                componentImage(S(m).PixelIdxList) - S(m).PixelValues;
        end


        if numel(containsPeak) >= params.NumObservationsRequired
            numRois = numRois+1;
            newComponents(numRois).PixelIdxList = find(currentComponentImage > 0);
            newComponents(numRois).PixelValues = currentComponentImage(newComponents(numRois).PixelIdxList);
        end
        

        %componentImage = componentImage - currentComponentImage;
        %componentImage(mask) = 0;

        % Add current segment numbers to the ignore list.
        remaining(containsPeak) = false;

        if sum(remaining) == 0; finished = true; end
        if sum(componentImage(:)) <= 0; finished = true; end
        
        if numel(newComponents) >= params.MaxNumRois
             finished = true; 
        end
        
% %         if mod(numel(newComponents), 10)==0
% %             if exist('str', 'var')
% %                 fprintf( char(8*ones(1,length(str))));
% %             end
% %             
% %             str = sprintf('Detected %d rois...', numel(newComponents));
% %             fprintf(str)
% %         end
        
        numIter = numIter+1;
    end
    
    summary.ComponentImageFinished = componentImage;
    
    warning('on', 'stats:linkage:NonMonotonicTree')
    fprintf(newline)
    
    overlap = params.PercentOverlapForMerge ./ 100;
    roisOut = flufinder.utility.mergeOverlappingRois(roisOut, overlap);
    roisOut = roisOut.addTag('bw_threshold_segment');
    
    if nargout == 1
        clear summary
    end

end

