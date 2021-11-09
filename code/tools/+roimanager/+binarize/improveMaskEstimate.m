function [score, mask, fH, imList, roiCand] = improveMaskEstimate(imData, tmpRoi, roiArray)

    % Important parameters in this function
    
    % width of mask that is accepted in x and y...
    % Calls function to binarize, and thresholding in that function is
    % important as well.

    if nargout>=3
        showResults = true;
    else
        showResults = false;
    end
    
    % get center and mask from temporary roi
    tmpMask = tmpRoi.mask;
    
    % Extract signal
    roiArray = cat(2, tmpRoi, roiArray);
    structArrayOfMasks = signalExtraction.prepareMasks(roiArray, 'standard', 1, []);

    roiUniqMask = structArrayOfMasks(1).unique;
    roiNpilMask = structArrayOfMasks(1).neuropil;
    F = signalExtraction.extractRoiFluorescence(imData, roiUniqMask, roiNpilMask, 'mean');

    roiF = squeeze(F(:,1,:));
    pilF = squeeze(F(:,2,:));

    F = squeeze(signalExtraction.dff.dffRoiMinusDffNpil(roiF, pilF));
    
    imSize = size(imData);

    % Get bounding box for small region surrounding roi.
    bbox = tmpRoi.getBBox(25);
    xCoords = bbox(1):bbox(2);
    yCoords = bbox(3):bbox(4);
    
    % Get the image data from this smaller region.
    imChunk = double(imData(yCoords, xCoords, :));
    chunkSize = size(imChunk);
    
    % Find samples in data with higher activity levels.
    thresholdA = mean(F) + std(double(F)) * 1;
    thresholdB = mean(F) + std(double(F)) * 2;
    thresholdB = min([250, thresholdB]);
    
    activeSamplesA = F > thresholdA;
    activeSamplesB = F > thresholdB;
    
    if sum(activeSamplesA) < 10
       [~, tmp] = sort(F);
       activeSamplesA = sort( tmp(end-60:end) );
    end
    
    
    if sum(activeSamplesB) < 10
       [~, tmp] = sort(F);
       activeSamplesB = sort( tmp(end-30:end) );
    end
    
    [rhoImA, pImA] = getPixelCorrelationImage(F, imChunk );
    [rhoImB, pImB] = getPixelCorrelationImage(F(activeSamplesA), imChunk(:,:,activeSamplesA) );
    [rhoImC, pImC] = getPixelCorrelationImage(F(activeSamplesB), imChunk(:,:,activeSamplesB) );
    
    meanImA = mean(imChunk, 3);
    meanImB = mean(imChunk(:,:,activeSamplesA), 3);
    meanImC = mean(imChunk(:,:,activeSamplesB), 3);

    correlationProd = rhoImA .* rhoImB .* rhoImC;

    pImB = abs(log(pImB));
    pImB = pImB - min(pImB(:));
    pImB(pImB == inf) = nan;
    pImB = pImB ./ max(pImB(:));
    pImB(isnan(pImB))=1;
    
    
    pImC = abs(log(pImC));
    pImC = pImC - min(pImC(:));
    pImC = pImC ./ max(pImC(:));
    
    % Go through all of these images and create masks.
    imList = {rhoImA, rhoImB, rhoImC, meanImB, meanImC, correlationProd, pImB, pImC};
    
    for i = 1:numel(imList)
        imList{i} = imList{i} ./ max(imList{i}(:));
    end
    
    imList{end+1} = mean(cat(3, imList{:}), 3);
    
    descr = {'Corr', 'corr_enhA', 'corr_enh_B', 'mean_enhA', 'mean_enh_B', 'corr_prod', 'p_enhA', 'p_enhB', 'mean_all'};
    masks = zeros([chunkSize(1:2), 9]);  
    
    roiCand = RoI.empty(0,9);
    
    mask = false(imSize(1:2));
    
    for i = 1:9
        masks(:, :, i) = getRoiMaskFromImage(imList{i});
        mask(yCoords, xCoords) = masks(:, :, i);

        if sum(mask)==0
            roiCand(1, i) = RoI('Circle', [mean(xCoords), mean(yCoords), 6], imSize(1:2));
        else
            roiCand(1, i) = RoI('Mask', mask, imSize(1:2));
        end
        roiCand(1, i).enhancedImage = stack.makeuint8(imList{i}, [min(imList{i}(:)), max(imList{i}(:))]);
    end
    
    if showResults
        fH = figure('Position', [1,200,800,300], 'Visible', 'off');
        AX = createAxesGrid(4, 9, [0.02, 0.05]);
        h = gobjects(9,1);
        for i = 1:9
            title(AX(1,i), descr{i})
            imagesc(AX(1,i), imList{i} ); 
            imagesc(AX(2,i), masks(:,:,i) );
            axis(AX(1,i), 'image'); axis(AX(2,i), 'image');
        end
        
        set([AX(2,:).XAxis], 'LineWidth', 1, 'Color', 'r')
        set([AX(2,:).YAxis], 'LineWidth', 1, 'Color', 'r')
    end

    
    % Compute a composite mask and score based on how well different masks
    % agree.
  
    [wX, wY] = deal(nan(9,1));
    [pX, pY] = deal(zeros(9,3));
    
    for i = 1:9
        
        if sum(sum(masks(:,:,i))) == 0; continue; end
        
        sumX = sum(masks(:, :, i), 1);
        sumY = sum(masks(:, :, i), 2);
        
        wX(i) = sum(sumX ~= 0);
        wY(i) = sum(sumY ~= 0);
        
        smoothX = smoothdata(sumX, 'movmean', 5);
        smoothY = smoothdata(sumY, 'movmean', 5); 
        
