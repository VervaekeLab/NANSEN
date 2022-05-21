function [mask, stat] = findSomaMaskByEdgeDetection(im, varargin)
%findSomaMaskByEdgeDetection Find roi mask for a cell body based on edge detection
%
%   INPUTS:
%       im          : thumbnail (cropped) image of a neuronal cell body
%       center      : center coordinates of the thumbnail image in the 
%                     original fov image
%       origImSize  : size of original fov image
%
%   OPTIONS (name/value pairs)
%       method
%       output
%       us
%
%   DESCRIPTION:
%       
%       This methods takes a single image (2D) or a stack of images (3D)
%       as inputs and finds a mask for a soma (cell body). The mask is
%       found by edge detection in the following way:
%           
%           1) The image is reshaped from a cartesian image to a polar 
%           image, i.e the first dimension of the new image is the radius 
%           from the center of the image, and the second dimension is the 
%           angle fo a radial line originating from the image center.
%           2) The gradient is computed along the radial dimension and the
%           peak gradient for each angle is selected as a boundary 
%           candidate.
%           3) The gradient is smoothed and outliers are removed
%
%       An optional parameter is to start by detecting the nucleus
%       boundary and use the result for localizing the cell body boundary.
%       Many times the nucleus boundary might be easier to reliably detect
%       and it can serve as a constraint on the outer boundary, i.e we can 
%       narrow the search for the outer boundary down to a thin region
%       outside of the inner (nucleus) boundary. If the gradient of a
%       nucleus boundary is insignificant (i.e a cell is overfilled, or the
%       cell is sectioned close to the top or bottom) the search for the 
%       outer boundary follows the standard procedure.
%       
%
%

% quantify ratio of brightness inside donut vs inside nucleus
% quantify the edgemagnitude.
% quantify uniformness of edges and brightness inside donut
    
    showPlot = false;

    % Todo: redefine parameters.
    params = struct();
    params.SpatialUpsamplingFactor = 4;
    params.DetectNucleusBoundary = true;

    def = struct('method', 'donut', 'output', 'mask', 'us', 4);
    opt = utility.parsenvpairs(def, [], varargin);

    imSizeSmall = size(im);
    
    %Upsample and smooth image.
    upSampleFactor = opt.us;
    im = imresize(im, upSampleFactor);

    smoothingWindow = max([1, 2*upSampleFactor+1]);
    smoothBoundary = @(b) utility.circularsmooth(b, smoothingWindow);
        
    imSizeUs = size(im);
    numImages = size(im, 3);
    
    % Unroll the image for easier circular edge detection...
    unrolled = stack.reshape.imunroll(im);
    [~, numAngles, ~] = size(unrolled);

    % Assign angules for each radial line in polar image
    thetaDeg = 0 : (360 / numAngles) : 360;
    thetaRad = deg2rad(thetaDeg(1:end-1));
    
    % Blur images using gaussian filter
    for i = 1:numImages
        unrolled(:, :, i) = imgaussfilt(unrolled(:, :, i), 1);
    end

    % Create the gradient image for edge detection.
    grad = diff(double(unrolled));
        

    % Allocate array for roi masks and initalize struct for stats
    mask = zeros([imSizeSmall(1:2), numImages], 'logical');
    
    if nargout == 2
        returnStats = true; 
        stat = initializeStats();
    else
        returnStats = false;
   end
    
    for i = 1:numImages
        
        tmpUnrolled = unrolled(:, :, i);
        tmpGradient = grad(:, :, i);
    
        
        if params.DetectNucleusBoundary
            % Start by detecting the boundary of the nucleus, i.e a
            % boundary where the gradient is positive, i.e going from a
            % dark region to a brighter region.
    
            [innerBoundary, innerBoundaryStats] = findEdge(tmpGradient, 'rise');
            if isempty(innerBoundary); continue; end
               
            innerBoundarySmooth = smoothBoundary(innerBoundary);            % anon function
            
            % Todo: Check that inner boundary is salient
            %innerBoundaryStats.EdgeValue2

            if isSignificantBoundary(innerBoundaryStats)
                %fprintf('inner\n')
                tmpGradient = updateGradientImage(tmpGradient, innerBoundarySmooth);
            else
                %fprintf('outer\n')
                innerBoundarySmooth = zeros(1, size(tmpGradient, 2));
            end
        
        else
            innerBoundarySmooth = zeros(size(tmpGradient, 2), 1);
        end
        
        [outerBoundary, outerBoundaryStats] = findEdge(tmpGradient, 'fall');
        if isempty(outerBoundary); continue; end
            
        outerBoundarySmooth = smoothBoundary(outerBoundary);                % anon function
       
        outerBoundary = outerBoundary + innerBoundarySmooth;
        outerBoundarySmooth = outerBoundarySmooth + innerBoundarySmooth;
        
        % Make sure boundary is within original image bounds
        lb = 1; ub = size(grad,1);
        outerBoundarySmooth( outerBoundarySmooth<lb ) = lb;
        outerBoundarySmooth( outerBoundarySmooth>ub ) = ub;
        
                
        if showPlot
            showDetectedEdges(grad, tmpUnrolled, innerBoundary, ...
                outerBoundary, innerBoundarySmooth, outerBoundarySmooth)              %#ok<UNRCH> % Local function
        end

        % Scale back (spatial down sample)
        innerRadius = innerBoundarySmooth ./ upSampleFactor;
        outerRadius = outerBoundarySmooth ./ upSampleFactor;

        outerRadius = outerRadius + 2/upSampleFactor; % Increase outer radius slightly

        % Transform back to cartesian coordinates
        [X, Y] = pol2cart(thetaRad, outerRadius);

        X = imSizeSmall(2)/2 + X + 0.5 ; % Correct for pixel coordinates being centered on 0.5
        Y = imSizeSmall(1)/2 - Y + 0.5 ; % Correct for pixel coordinates being centered on 0.5
        
        % Create mask
        mask(:, :, i) = poly2mask(X, Y, imSizeSmall(1), imSizeSmall(2));

    
        
        if returnStats
            args = {im, tmpUnrolled, innerBoundarySmooth, outerBoundarySmooth, ...
                imSizeUs, thetaRad};
            
            stat(i) = getStats(args{:});
            if params.DetectNucleusBoundary
                stat(i).innerStrength = innerBoundaryStats.EdgeValue;
            end
            stat(i).outerStrength = outerBoundaryStats.EdgeValue;
        end
    
    end

    
