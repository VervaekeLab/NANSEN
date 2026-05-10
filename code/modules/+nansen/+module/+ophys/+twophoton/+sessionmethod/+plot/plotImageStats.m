function varargout = plotImageStats(sessionObj, varargin)
%Plot frame-wise image statistics for a two-photon recording.
%
%Use this when:
%- You want a fast quality-control view of brightness, saturation, or
%  acquisition instability across time.
%- You have an `ImageStats` data variable for the selected session.
%
%What happens:
%- NANSEN loads `ImageStats` and plots the mean pixel value per frame in
%  SignalViewer.
%- Optional shaded envelopes show the minimum/maximum range and configured
%  percentile ranges.
%
%Outputs:
%- No data are written; this method only opens an interactive plot.
    
    % % % Get struct of default parameters for function.
    params = getDefaultParameters();
    
    % % % Initialization block for a session method function.
    ATTRIBUTES = {'serial', 'unqueueable'};
    settings = nansen.session.SessionMethod.setAttributes(params, ATTRIBUTES{:});
    
    if ~nargin && nargout > 0
        varargout = {settings};   return
    end
    
    % % % Parse name-value pairs in function input.
    params = utility.parsenvpairs(params, [], varargin);
    
    % % % Implementation of the session method
    S = sessionObj.loadData('ImageStats');
    S = S{1,1};
    
    hViewer = signalviewer.App(timeseries(S.meanValue, 'Name', 'Mean Fluorescence'));
    hLine = hViewer.getHandle('Mean Fluorescence');
    set(hLine, 'LineWidth', 1.5)

    hViewer.Axes.YLim = [0, max(S.maximumValue) .* 1.1];
    hViewer.YLimExtreme.left = hViewer.Axes.YLim;

    %f = figure;
    %ax = axes(f);
    
    %hold(h.Axes, 'on')
    
    %plot(ax, S.meanValue)
    
    cmap = magma(4);
    axes(hViewer.Axes)
    
    if params.ShowExtremes
        assertHasShadedErrorBar()
        lowerBound = (S.meanValue - S.minimumValue)';
        upperBound = (S.maximumValue - S.meanValue)';
        h = shadedErrorBar([], S.meanValue, [upperBound; lowerBound], 'lineprops',{'color', cmap(:,1)});
        set(h.patch, 'HitTest', 'off', 'PickableParts', 'none')
        drawnow

%       hViewer.addTimeseries( timeseries(S.minimumValue, 'Name', 'Minimum Level'))
%       hViewer.addTimeseries( timeseries(S.maximumValue, 'Name', 'Maximum Level'))
    end
    uistack(hLine, 'top')
    
    if params.ShowPrctile1
        assertHasShadedErrorBar()
        lowerBound = (S.meanValue - S.prctileL1)';
        upperBound = (S.prctileU1 - S.meanValue)';
        h = shadedErrorBar([], S.meanValue, [upperBound; lowerBound], 'lineprops',{'color', cmap(:,2)});
        set(h.patch, 'HitTest', 'off', 'PickableParts', 'none')
        drawnow
    end
    uistack(hLine, 'top')

    if params.ShowPrctile2
        assertHasShadedErrorBar()
        lowerBound = (S.meanValue - S.prctileL2)';
        upperBound = (S.prctileU2 - S.meanValue)';
        h = shadedErrorBar([], S.meanValue, [upperBound; lowerBound], 'lineprops',{'color', cmap(:,3)});
        set(h.patch, 'HitTest', 'off', 'PickableParts', 'none')
        drawnow
    end
    uistack(hLine, 'top')

end

function params = getDefaultParameters()
    params = struct();
    params.ShowExtremes = true; % Show the minimum-to-maximum pixel range.
    params.ShowPrctile1 = true; % Show the first configured percentile envelope.
    params.ShowPrctile2 = true; % Show the second configured percentile envelope.
end

function assertHasShadedErrorBar()
    assert( exist('shadedErrorBar', 'file') == 2, ...
        'This method requires shadedErrorBar from MATLAB FileExchange')
end