% %         pX(i,:) = polyfit( (1:chunkSize(2)), sumX, 2);
% %         pxFit = polyval(pX(i,:), 1:chunkSize(2) );
% %         
% %         if pxFit(1) < 0
% %             wX(i) = fwhm(1:chunkSize(2), smoothX);
% %         else
% %             wX(i) = nan;
% %         end
% % 
% %         pY(i,:) = polyfit( (1:chunkSize(1)), sumY', 2);
% %         pyFit = polyval(pY(i,:), 1:chunkSize(1) );
% %         
% %         if pyFit(1) < 0
% %             wY(i) = fwhm(1:chunkSize(1), smoothY);
% %         else
% %             wY(i) = nan;
% %         end

        if showResults
            plot(AX(3,i), sumX); hold(AX(3,i), 'on'); plot(AX(3,i), sumY)
            plot(AX(4,i), smoothX); hold(AX(4,i), 'on'); plot(AX(4,i), smoothY);
            set(AX, 'XLim', [1, chunkSize(2)], 'YLim', [1, chunkSize(1)])

        end
%         fprintf('wX = %.2f - wY = %.2f \n', wX(i), wY(i))
%         fprintf('px1 = %.2f - px2 = %.2f - px3 = %.2f || py1 = %.2f - py2 = %.2f - py3 = %.2f\n', Px(1), Px(2), Px(3), Py(1), Py(2), Py(3))
    
    end
    
    isValidA = ~isnan(wX) & ~isnan(wY);
%     isValid = isValid & wX < 25 & wY < 25;
    isValidB = wX < 17 & wY < 17;
    isValidC = wX > 5 & wY > 5;
    
    isValid = isValidA & isValidB & isValidC;
    
    if showResults
        set([AX(2,isValid).XAxis], 'LineWidth', 1, 'Color', 'g')
        set([AX(2,isValid).YAxis], 'LineWidth', 1, 'Color', 'g')
        set(AX, 'XTick', [], 'YTick', [])
    end
    
    masks = masks(:, :, isValid);
    
    mask = false(imSize(1:2));
    score = 0;

    if ~isempty(masks)
        maskSmall = median(masks, 3);
        maskSmall = pickLargestComponent(maskSmall);
        if sum(maskSmall(:)) < 25; return; end
        
%         maskSmall = getRoiMaskFromImage(imList{end}); % Use when doing
%         donut template detection
        B = bwboundaries(maskSmall);
        B = B{1};
        B(:, 1) = utility.circularsmooth(B(:,1), 5);
        B(:, 2) = utility.circularsmooth(B(:,2), 5);

        maskSmall = poly2mask(B(:, 2), B(:, 1), size(maskSmall,1), size(maskSmall,2));
        
        score = sum(isValid) / numel(isValid);
        mask(yCoords, xCoords) = maskSmall;
    end
    
    if nargout == 2
        delete(fH); clear(fH)
    end
    
end


% Estimate center of mass from mask (correlation)

% The run find boundaries on enhanced average and on correlation product



