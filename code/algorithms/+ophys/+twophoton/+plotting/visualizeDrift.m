function [f, results] = visualizeDrift(data)
%visualizeDrift Visualize the drift occuring throughout a stack of images
%
%   INPUT:
%       avgProjImageArray : a 3D image array with an average projection for
%           each of a set of subparts of an imageStack (downsampled binned
%           average)
%
%    -or:
%       driftSummary : struct outputted by ophys.twophoton.analysis.computeDriftSummary
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
%
%   See also ophys.twophoton.analysis.computeDriftSummary

    
    if isnumeric(data)
        results = ophys.twophoton.analysis.computeDriftSummary(data);
    elseif isstruct(data)
        results = data;
    end

    % todo: Check results...
    numParts = results.NumParts;


    % Specify configuration for figure
    MARGIN = 50;
    SPACING = 20;

    figSize = [900,600];

    yHeightU = 0.75;
    yHeightL = 0.25;
    yHeightPix = (figSize(2)-MARGIN*2-SPACING*4) .* [yHeightU, yHeightL];


    fprintf('Plotting data...'); fprintf(newline)
    
    % Create figure
    f = figure('MenuBar', 'none', 'Position', [100,100,figSize]);
    f.Name = sprintf('Drift visualization');
    
    % Setup axes layout and create axes
    figSize = getpixelposition(f);
    [xU, wU] = uim.utility.layout.subdividePosition(MARGIN, figSize(3)-MARGIN*2, [0.5,0.5], SPACING);
    [xL, wL] = uim.utility.layout.subdividePosition(MARGIN, figSize(3)-MARGIN*2, [1, yHeightPix(2)], SPACING*4);
    [y, h] = uim.utility.layout.subdividePosition(MARGIN, figSize(4)-MARGIN*2, [0.25,0.75], SPACING*2);
    
    ax = matlab.graphics.axis.Axes.empty;
    ax(1) = axes(f, 'Units', 'pixels', 'Position', [xU(1), y(2), wU(1), h(2)]);
    ax(2) = axes(f, 'Units', 'pixels', 'Position', [xU(2), y(2), wU(2), h(2)]);
    ax(3) = axes(f, 'Units', 'pixels', 'Position', [xL(1), y(1), wL(1), h(1)]);
    ax(4) = axes(f, 'Units', 'pixels', 'Position', [xL(2), y(1), wL(2), h(1)]);
    
    % Plot first and last image overlaid
    image(ax(1), results.ImagesMerged )
    ax(1).Title.String = 'First and last part overlaid';
    ax(1).CLim = [0,255];

    % Plot difference between first and last image
    imagesc(ax(2), results.ImagesDiff)
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
    plot(ax(3), results.ImageCorrelations(:, 1))
    ax(3).XLim = [1, numParts];
    ax(3).YLabel.String = 'Image Correlation';

    yyaxis(ax(3), 'right')

    normalizeMean = @(x) x ./ results.PeakFluorescence;

    meanFNorm = normalizeMean( results.MeanFluoresence ) ;
    meanFSmoothNorm = normalizeMean( results.MeanFluoresenceSmooth );

    plot(ax(3), meanFNorm  )
    hold(ax(3), "on")
    plot(ax(3), meanFSmoothNorm )
    
    ax(3).Title.String = 'Stability throughout recording';
    ax(3).YLabel.String = 'Mean Fluorescence (% of peak)';
    ax(3).XLabel.String = 'Recording part number';

    ax(3).Title.String = 'Pairwise Image Correlations';
    imagesc(ax(4), results.ImageCorrelations)
    colormap(ax(4), 'viridis')
    %axis(ax(4), 'image')
    %set([ax(4).XAxis], 'Visible', 'off')
    %set([ax(4).YAxis], 'Visible', 'off')
    set(ax, 'Units', 'normalized')

    if nargout < 1; clear f;       end
    if nargout < 2; clear results; end

end