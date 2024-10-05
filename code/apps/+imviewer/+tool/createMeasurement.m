function M = createMeasurement(ax, type)

figH = ax.Parent;

switch type
    case 'line'
        impoints = cell(2, 1);
        hline = plot(ax, nan, nan,  '--', 'Color', ones(1,3)*0.5);
        hline.LineWidth = 1;
        hline.HitTest = 'off';
        tmpH = uicontrol('style', 'edit', 'Parent', figH, 'Visible', 'off');
        
        for i = 1:2
            impoints{i} = impoint(ax);
            impoints{i}.setColor(ones(1,3)*0.5);
            impoints{i}.addNewPositionCallback(@(pos)imPointMoved(pos, hline, i, tmpH));
        end

        impointPosition = cellfun(@(imp) imp.getPosition, impoints, 'uni', false);
        impointPosition = cell2mat(impointPosition);

        hline.XData = impointPosition(:, 1)';
        hline.YData = impointPosition(:, 2)';
        
        centerX = min(hline.XData) + abs(diff(hline.XData))/2;
        centerY = min(hline.YData) + abs(diff(hline.YData))/2;
        
end

[x, y] = ds2nfu(ax, centerX, centerY);
tmpH.Units = 'normalized';
tmpH.Position = [x+0.03, 1-y-0.02-0.03, 0.07, 0.04];
tmpH.Visible = 'on';

figH.WindowKeyPressFcn = {figH.WindowKeyPressFcn, @uiresumeKeyPress};
uiwait(figH)
figH.WindowKeyPressFcn = figH.WindowKeyPressFcn{1};

pos1 = impoints{1}.getPosition();
pos2 = impoints{2}.getPosition();

M.PixelLength = sqrt( (pos2(1)-pos1(1)).^2 + (pos2(2)-pos1(2)).^2 );
        
end

function imPointMoved(pos, hLine, i, tmpH)
    x = pos(1);
    y = pos(2);
    
    hLine.XData(i) = x;
    hLine.YData(i) = y;
    
    centerX = min(hLine.XData) + abs(diff(hLine.XData))/2;
    centerY = min(hLine.YData) + abs(diff(hLine.YData))/2;
    
    [x, y] = ds2nfu(gca, centerX, centerY);
    tmpH.Position(1:2) = [x+0.03, 1-y-0.02-0.03];
    
end

function uiresumeKeyPress(src, event)

    switch event.Key
        case 'return'
            uiresume(src)
    end
end
