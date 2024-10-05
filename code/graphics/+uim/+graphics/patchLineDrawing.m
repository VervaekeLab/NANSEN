function hP = patchLineDrawing(ax, im, varargin)

    def = struct('SmoothIter', 2, 'SmoothWindow', 10, 'cropImage', true, ...
        'plotType', 'polygon');
    
    opt = utility.parsenvpairs(def, [], varargin);
    
    % Crop image.
    if opt.cropImage
        [height, ~, ~] = size(im);

        A = arrayfun(@(i) find( im(i, :, 1) ~= 255, 1, 'first')-1, 1:height, 'uni', 0 );
        B = arrayfun(@(i) find( im(i, :, 1) ~= 255, 1, 'last')+1, 1:height, 'uni', 0);

        cropLeft = min([A{:}]);
        cropRight = max([B{:}]);
        if cropLeft == 0; cropLeft = 1; end
        if cropRight > size(im, 2); cropRight = size(im, 2); end

        im = im(:, cropLeft:cropRight, :);
        
        [~, width, ~] = size(im);

        C = arrayfun(@(i) find( im(:, i, 1) ~= 255, 1, 'first')-1, 1:width, 'uni', 0 );
        D = arrayfun(@(i) find( im(:, i, 1) ~= 255, 1, 'last')+1, 1:width, 'uni', 0 );

        cropTop = min([C{:}]);
        cropBot = max([D{:}]);
        if cropTop == 0; cropTop = 1; end
        if cropBot > size(im, 1); cropBot = size(im, 1); end

        im = im(cropTop:cropBot, :, :);
    end
    
    %% Get coordinates of edges
    BW = mean(im, 3) < 100;
    
    switch opt.plotType
        case 'polygon'
            hP = plotObjectsAsPolygons(ax, BW, opt);
        case 'patch'
            hP = patchObjects(ax, BW, opt);
    end
end

function hP = patchObjects(ax, BW, opt)
%patchObjects Plot binary objects using patches.

    % Get size of image
    imSize = [size(BW, 1), size(BW, 2)];
    
    [B, ~, N, A] = bwboundaries(BW);
    
    hP = gobjects(N, 1);
    
    % Loop through object boundaries (Example from bwboundaries doc)
    for k = 1:N
        
        [xDataOuter, yDataOuter] = getBoundary(B{k}, imSize, opt);
        if numel(xDataOuter) < 20; continue; end
        
        xData = xDataOuter; yData = yDataOuter;
        
        % Boundary k is the parent of a hole if the k-th column
        % of the adjacency matrix A contains a non-zero element
        if (nnz(A(:,k)) > 0)
            % Loop through the children of boundary k
            for l = find(A(:,k))'
                [xDataInner, yDataInner] = getBoundary(B{l}, imSize, opt);
                if isempty(xDataInner); continue; end
                
                % Have to insert to inner boundary so that it starts and
                % stops where the outer boundary starts and stops.
                distance = sqrt( (xDataInner(1)-xDataOuter).^2 + ...
                                 (yDataInner(1)-yDataOuter).^2 );
                
                [~, insertPoint] = min(distance);
                
                insertInd = find( xData == xDataOuter(insertPoint) );
                insertInd = insertInd(1);
                xData = cat(1, xData(1:insertInd), xDataInner, xData(insertInd:end));
                yData = cat(1, yData(1:insertInd), yDataInner, yData(insertInd:end));
            end
        end
        
        hP(k) = patch(ax, xData, yData, 'k');
    end
    
    keep = arrayfun(@(h) ~isa(h, 'matlab.graphics.GraphicsPlaceholder'), hP);
    hP = hP(keep);
    
    set(hP, 'EdgeColor', 'none')

end

function hP = plotObjectsAsPolygons(ax, BW, opt)
%plotObjectsAsPolygons Plot binary objects as polygons
    % Get size of image
    [imHeight, imWidth] = size(BW);

    % Get boundaries of binary objects
    CC = bwboundaries(BW);

    % Turn off warning that sometimes occurs for polyshapes..
    warning('off', 'MATLAB:polyshape:repairedBySimplify')
    
    %% Plot image/objects using polygon
    for i = 1:numel(CC)
        data = CC{i};
        
        if numel(data) < 20; continue; end
        
        % Center coordinates
        y = data(:,1) - imHeight/2; x = data(:,2) - imWidth/2;

        for j = 1:opt.SmoothIter
            y = utility.circularsmooth(y, opt.SmoothWindow, 'movmean');
            x = utility.circularsmooth(x, opt.SmoothWindow, 'movmean');
        end
        
        if i == 1 || ~exist('pgon', 'var')
            pgon = polyshape(x, y);
        else
            pgon = pgon.addboundary(x, y);
        end
    end
    
    warning('on', 'MATLAB:polyshape:repairedBySimplify')

    hP = plot(ax, pgon, 'FaceColor', 'k', 'FaceAlpha', 1, 'EdgeColor', 'none');
    
end

function [xData, yData] = getBoundary(B, imSize, opt)
    
    [xData, yData] = deal([]);
    
    B(end+1, :) = B(1, :);
    if numel(B) < 40; return; end

    xData = B(:,2) - imSize(2)/2;
    yData = B(:,1) - imSize(1)/2;
    
    for j = 1:opt.SmoothIter
        yData = utility.circularsmooth(yData, opt.SmoothWindow, 'movmean');
        xData = utility.circularsmooth(xData, opt.SmoothWindow, 'movmean');
    end
    
    xData(end+1) = xData(1);
    yData(end+1) = yData(1);

end
