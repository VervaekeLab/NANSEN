function [mask, stat] = findRoiMaskFromImage(im, center, origImSize, varargin)


% quantify ratio of brightness inside donut vs inside nucleus
% quantify the edgemagnitude.
% quantify uniformness of edges and brightness inside donut

    def = struct('method', 'donut', 'output', 'mask', 'us', 4);
    opt = utility.parsenvpairs(def, [], varargin);

    imSizeSmall = size(im);
    
    %Upsample and smooth image.
    upSampleFactor = opt.us;
    im = imresize(im, upSampleFactor);
    imSize = size(im);
    
    
    numImages = size(im, 3);
    
    % Unroll the image for easier circular edge detection...
    unrolled = stack.reshape.imunroll(im);

    % Filter image
    for i = 1:numImages
        unrolled(:, :, i) = imgaussfilt(unrolled(:, :, i), 1);
    end

    % Create the gradient image for edge detection.
    grad = diff(double(unrolled));
    
    method = opt.method; % disk
    showPlot = false;
    
    
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
    
    switch opt.output
        case 'mask'
            mask = zeros([origImSize(1:2), numImages], 'logical');
        case 'coords'
            mask = repmat({zeros(0,2)}, 1, numImages);
    end
    
    
    for i = 1:numImages
        
        tmpUnrolled = unrolled(:, :, i);
        tmpGradient = grad(:, :, i);
    
        switch method
            case 'disk'
                [edgeCoordsOut, statOut] = findEdge(tmpGradient, 'fall');
                if isempty(edgeCoordsOut); continue; end
                edgeCoordsOutS = utility.circularsmooth(edgeCoordsOut, 2*upSampleFactor);

                edgeCoordsOutS(edgeCoordsOutS<1)=1;
                edgeCoordsOutS(edgeCoordsOutS>size(grad,1))=size(grad,1);

                edgeCoordsInnS = edgeCoordsOutS - 5;
                centerLine = mean([edgeCoordsInnS', edgeCoordsOutS'], 2);
                
                
            case 'donut'
                [edgeCoordsInn, statInn] = findEdge(tmpGradient, 'rise');
                if isempty(edgeCoordsInn); continue; end
                edgeCoordsInnS = utility.circularsmooth(edgeCoordsInn, max([1, 2*upSampleFactor]));

                lowerLim = floor(min(edgeCoordsInnS));
                newIm = nan(size(tmpGradient) - [lowerLim, 0]);

                for j = 1:size(grad,2)
                    values = tmpGradient(round(edgeCoordsInn(j)):end, j);
                    newIm(1:numel(values), j) = values;
                end
                
                offset = 3; % Hardcoded value for thy1 somas...

                % Offset is supposed to keep search close to internal
                % border. Expand search area a factor of 0.75 times the
                % internal radius:
                offset = round( mean(edgeCoordsInnS) ./ upSampleFactor .* 1); 
                
                h = min([size(newIm,1), offset*upSampleFactor ]);% why 3??????? parameterize
                newIm = newIm(1:h, :);
                
                [edgeCoordsOut, statOut] = findEdge(newIm, 'fall');
                if isempty(edgeCoordsOut); continue; end
                
                edgeCoordsOut = edgeCoordsOut+edgeCoordsInnS;
                edgeCoordsOutS = utility.circularsmooth(edgeCoordsOut, max([1, 2*upSampleFactor]));

                edgeCoordsOutS(edgeCoordsOutS<1)=1;
                edgeCoordsOutS(edgeCoordsOutS>size(grad,1))=size(grad,1);

                centerLine = mean([edgeCoordsInnS', edgeCoordsOutS'], 2);

        end



        if showPlot
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

    %         plot(1:size(unrolled,2), innerBnd, 'or')
    %         plot(1:size(unrolled,2), innerBnd1, 'r')
        end


        % Scale back (spatial down sample)
        innerRadius = edgeCoordsInnS ./ upSampleFactor;
        outerRadius = edgeCoordsOutS ./ upSampleFactor;

        outerRadius = outerRadius+0.5; % Add small offset

        % Transform back to cartesian coordinates
        theta = 0 : (360 / (size(unrolled, 2))) : 360;

        [xi, yi] = pol2cart(deg2rad(theta(1:end-1)), outerRadius);

        
        
        x = center(i, 1); y = center(i, 2);
        switch opt.output
            case 'mask'
                mask(:, :, i) = poly2mask(x+xi-0.25, y-yi-0.25, origImSize(1), origImSize(2));
            case 'coords'
                xOffset = imSizeSmall(2)/2; % min(xi);
                yOffset = imSizeSmall(1)/2; % min(yi);
                xi = xi + xOffset; yi = yi + yOffset;
                
                bwTmp = poly2mask(xi, yi, imSizeSmall(1), imSizeSmall(2));
                [Y, X] = find(bwTmp);   
                
                offsetCorrection = -0.5;
                
                xCoords = x+X-xOffset + offsetCorrection;
                yCoords = y-Y+yOffset + offsetCorrection;
                
                keepX = xCoords >= 1 & xCoords <= origImSize(2); 
                keepY = yCoords >= 1 & yCoords <= origImSize(1);
                keep = keepX & keepY;
                
                mask{i} = [xCoords(keep), yCoords(keep)];
        end
        
        

        % Create some stat values:
        imCenter = fliplr( imSize(1:2)./2 );
        x = imCenter(1); y = imCenter(2);


        [xi, yi] = pol2cart(deg2rad(theta(1:end-1)), edgeCoordsOutS);
        stat(i).outerEdge = [x+xi', y-yi'];

        maskSoma = poly2mask(x+xi-0.25, y-yi-0.25,  imSize(1), imSize(2));

        [xi, yi] = pol2cart(deg2rad(theta(1:end-1)), edgeCoordsInnS);
        stat(i).innerEdge = [x+xi', y-yi'];

        maskNucl = poly2mask(x+xi-0.25, y-yi-0.25,  size(im,1),  size(im,2));


        stat(i).nucleusValue = median(mean(im(maskNucl)));
        stat(i).donutValue = median(mean(im(maskSoma &~ maskNucl)));
        stat(i).surroundValue = median(mean(im(~maskSoma)));
        
        stat(i).innerStrength = statInn.EdgeValue;
        stat(i).outerStrength = statOut.EdgeValue;


        indCenter = sub2ind(size(tmpUnrolled), round(centerLine), (1:size(tmpUnrolled,2))');
        indInner = sub2ind(size(tmpUnrolled), round(edgeCoordsInnS)', (1:size(tmpUnrolled,2))');
        indOuter = sub2ind(size(tmpUnrolled), round(edgeCoordsOutS)', (1:size(tmpUnrolled,2))');

        VAL = double(tmpUnrolled(indCenter));

        stat(i).uniformity = mean(VAL) ./ std(VAL);
        stat(i).variance = std(VAL);

        tf = ( VAL > mean(VAL)-std(VAL) &  VAL < mean(VAL)+std(VAL) );
        stat(i).uniformity = sum(tf) ./ numel(VAL);


        isRidge = tmpUnrolled(indCenter) > tmpUnrolled(indInner) & tmpUnrolled(indCenter) > tmpUnrolled(indOuter);
        stat(i).ridgeFraction = mean(isRidge);
        
    end

    
% % %     figure; plot(VAL)
% % %     hold on
% % %     ax = gca;
% % %     plot(ax.XLim, ones(1,2)*mean(VAL)-std(VAL));
% % %     plot(ax.XLim, ones(1,2)*mean(VAL)+std(VAL));

end


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


    % Find big jumps in coords


    if showPlot
        figure('Position', [300,300,300,300]); axes('Position', [0,0,1,1]);
        imagesc(grad); hold on
        plot(1:size(grad,2), edgeCoords, 'ow')
        p = polyfit(1:size(grad,2), edgeCoords, 2);
        y = polyval(p, 1:size(grad,2));
        plot(1:size(grad,2), y, 'w')
    end

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

end




% % % Older version of code

% % v = 0;
% % 
% %     if v==1
% % 
% %         [maxval, maxind] = max(double(unrolled));
% %         outerRadius = maxind + upSampleFactor;
% % 
% %     elseif v==2
% % 
% %         % Look for edges.
% %         grad = diff(double(unrolled));
% % 
% %         [~, outerBndA1] = min(grad);
% %         [~, outerBndA2] = min(grad .* double(unrolled(2:end,:))); % Weighted by brightess....
% %         [~, innerBnd] = max(grad);
% %         
% %         outerBndA = outerBndA1;
% %         outerBndB = outerBndA2;
% %         
% % %          isoutlier(outerBnd1, 'movmedian', 40)
% % %         TF = isoutlier(outerBndA1, 'gesd', 'ThresholdFactor', 1)
% % 
% % %         outerBndA( outerBndA > median(outerBndA) + std(outerBndA)) = nan;
% %         outerBndA = filloutliers(outerBndA, 'linear', 'gesd', 'ThresholdFactor', 1);
% %         outerBndB = filloutliers(outerBndB, 'linear', 'gesd', 'ThresholdFactor', 1);
% %         
% %         % Choose the one with smallest std...
% %         if false %std(outerBndA) > std(outerBndB)
% %             outerBndA = outerBndB;
% %         else
% %             
% %         end
% % 
% %         % Remove outliers and smooth data for the outer boundary
% %         baseline = utility.circularsmooth(outerBndA, 10, 'movmedian');
% %         outerBnd2 = outerBndA - baseline;
% %         outerBnd2 = filloutliers(outerBnd2, 'pchip', 'gesd', 'ThresholdFactor', 1);
% % 
% %         outerBnd1 = outerBnd2 + baseline;
% %         outerBnd1 = utility.circularsmooth(outerBnd1, 5, 'movmean');
% % 
% %         % Remove outliers and smooth data for the inner boundary
% %         baseline = utility.circularsmooth(innerBnd, 10, 'movmedian');
% %         innerBnd2 = innerBnd - baseline;
% %         innerBnd2 = filloutliers(innerBnd2, 'pchip', 'gesd', 'ThresholdFactor', 1);
% %         innerBnd1 = innerBnd2 + baseline;
% %         %innerBnd1 = utility.circularsmooth(innerBnd1, 5, 'movmean');
% % 
% %         if showPlot
% %             figure('Position', [300,300,300,300]); axes('Position', [0,0,1,1]);
% %             imagesc(unrolled); hold on
% %             imagesc(grad); hold on
% %             plot(1:size(unrolled,2), outerBndA1, 'ow')
% %             plot(1:size(unrolled,2), outerBnd1, 'r')
% %             plot(1:size(unrolled,2), innerBnd, 'or')
% %             plot(1:size(unrolled,2), innerBnd1, 'r')
% %         end
% % 
% %         innerRadius = innerBnd1 + upSampleFactor;
% %         outerRadius = outerBnd1 + upSampleFactor;
% %     end 