% % %     figure; plot(VAL)
% % %     hold on
% % %     ax = gca;
% % %     plot(ax.XLim, ones(1,2)*mean(VAL)-std(VAL));
% % %     plot(ax.XLim, ones(1,2)*mean(VAL)+std(VAL));

end

% % % Local functions

function [edgeCoords, stat] = findEdge(grad, polarity)

    stat = struct;
    showPlot = false;

    switch polarity
        case 'fall'
            peakfun = @nanmin;
        case 'rise'
            peakfun = @nanmax;
    end

    [edgeVal, edgeCoords] = peakfun(grad);


    medianCoord = median(edgeCoords);
    stdCoord = std(edgeCoords);    


    if showPlot
        persistent f ax hIm
        if isempty(f) || ~isvalid(f)
            f = figure('Position', [300,300,300,300]); 
            ax = axes('Position', [0,0,1,1]);
        end
        imagesc(ax, grad); hold on
        plot(ax, 1:size(grad,2), edgeCoords, 'ow')
        p = polyfit(1:size(grad,2), edgeCoords, 2);
        y = polyval(p, 1:size(grad,2));
        plot(ax, 1:size(grad,2), y, 'w')
    end
    
    % Find big jumps in coords
    cunt = 0;
    while true
        
        if isempty(edgeCoords)
            break
        end
        
        deltaRs = diff([edgeCoords(end), edgeCoords]);
        
        if all(deltaRs < 5)
            break
        end

        [~, tmpInd] = max(deltaRs);

        if edgeCoords(tmpInd) > medianCoord + stdCoord
            tmpBnd = round( max( [ 1, edgeCoords(tmpInd)-2] ));
            [edgeVal(tmpInd), edgeCoords(tmpInd)] = peakfun(grad(1:tmpBnd, tmpInd));
        elseif edgeCoords(tmpInd) < medianCoord - stdCoord
            tmpBnd = round( min( [ edgeCoords(tmpInd)+2, size(grad, 1)] ));
            [edgeVal(tmpInd), edgeCoords(tmpInd)] = peakfun(grad(tmpBnd:end, tmpInd));
            edgeCoords(tmpInd) = edgeCoords(tmpInd) + tmpBnd - 1;
        else
            % Ad hoc solution...If point is in range, but still has a big
            % jump, do linear interpolation with previous..

            % Alternative: Find out if previous value is more fucked up...
            
            if tmpInd == 1
                prevInd = numel(edgeCoords);
            else
                prevInd = tmpInd-1;
            end

            newCoord = mean(edgeCoords([prevInd, tmpInd]));

            if edgeVal(prevInd) > edgeVal(tmpInd)
                edgeCoords(prevInd) = newCoord;
                edgeVal(prevInd) = grad(round(edgeCoords(prevInd)), prevInd);
            else
                edgeCoords(tmpInd) = newCoord;
                edgeVal(tmpInd) = grad(round(edgeCoords(tmpInd)), tmpInd);
            end
            
        end

        % Prevent looping into fields of eternity.
        cunt = cunt+1;
        if cunt > size(grad,2)
            break
        end
        
        % Update mean and std values.
        medianCoord = median(edgeCoords);
        stdCoord = std(edgeCoords);    
    
    end
    
    stat.EdgeValues = edgeVal;
    stat.EdgeValue = mean(edgeVal);
    stat.EdgeValue2 = mean(edgeVal) ./ std(edgeVal);

end

