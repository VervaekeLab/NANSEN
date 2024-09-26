function [A, C, centerOut] = addManualComponent(Y, A, C, center, roiRad, options)

% center : center coordinates of roi [x, y]

    defoptions = CNMFSetParms;
    if nargin < 6 || isempty(options); options = defoptions; end
    if ~isfield(options,'d1') || isempty(options.d1); options.d1 = input('What is the total number of rows? \n'); end          % # of rows
    if ~isfield(options,'d2') || isempty(options.d2); options.d2 = input('What is the total number of columns? \n'); end       % # of columns
    if nargin < 5 || isempty(roiRad)
        roiRad = 5;
    end
    
    roiRad = round(roiRad);

    [~,T] = size(C);

    % Select a square box of x and y pixels around center with radius r.
    % Make sure they are within the image, by shifting the box if
    % necessary.

    int_x = round(center(1)) + (-roiRad:roiRad);
    if int_x(1)<1
        int_x = int_x + 1 - int_x(1);
    end
    if int_x(end)>options.d1
        int_x = int_x - (int_x(end)-options.d1);
    end

    int_y = round(center(2)) + (-roiRad:roiRad);
    if int_y(1)<1
        int_y = int_y + 1 - int_y(1);
    end
    if int_y(end)>options.d2
        int_y = int_y - (int_y(end)-options.d2);
    end
            
    % Create a meshgrid, for the box specified by x and y and find
    % all the pixels within this square box.
    [INT_x,INT_y] = meshgrid(int_x,int_y);
    coor = sub2ind([options.d1,options.d2],INT_x(:),INT_y(:));
            
    % Crop image based on rectangle
    Ypatch = reshape(Y(int_x,int_y,:),(2*roiRad+1)^2,T);  % make it nPix x nFrames
    Y_res = Ypatch - A(coor,:)*C; % Subtract activity from other rois in the square???
    Y_res = bsxfun(@minus, Y_res, median(Y_res,2)); % same as Y_res-median(Y_res,2)
            
    [atemp, ctemp, ~, ~, newcenter, ~] = greedyROI(reshape(Y_res,2*roiRad+1,2*roiRad+1,T), 1, options); % Call greedy roi to initialize a and c.
            
    % Add the new components to the list of components!
    A(coor,end+1) = atemp/norm(atemp);
    C(end+1,:) = ctemp*norm(atemp);
    
    % Find new center based on the spatial component found by greedy roi.
    centerOut = com(A(:,end),options.d1,options.d2);

end
