function hText = showBrainMapLabels(hAxes, leftOrRight, varargin)

% % % Note: LabelDetails is not implemented
% % param = struct('LabelDetails', 'fine'); % fine or coarse
% % param = parsenvpairs(param, [], varargin);

if nargin < 1
    tmpFig = brainmap.paxinos.open();
    hAxes = gca;
    leftOrRight = 'both';
    h = findobj(tmpFig, 'Type', 'Polygon');

else
%     tmpFig = openfig(fileName, 'Invisible');
%     h = findobj(tmpFig, 'Type', 'Polygon');
    h = findobj(hAxes, 'Type', 'Polygon');
end

xLimOrig = getappdata(hAxes, 'XLimOrig');
yLimOrig = getappdata(hAxes, 'YLimOrig');

xMin = xLimOrig(1);
yMin = yLimOrig(1);

xRange = range( xLimOrig );
yRange = range( yLimOrig );

m = 100; % Magnification?
regionAreaMax = 40675;

hText = gobjects(size(h));
count = 0;

for i = 1:numel(h)
    if ~isempty(h(i).Tag)
       
        % Find center of mass for placement of text.
        edge = h(i).Shape.Vertices;
        x = (edge(:,1) - xMin)*m;
        y = (edge(:,2) - yMin)*m;

        x(isnan(x))=[];
        y(isnan(y))=[];

        BW = poly2mask(x, y, yRange*m, xRange*m);

        stats = regionprops(BW, 'Centroid', 'Area');
        pos = stats.Centroid/100 + [xMin,yMin];

        regionArea = stats.Area;
%        pos = mean(h(i).Shape.Vertices);

        switch leftOrRight
            case 'left'
                if pos(1)>0; continue; end
            case 'right'
                if pos(1)<0; continue; end
        end
       
        switch h(i).Tag
            case 'V2MM'
                pos(2) = pos(2)+0.4;
        end

        count = count+1;
        hText(count) = text(hAxes, pos(1), pos(2), h(i).Tag, 'HorizontalAlignment', 'center', 'Color', ones(1,3)*0.2, 'FontSize', 8 + round(6*regionArea./regionAreaMax));
    end
end

if nargout
    hText = hText(1:count);
end

%if nargin < 1; close(tmpFig); end

end
