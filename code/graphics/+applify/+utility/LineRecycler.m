classdef LineRecycler < applify.utility.abstract.GObjectRecycler
% A class for line recycling.
%
%   This class is useful in apps where the number of plotted lines are
%   large and where the plotted lines need to be updated fast.
%
%   See also applify.utility.abstract.GObjectRecycler
    
    properties
        LineWidth = 0.5;
        Color = 0.5 * ones(1,3)
    end
    
    methods
        
        function h = getLines(obj, n)
        %getLines Get a specified number of line objects
        %
        %   h = getLines(obj, n) returns a (n x 1) vector of line objects

            h = obj.getGobjects(n);
        end
    end

    methods (Access = protected)
    
        function h = createNewHandles(obj, n)
        %createNewHandles Create new line objects
            [xInit, yInit] = deal( nan(2, n) );
            lineProperties = obj.getPropertiesAsNameValuePairs();

            h = line(obj.ParentAxes, xInit, yInit, lineProperties{:});
        end
        
        function h = resetHandleData(~, h)
        %resetHandleData Reset the x- and y-data of line handles
            set(h, 'XData', nan, 'YData', nan)
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
    
    lineProvider = applify.utility.LineRecycler(ax);
        
    fprintf('Creating 2000 lines\n')
    tic; h = lineProvider.getLines(2000); toc

    fprintf('Recycling 2000 lines\n')
    tic; lineProvider.recycle(h); toc
    
    fprintf('Retrieving 2000 recycled lines\n')
    tic; h = lineProvider.getLines(2000); toc
end
