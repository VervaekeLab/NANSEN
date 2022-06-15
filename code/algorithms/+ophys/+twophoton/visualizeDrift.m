function [f, results] = visualizeDrift(avgProjImageArray)
%visualizeDrift Visualize the drift occuring throughout a stack of images
%
%   INPUT:
%       avgProjImageArray : a 3D image array with an average projection for
%           each of a set of subparts of an imageStack (downsampled binned
%           average)
%
%   This function displays two different images and two timeseries signals
%       1) Image where first and last image of a stack is merged using two
%          different colors.
%       2) Image showing the difference between the first and the last
%          image of a stack
%       3) Image correlations: The correlation of each image of the stack
%          with the first image of the stack.
%       4) Mean fluorescence: The mean fluorescence level in each image of
%          the stack.


    numParts = size(avgProjImageArray, 3);

    fprintf('Computing image frame statistics...'); fprintf(newline)
    meanFluorescence = mean(mean(avgProjImageArray, 1), 2);
    meanFluorescenceSmooth = smoothdata(meanFluorescence);

    getPercentileValues = @(IM, p) prctile(prctile(IM, p, 1), p, 2);
    
    %minFluorescence = getPercentileValues( avgProjectionImageArray, 5);
    maxFluorescence = getPercentileValues( avgProjImageArray, 95);
    maxFluorescenceSmooth = smoothdata(maxFluorescence);

    % Correct for mean fluorescence changes across the recording
    avgProjImageArray = avgProjImageArray ./ meanFluorescenceSmooth;
    
    imageCorrelation = zeros(1, numParts);
    
    fprintf('Computing image correlations...'); fprintf(newline)
    for i = 1:numParts
        imageCorrelation(i) = corr2(avgProjImageArray(:, :, 1), ...
                                    avgProjImageArray(:, :, i));
    end
    
    % Prepare images to plot
    avgProjImageArray = avgProjImageArray ./ sqrt(avgProjImageArray);       % Not sure if this is useful
    
    % Todo: Change colors
    cMapA = [1, 0.5, 0; 0, 0.5, 1];
    imageMerged = stack.colorCodeImageStack(avgProjImageArray(:, :, [1,end]), cMapA);
    
    imageMerged = imageMerged - min(imageMerged(:));
    imageMerged = uint8( imageMerged ./ max(imageMerged(:)) .* 255 );

    imageDiff = avgProjImageArray(:, :, 1) - avgProjImageArray(:, :, end);

    
    % Specify configuration for figure
    MARGIN = 50;
    SPACING = 20;

    fprintf('Plotting data...'); fprintf(newline)
    
    % Create figure
    f = figure('MenuBar', 'none', 'Position', [100,100,900,600]);
    f.Name = sprintf('Drift visualization');
    
    % Setup axes layout and create axes
    figSize = getpixelposition(f);
    [x, w] = uim.utility.layout.subdividePosition(MARGIN, figSize(3)-MARGIN*2, [0.5,0.5], SPACING);
    [y, h] = uim.utility.layout.subdividePosition(MARGIN, figSize(4)-MARGIN*2, [0.25,0.75], SPACING);
    
    ax = matlab.graphics.axis.Axes.empty;
    ax(1) = axes(f, 'Units', 'pixels', 'Position', [x(1), y(2), w(1), h(2)]);
    ax(2) = axes(f, 'Units', 'pixels', 'Position', [x(2), y(2), w(2), h(2)]);
    ax(3) = axes(f, 'Units', 'pixels', 'Position', [x(1), y(1), figSize(3)-MARGIN*2, h(1)]);

    % Plot first and last image overlaid
    image(ax(1), imageMerged )
    ax(1).Title.String = 'First and last part overlaid';
    ax(1).CLim = [0,255];

    % Plot difference between first and last image
    imagesc(ax(2), imageDiff)
    ax(2).Title.String = 'First and last part difference';

    % Set properties for axes showing images
    axis(ax(1:2), 'image')
    set([ax(1:2).XAxis], 'Visible', 'off')
    set([ax(1:2).YAxis], 'Visible', 'off')
    
    warning('off', 'MATLAB:griddedInterpolant:CubicUniformOnlyWarnId')      % Temp turn off warning from cbrewer
    cMapB = cbrewer('div', 'RdBu', 255); cMapB(cMapB<0)=0;
    warning('on', 'MATLAB:griddedInterpolant:CubicUniformOnlyWarnId')
    set(ax(2), 'Colormap', cMapB)
    
    % Plot the image correlations and the mean fluorescence throughout the
    % recording
    ax(3).Title.String = 'Image correlation w/ first part + mean fluorescence';
    plot(ax(3), imageCorrelation)
    ax(3).XLim = [1, numParts];
    ax(3).YLabel.String = 'Image Correlation';

    yyaxis(ax(3), 'right')
    plot(ax(3), squeeze( meanFluorescence ./ max(maxFluorescence) ) )
    hold(ax(3), "on")
    plot(ax(3), squeeze( meanFluorescenceSmooth ) )
    %plot(ax(3), squeeze( minFluorescence ) )
    %plot(ax(3), squeeze( maxFluorescence ) )

    ax(3).YLabel.String = 'Mean Fluorescence (% of max)';
    ax(3).XLabel.String = 'Recording part number';

    if ~nargout
        clear f
    end
        
    if nargout >= 2
        results = struct;
        results.NumParts = numParts;
        results.ImagesMerged = imageMerged;
        results.ImagesDiff = imageDiff;
        results.ImageCorrelations = imageCorrelation;
        results.MeanFluoresence = meanFluorescence;
        results.MeanFluoresenceSmooth = meanFluorescenceSmooth;
    end

end