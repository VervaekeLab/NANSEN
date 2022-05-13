function [roisOut, statOut] = shapeDetection(im, rois, varargin)


    showResults = false; % For debugging
    
    def.Shape = 'ring'; % 'ring' or 'disk' or 'custom'
    def.ShapeKernel = [];
    
    def.InnerRadius = 3;
    def.OuterRadius = 5; 
    def.Sigma       = 1;
    def.PercentOverlapForMerge = 75; % todo.

    

    im = double(im);

    % Normalize image to values between 0 and 1.
    im = im - min(im(:));
    im = im ./ max(im(:));

    
    filterWindow = flufinder.filter.makeRingKernel(im, varargin{:});
    
    % C = conv2(imOrig,window, 'same') ;
    % C = C./max(C(:));

    %% Create a donut correlation image

    % Todo:
    %   Does smaller/bigger window size giver better/worse results
    %   Does smaller/bigger window size influence the computation time?


    B = nlfilter(im, size(filterWindow), @(Y) corr2(Y, filterWindow)); % <- faster
    B = B ./ max(B(:));



    %% Binarize the donut correlation image
    BW = B.^2 > 0.2;  % BW2 = B > sqrt(0.2);
    % imviewer(cat(3, im, BW))

    BW = bwareaopen(BW, 5);
    % imviewer(cat(3, im, BW))


    %% Find centroids and filter by those that are not in existing rois or 
    % close to image edges
    CC = bwconncomp(BW);

    stat = regionprops(CC, 'Centroid');

    centerCoords = cat(1, stat(:).Centroid);
    % plot(gca, centerCoords(:,1), centerCoords(:,2), 'x')

    if ~isempty(rois)
        masks = arrayfun(@(roi) roi.mask, rois, 'uni', 0);
        masks = cat(3, masks{:});
        masks = max(masks, [], 3) ~= 0;
    else
        masks = false(size(im));
    end

    centerInd = sub2ind(size(masks),round(centerCoords(:,2)), round(centerCoords(:,1)) );
    keep = masks(centerInd) == 0;
    % plot(gca, centerCoords(keep,1), centerCoords(keep,2), 'xr')

    % Dont keep point very close to edge of image
    keep = keep & all(centerCoords > 15, 2);
    keep = keep & all(centerCoords < fliplr(size(masks))-15, 2);

    centerCoords = round( centerCoords(keep, :) );

    nKeep = sum(keep);

    % Todo: Use specialized function for getting crop indices
    
    %% extract "box" around remaining centroids.
    boxSize = [21,21];
    assert(all(mod(boxSize,2)==1), 'Boxsize should be odd')
    imdata = zeros( [boxSize, nKeep] );

    indX = (1:boxSize(2)) - ceil(boxSize(2)/2);
    indY = (1:boxSize(1)) - ceil(boxSize(1)/2);

    for i = 1:nKeep
        tmpX = indX + centerCoords(i, 1);
        tmpY = indY + centerCoords(i, 2);
        imdata(:, :, i) = im(tmpY, tmpX);
    end

    imdataUS = imresize(imdata, 4);

    % imdataG = filterImArray(imdata, 0.2, 'gauss');
    % imdata = imdataG;

    imdataUS(imdataUS<0)=0;
    imdataUS(imdataUS>1)=1;


    meanImUS = mean(imdataUS, 3);
    meanImUS = imresize(filterKernel, 4);
    err = zeros(size(imdata,3), 1);

    for i = 1:size(imdata,3)
        %err(i) = corr_err(meanImUS, imdataUS(:,:,i) );
        err(i) = corr2(meanImUS, imdataUS(:,:,i) );

    end


    % Keep only images that correlate with the donut.
    keep2 = err>0.1;
    imdata = imdata(:, :, keep2);
    centerCoords = centerCoords(keep2, :);

    [masks, s] = flufinder.binarize.findSomaMaskByEdgeDetection(imdata, centerCoords, size(im));
    
    % Todo: place in fov sized mask
    
    
    if showResults
        nIms = size(imdata,3);
        masks = zeros([size(im), nIms], 'logical');

        for i = 1:nIms
            center = centerCoords(i, :);
            [maskSmall, s(i)] = flufinder.binarize.findSomaMaskByEdgeDetection(imdata(:,:,i));
            
            
            masks(S(2):L(2), S(1):L(1), i) = roiMaskSmall;
            
            
            
            if showResults
                f = figure('Position', [1,1,  size(imdata,2)*4, size(imdata,1)*4], 'Visible', 'off'); 
                ax = axes('Position', [0,0,1,1], 'Parent', f);
                imagesc(ax, imresize( imdata(:,:,i), 4)) ; hold on

                plot(s(i).innerEdge(:,1), s(i).innerEdge(:,2))
                plot(s(i).outerEdge(:,1), s(i).outerEdge(:,2))
                axis image

                tmp = frame2im(getframe(f));
                tmp = imresize(tmp, 0.5);

                imdataRes(:, :, :, i) = tmp;
                close(f)
            end


            waitbar(i/nIms,h)
        end

        close(h)
    end


    %% Calculate scores
    score1 = [s.donutValue] ./ [s.nucleusValue];
    score2 = [s.donutValue] ./ [s.surroundValue];

    scoreA = [s.ridgeFraction];
    scoreB = score1 .* score2;



    if showResults
        imdata2 = uint8(imdata*255);
        imdata2 = reshape(imdata2, size(imdata,1), size(imdata,2), 1, []);
        imdata2 = cat(3, imdata2, imdata2, imdata2);
        imdata2 = imresize(imdata2, 4);

        [~, indFinal] = sort(scoreB, 'descend');
        imviewer(cat(2, imdata2(:,:,:,indFinal), imdataRes(:, :, :, indFinal)))
    end

    % Need some ROC Analysis on this when time is available:

    keepFinal = scoreA > 0.6; %& scoreB > 1.75;
    masks = masks(:, :, keepFinal);

    roisOut = RoI.empty;
    for i = 1:size(masks, 3)
        roisOut(end+1) = RoI('Mask', masks(:, :, i), size(im));
    end
    
    % Merge overlapping rois before returning
    overlap = def.PercentOverlapForMerge ./ 100;
    overlap = 0.8;
    roisOut = flufinder.utility.mergeOverlappingRois(roisOut);
    roisOut = roisOut.addTag('shape_segment');


    if nargout==2
        statOut = s;
    end

end