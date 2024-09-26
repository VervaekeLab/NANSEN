function varargout = getIcon(iconName, outputFormat)

    if nargin < 2 || isempty(outputFormat)
        outputFormat = 'coords';
    end
    
    switch iconName
        
        case 'Play'
            xData = [0 0 1.5];
            yData = [1 -1 0];
        case 'Pause'
            xData = [0, 2/3;  1/3, 1; 1/3, 1;  0, 2/3];
            yData = [1,1; 1,1; -1,-1; -1,-1] .* 0.7;
                       
    end

    switch outputFormat
        case 'coords'
            varargout = {xData, yData};
            
        case 'polyshape'

% %             xData = [xData(:,1); nan; xData(:,2)];
% %             yData = [yData(:,1); nan; yData(:,2)];

            ps = polyshape([xData, yData]);

            S = struct();
            S.Shape = ps;
            S.Color = [1,1,1];
            
            varargout = {S};
    end
end
