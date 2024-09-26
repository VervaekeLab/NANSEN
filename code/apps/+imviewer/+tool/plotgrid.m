function h = plotgrid(ax, n)

if nargin < 2; n = 10; end

xLim = ax.XLim;
yLim = ax.YLim;

xPoints = linspace(xLim(1),xLim(2),n);
yPoints = linspace(yLim(1),yLim(2),n);

xData1 = cat(1, xPoints, xPoints);
yData1 = [repmat(yLim(1), 1, n); repmat(yLim(2), 1, n)];
xData2 = [repmat(xLim(1), 1, n); repmat(xLim(2), 1, n)];
yData2 = cat(1, yPoints, yPoints);

h = plot(ax, xData1, yData1, xData2, yData2, 'Color', ones(1,3)*0.5);

end