function gradientImageOut = updateGradientImage(gradientImage, boundary)
%updateGradientImage Create a cropped gradient image, cropping at inner
%boundary and keeping a thin region outside the boundary


    lowerRadius = floor(min(boundary));
    newIm = nan(size(gradientImage) - [lowerRadius, 0]);

    numAngles = size(gradientImage, 2);
    assert(numAngles == length(boundary), 'Boundary should have same number of samples as the width of the gradient image')
    
    % Insert values for new image so that the new image is cropped along
    % the boundary
    for j = 1:numAngles
        tmpLowerRadius = round(boundary(j));
        values = gradientImage(tmpLowerRadius:end, j);
        newIm(1:numel(values), j) = values;
    end
    
    % Offset is supposed to keep search close to internal
    % border. Expand search area a factor of 0.75 times the
    % mean of the internal radius:
    
    %upSampleFactor = 4;
    %offset = round( mean(boundary) ./ upSampleFactor .* 0.75);            
    %h = min([size(newIm,1), offset*upSampleFactor ]);% why 3??????? parameterize
    
    
    upperRadius = ceil( mean(boundary) .* 1.2 );
    %upperRadius % todo: adapt....
    h = min([size(newIm, 1), upperRadius ]);
    
    gradientImageOut = newIm(1:h, :);
end


function tf = isSignificantBoundary(innerBoundaryStats)
    tf = innerBoundaryStats.EdgeValue2 > 1.5; % Ad hoc cutoff value...
end

function stat = initializeStats()
    % Initialize struct to keep stats
    stat = struct('innerEdge', {}, ...
        'outerEdge', {}, ...
        'nucleusValue', {}, ...
        'donutValue', {}, ...
        'surroundValue', {}, ...
        'innerStrength', {}, ...
        'outerStrength', {}, ...
        'uniformity', {}, ...
        'variance', {}, ...
        'ridgeFraction', {});
end

function stat = getStats(im, tmpUnrolled, innerBoundarySmooth, ...
    outerBoundarySmooth, imSizeUs, theta)
    
    stat = struct;
    
    % Create some stat values:
    imCenter = fliplr( imSizeUs(1:2)./2 );
    x = imCenter(1); y = imCenter(2);


    [X, Y] = pol2cart(deg2rad(theta), outerBoundarySmooth);
    stat.outerEdge = [x+X', y-Y'];

    maskSoma = poly2mask(x+X-0.25, y-Y-0.25,  imSizeUs(1), imSizeUs(2));

    [X, Y] = pol2cart(deg2rad(theta), innerBoundarySmooth);
    stat.innerEdge = [x+X', y-Y'];

    maskNucl = poly2mask(x+X-0.25, y-Y-0.25,  imSizeUs(1),  imSizeUs(2));


    stat.nucleusValue = median(mean(im(maskNucl)));
    stat.donutValue = median(mean(im(maskSoma &~ maskNucl)));
    stat.surroundValue = median(mean(im(~maskSoma)));

    stat.innerStrength = 0;
    stat.outerStrength = 0;

    centerLine = mean([innerBoundarySmooth', outerBoundarySmooth'], 2); % For stats


    indCenter = sub2ind(size(tmpUnrolled), round(centerLine), (1:size(tmpUnrolled,2))');
    indInner = sub2ind(size(tmpUnrolled), round(innerBoundarySmooth)', (1:size(tmpUnrolled,2))');
    indOuter = sub2ind(size(tmpUnrolled), round(outerBoundarySmooth)', (1:size(tmpUnrolled,2))');

    VAL = double(tmpUnrolled(indCenter));

    stat.uniformity = mean(VAL) ./ std(VAL);
    stat.variance = std(VAL);

    tf = ( VAL > mean(VAL)-std(VAL) &  VAL < mean(VAL)+std(VAL) );
    stat.uniformity = sum(tf) ./ numel(VAL);

    if all(innerBoundarySmooth==0)
        stat.ridgeFraction = nan;
    else
        isRidge = tmpUnrolled(indCenter) > tmpUnrolled(indInner) & tmpUnrolled(indCenter) > tmpUnrolled(indOuter);
        stat.ridgeFraction = mean(isRidge);
    end

end

function showDetectedEdges(grad, tmpUnrolled, edgeCoordsInn, ...
    edgeCoordsOut, edgeCoordsInnS, edgeCoordsOutS)

    persistent f ax hIm
    if isempty(f) || ~isvalid(f)
        f = figure('Position', [300,300,300,300]); axes('Position', [0,0,1,1]);
        ax = axes(f, 'Position',[0,0,1,1]);
    else
        cla(ax)
    end

    h = imagesc(ax, grad); hold on

    plot(ax, 1:size(tmpUnrolled, 2), edgeCoordsInn, 'ow')
    plot(ax, 1:size(tmpUnrolled, 2), edgeCoordsOut, 'or')
    plot(ax, 1:size(tmpUnrolled, 2), edgeCoordsInnS, 'w')
    plot(ax, 1:size(tmpUnrolled, 2), edgeCoordsOutS, 'r')

%     plot(1:size(unrolled,2), innerBnd, 'or')
%     plot(1:size(unrolled,2), innerBnd1, 'r')

end

