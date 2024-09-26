classdef TextRecycler < applify.utility.abstract.GObjectRecycler
% A class for text recycling.
%
%   This class is useful in apps where the number of plotted text objects
%   are large and where the plotted text need to be updated fast.
%
%   See also applify.utility.abstract.GObjectRecycler

    properties
        FontSize = 10;
        FontUnits = 'pixels'
        Color = 0.5 * ones(1,3)
    end
    
    methods
        
        function h = getTextHandles(obj, n)
        %getTextHandles Get a specified number of text objects
        %
        %   h = getTextHandles(obj, n) returns a (n x 1) vector of text objects

            h = obj.getGobjects(n);
        end
    end

    methods (Access = protected)
    
        function h = createNewHandles(obj, n)
        %createNewHandles Create new line objects
            [xInit, yInit] = deal( zeros(n, 1) );
            textProperties = obj.getPropertiesAsNameValuePairs();

            h = text(obj.ParentAxes, xInit, yInit, '', textProperties{:});
        end
        
        function h = resetHandleData(~, h)
        %resetHandleData Reset the x- and y-data of line handles
            set(h, 'Position', [nan, nan])
        end
    end

    methods (Static)
        function speedtest()
            performanceTest()
        end
    end
end

function performanceTest()

    f = figure;
    ax = axes(f);
    
    textProvider = applify.utility.TextRecycler(ax);
        
    fprintf('Creating 2000 text handles\n')
    tic; h = textProvider.getTextHandles(2000); toc

    fprintf('Recycling 2000 text handles\n')
    tic; textProvider.recycle(h); toc
    
    fprintf('Retrieving 2000 recycled text handles\n')
    tic; h = textProvider.getTextHandles(2000); toc
end
