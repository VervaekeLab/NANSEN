function varargout = plotImageStats(sessionObj, varargin)
%plotImageStats Plot stats from raw two photon recording
%
%   Plot mean pixel value for each frame with a shaded error bar
%   corresponding to a lower and an upper percentile of the pixel values.

    
    % % % Get struct of default parameters for function.
    params = getDefaultParameters();

    
    % % % Initialization block for a session method function.
    ATTRIBUTES = {'serial', 'nonqueueable'};
    settings = nansen.session.SessionMethod.setAttributes(params, ATTRIBUTES{:});
    
    if ~nargin && nargout > 0
        varargout = {settings};   return
    end
    
    
    % % % Parse name-value pairs in function input.
    params = utility.parsenvpairs(params, [], varargin);    
    
    
    % % % Implementation of the session method
    S = sessionObj.loadData('imageStats');
    
    hViewer = signalviewer.App(timeseries(S.meanValue, 'Name', 'Mean Fluorescence'));
        
    hViewer.Axes.YLim = [0, 2^16];

    %f = figure;
    %ax = axes(f); 
    
    %hold(h.Axes, 'on')
    
    %plot(ax, S.meanValue)
    
    cmap = magma(4);
    axes(hViewer.Axes)
    
    if params.ShowExtremes
        lowerBound = (S.meanValue - S.minimumValue)';
        upperBound = (S.maximumValue - S.meanValue)';
        h = shadedErrorBar([], S.meanValue, [upperBound; lowerBound], 'lineprops',{'color', cmap(:,1)});
        drawnow

%       hViewer.addTimeseries( timeseries(S.minimumValue, 'Name', 'Minimum Level'))
%       hViewer.addTimeseries( timeseries(S.maximumValue, 'Name', 'Maximum Level'))
    end
    
    if params.ShowPrctile1
        lowerBound = (S.meanValue - S.prctileL1)';
        upperBound = (S.prctileU1 - S.meanValue)';
        h = shadedErrorBar([], S.meanValue, [upperBound; lowerBound], 'lineprops',{'color', cmap(:,2)});
        drawnow
    end
    
    if params.ShowPrctile2
        lowerBound = (S.meanValue - S.prctileL2)';
        upperBound = (S.prctileU2 - S.meanValue)';
        h = shadedErrorBar([], S.meanValue, [upperBound; lowerBound], 'lineprops',{'color', cmap(:,3)});
        drawnow
    end
    

end


function S = getDefaultParameters()
    S = struct();
    S.ShowExtremes = true;
    S.ShowPrctile1 = true;
    S.ShowPrctile2 = true;
end