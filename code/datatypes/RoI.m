classdef RoI
% ROI Region of Interest object.
%   Holds information of the indices of a picture that is the actual
%   region of interest. The center is the mean of the index values and
%   not weighted. 

% Proposed added properties
%
% pixelunits      : size of pixel in micrometer.
% pixelidxlist    : index in the smallest rectangle that contains the roi


% Todo:

properties (Constant, Hidden)
    MaskWeightCutoff = 0
end

properties
    uid                         % Unique ID of RoI
    num                         % Number of RoI in list of RoIs. 
    shape                       % Alternatives: Polygon, Circle, Mask.
    coordinates                 % Corners, center and radius or pixel coordinates (x, y) (depends on shape)
    pixelweights                %
    imagesize                   % Size of image where RoI was created (y,x)
    center                      % Mean center of RoI in image in cartesian coordinates (x, y)
    area                        % Area or number of pixels of RoI
    boundary = cell(0)          % Boundary points of RoI (y, x)
    connectedrois = cell(0)     % A list of uid of connected RoIs
    parentroi = cell(0)         % A uid of parent RoIs
    group                       % 
    celltype                    % Neuron, Astrocyte, other?
    structure = 'na'            % Axon, Dendrite, Endfoot, Vein, Artery, Capillary
    xyz                         % X, y and z coordinates relative to a reference point, e.g. bregma
    region = ''                 % Region of the brain where the RoI is drawn 
    layer = ''                  % Layer of cortex
    tags = cell(0,1)            % User defined tags. E.g 'overexpressing', 'excitatory', 'tuned' 
    enhancedImage = [];         % Enhanced ROI image for all ROIs can be added to the roiArray
% %     enhancedImageMask = [];     % A small ROI mask which fits the enhancedImage can also be saved for all ROIs
end

% properties (Transient)
%     Info
%     ThumbnailImage
%     Stats
% end

properties (Access = private, Hidden)
    ApplicationData struct = struct()
end


properties ( Hidden = true, Transient = true )
    ID = []  
    Tag
    Group
    CorticalLayer = 'n/a'
    Shape
    Center
    Channel = 0
    PixelsX = []
    PixelsY = []
    imPointsX
    imPointsY
    Selected
    Boundary = cell(0)
    Weights = []
    WeightType
    ImageDimX
    ImageDimY
    nFrames
    Mask
    ResX = 1
    ResY = 1
    Version = 'v1.0'
end


properties ( Dependent = true, Transient = true )
    tag
    mask        % Boolean mask of RoI
end


methods
    
    
    function obj = RoI(shape, coordinates, imSize)
        % RoI Constructor. Create a RoI object of specified shape.
        %   roi = RoI(SHAPE, COORDINATES, IMSIZE) creates a RoI object of
        %   specifed SHAPE based on COORDINATES. IMSIZE is the size of
        %   the image where the roi is created, in nRows, nCols
        %
        %   SHAPE (str): 'Polygon' | 'Circle' | 'Mask'
        %   COORDINATES: Depends on the shape:
        %       'Polygon'   : nx2 vector of polygon corner coordinates
        %       'Circle'    : 1x3 vector of x_center, y_center, radius
        %       'Mask'      : nRow x nCol logical array 
        %   IMDIM (double): 1x2 vector ([nRows, nCols]) 

        if nargin < 1
            return
        end
        
        if nargin < 3 && (strcmp(shape, 'Mask') || strcmp(shape, 'IMask'))
            [h, w, ~] = size(coordinates);
            imSize = [h, w];
        end

        if ~islogical(coordinates)
            imSize = cast(imSize, 'like', coordinates);
        end

        % Set coordinates and shape
        obj.shape = shape;
        obj = setCoordinates(obj, coordinates);
        
        % Create a unique ID for the roi.
        obj.uid = nansen.util.getuuid();
        
        % Set image size
        obj.imagesize = imSize;

        % Calculate other properties
        obj = setBoundaries(obj);
        obj = findCenter(obj);
        obj = setArea(obj);
        
    end
    
    
% % Methods for changing the spatial position/shape of the roi
    
    function obj = move(obj, shift, imageUpdateMethod)
    %move Move RoI according according to specified shifts
    %
    %   Shift is a 1x2 vector of where the first element is the number of
    %   pixels to shift the RoI along x-direction (dx) and the second 
    %   element is the number of pixels to shift the RoI in the y-direction
    %   (dy).
    
        if nargin < 3; imageUpdateMethod = 'resetImage'; end
    
        nRois = numel(obj);
        dydx = fliplr(shift);

        for i = nRois:-1:1

            switch obj(i).shape
                case {'Polygon', 'Mask', 'Donut'}
                    obj(i).coordinates = obj(i).coordinates + shift;
% %                 case 'Mask'
% %                     obj(i).translateMaskSubPixel(shift);
                case 'Circle'
                    obj(i).coordinates = obj(i).coordinates + [shift, 0];
            end

            % Update boundary and center
            obj(i).boundary = cellfun(@(b) b+dydx, obj(i).boundary, 'uni', 0);
            obj(i).center = obj(i).center + shift;
            obj(i) = obj(i).updateImage(imageUpdateMethod, shift);

        end
        
    end
    
    
    function obj = translateMaskSubPixel(obj, shift)
        
        % This is not a good idea. if repreated many times, mask will tend
        % to reshape into a rectangle
        
        Bx = obj.boundary{1}(:,2);
        By = obj.boundary{1}(:,1);
        
        Bx = Bx - obj.center(1);
        By = By - obj.center(2);
        
        [theta, rad] = cart2pol(Bx, By);
        [Bx, By] = pol2cart(theta, rad+0.5);
        
        Bx = Bx + obj.center(1) + shift(1);
        By = By + obj.center(2) + shift(2);
        
        shiftedMask = poly2mask(Bx, By, obj.imagesize(1), obj.imagesize(2));
        obj = obj.setCoordinates(shiftedMask);
        
    end
    
    
    function obj = reshape(obj, shape, coordinates, imageUpdateMethod)
    %reshape Reshape a RoI based on new input coordinates
        
        if nargin < 4; imageUpdateMethod = 'resetImage'; end

        oldCenter = obj.center;
    
        if ~isempty(shape)
            obj.shape = shape;
        end
        obj = setCoordinates(obj, coordinates);
        
        % Update boundary, center and area
        obj = setBoundaries(obj);
        obj = findCenter(obj);
        obj = setArea(obj);
        
        % Calculate the shift of the roi
        newCenter = obj.center;
        shift = newCenter-oldCenter;
            
        % Update the roi image
        obj = obj.updateImage(imageUpdateMethod, shift);
        
    end
    
    
    function obj = grow(obj, npixels)
    %grow Grow a RoI by n pixels
            
    
        switch obj.shape
            case 'Circle'
                obj.coordinates(3) = obj.coordinates(3) + npixels;
            
            case 'Polygon'
                xedge = obj.coordinates(:, 1); xcenter = obj.center(1);
                yedge = obj.coordinates(:, 2); ycenter = obj.center(2);
                
                % Calculate angle in polar for each edge point.
                theta = atan2(yedge-ycenter, xedge-xcenter);
                
                % Calculate radius for each edge point
                radius = sqrt( (yedge-ycenter).^2 + (xedge-xcenter).^2);
                newRadius = radius + npixels;
                obj.coordinates(:, 1) = xcenter + cos(theta) .* newRadius;
                obj.coordinates(:, 2) = ycenter + sin(theta) .* newRadius;
                
            case {'Mask', 'Donut'}

                for i = 1:npixels
                    ycenter = round(obj.center(2));
                    tmpMask = obj.mask;
                    radius = round(sum(tmpMask(ycenter, :))/2); % equator..

                    % Define neighborhood for mask dilation.
                    if mod(radius, 2) == 0 
                        % Imdilate 1 pixel in each direction: N, E, S, W.
                        nhood = [0,1,0;1,1,1;0,1,0];
                    elseif mod(radius, 2) == 1
                        % Imdilate 1 pixel in each direction:  NE, SE, SW, NW
                        nhood = [1,0,1;0,1,0;1,0,1];
                    end

                    if strcmp(obj.shape, 'Donut')
                        filledMask = imfill(tmpMask, 'holes');
                        nucleusMask = xor(tmpMask, filledMask);

                        filledMask = imdilate(filledMask, nhood);
                        nucleusMask = imdilate(nucleusMask, nhood);

                        tmpMask = filledMask & ~nucleusMask;
                    else
                        tmpMask = imdilate(tmpMask, nhood);
                    end
                
                    obj = obj.setCoordinates(tmpMask);
                end

%                 obj.coordinates = sparse(imdilate(tmpMask, nhood));
        end
        
        % Calculate other properties
        obj = setBoundaries(obj);
        obj = findCenter(obj);
        obj = setArea(obj);
%         obj.enhancedImage = [];


    end
    
    
    function obj = shrink(obj, npixels)
    %shrink Shrink a RoI by n pixels 
        
        switch obj.shape
            case 'Circle'
                obj.coordinates(3) = obj.coordinates(3) - npixels;
                
            case 'Polygon'
                xedge = obj.coordinates(:, 1); xcenter = obj.center(1);
                yedge = obj.coordinates(:, 2); ycenter = obj.center(2);
                
                % Calculate angle in polar for each edge point.
                theta = atan2(yedge-ycenter, xedge-xcenter);
                
                % Calculate radius for each edge point
                radius = sqrt( (yedge-ycenter).^2 + (xedge-xcenter).^2);
                newRadius = radius - npixels;
                obj.coordinates(:, 1) = xcenter + cos(theta) .* newRadius;
                obj.coordinates(:, 2) = ycenter + sin(theta) .* newRadius;
                
            case {'Mask', 'Donut'}
                ycenter = round(obj.center(2));
                tmpMask = obj.mask;
                radius = round(sum(tmpMask(ycenter, :))/2); % equator..

                % Define neighborhood for mask dilation.
                if mod(radius, 2) == 0 
                    % Imdilate 1 pixel in each direction: N, E, S, W.
                    nhood = [0,1,0;1,1,1;0,1,0];
                elseif mod(radius, 2) == 1
                    % Imdilate 1 pixel in each direction:  NE, SE, SW, NW
                    nhood = [1,0,1;0,1,0;1,0,1];
                end
                
                if strcmp(obj.shape, 'Donut')
                    filledMask = imfill(tmpMask, 'holes');
                    nucleusMask = xor(tmpMask, filledMask);
                    
                    filledMask = imerode(filledMask, nhood);
                    nucleusMask = imerode(nucleusMask, nhood);
                    
                    tmpMask = filledMask & ~nucleusMask;
                else
                    tmpMask = imerode(tmpMask, nhood);
                end
                
                obj = obj.setCoordinates(tmpMask);
        end
        
        % Calculate other properties
        obj = setBoundaries(obj);
        obj = findCenter(obj);
        obj = setArea(obj);
%         obj.enhancedImage = [];

    end
    
    
    function obj = goDonuts(obj, thickness)
        
        if nargin < 2; thickness = 1; end
        
        border = round(obj.boundary{1});

        ind = sub2ind(obj.imagesize, border(:, 1), border(:, 2));
        tmpMask = false(obj.imagesize);
        tmpMask(ind) = true;

        for i = 1:thickness
        
           if mod(i, 2) == 0 
                % Imdilate 1 pixel in each direction: N, E, S, W.
                nhood = [0,1,0;1,1,1;0,1,0];
                tmpMask = imdilate(tmpMask, nhood);

            elseif mod(i, 2) == 1
                % Imdilate 1 pixel in each direction:  NE, SE, SW, NW
                nhood = [1,0,1;0,1,0;1,0,1];
                tmpMask = imdilate(tmpMask, nhood);
           end
        end
        
        donutMask = obj.mask & tmpMask;

        % Set coordinates based on new mask.
        obj.shape = 'Donut';
        obj = obj.setCoordinates(donutMask);
        
        % Calculate other properties
        obj = setBoundaries(obj);
        obj = findCenter(obj);
        obj = setArea(obj);
        obj.enhancedImage = [];

    end
    
    
    function obj = updateImage(obj, imageUpdateMethod, shift)
    %updateImage Update roi image(s) when roi is translated.
    
    % Is there a better way to do this? Should roi images be a transient
    % property?
    
        if nargin < 3; shift = [0, 0]; end 

        switch imageUpdateMethod
            case 'resetImage' % Reset the roi image
                obj.enhancedImage = [];
                
            case 'shiftImage'
                % Shift image opposite direction of roi..
                dydx = -round(fliplr(shift));
                dxdy = -round(shift);
                
                if ~isempty(obj.enhancedImage)
                    obj.enhancedImage = circshift(obj.enhancedImage, dydx);
                    %obj.enhancedImage = imtranslate(obj.enhancedImage, dxdy);
                end
                
                imData = getappdata(obj, 'roiImages');
                if ~isempty(imData)
                    imageNames = fieldnames(imData);
                    for i = 1:numel(imageNames)
                        if ~isempty(imData.(imageNames{i}))
                            %imData.(imageNames{i}) = circshift(imData.(imageNames{i}), dydx);
                            imData.(imageNames{i}) = imtranslate(imData.(imageNames{i}), dxdy);
                        end
                    end
                    obj = setappdata(obj, 'roiImages', imData);
                end
        end
        
    end
    
    
    function bbox = getBBox(obj, size)
        
        if numel(size) == 1
            [width, height] = deal(size);
        elseif numel(size) == 2
            width = size(1); height = size(2);
        else
            error('Size must be a 1 or 2 element vector')
        end
        
        
        xLim = round(obj.center(1)) + [-ceil(width/2), floor(width/2)];
        yLim = round(obj.center(2)) + [-ceil(height/2), floor(height/2)];

        if xLim(1) < 1
            xLim = xLim + abs(xLim(1) - 1);
        elseif xLim(2) > obj.imagesize(2)
            xLim = xLim - (xLim(2) - obj.imagesize(2));
        end
        
        if yLim(1) < 1
            yLim = yLim + abs(yLim(1) - 1);
        elseif yLim(2) > obj.imagesize(1)
            yLim = yLim - (yLim(2) - obj.imagesize(1));
        end
        
        bbox = [xLim, yLim];

        
        
    end
    
    
    function [I, J] = getThumbnailCoords(obj, boxSize)
    %getThumbnailCoords Return image coordinates for a thumbnail picture.
    %
    % [I, J] = getThumbnailCoords(obj, boxSize) returns image coordinates
    % for a box of given boxSize centered on the current roi. I is the
    % x-coordinates  and J is the y-coordinates
    
        if nargin < 2
            boxSize = size(obj.enhancedImage);
        end
    
        assert(all( mod(boxSize,2)) ~= 0)
    
        indX = (1:boxSize(2)) - ceil(boxSize(2)/2);
        indY = (1:boxSize(1)) - ceil(boxSize(1)/2);
        centerCoords = obj.center;

        % Image coordinates for a square box centered on the roi
        I = round(indX + centerCoords(1));
        J = round(indY + centerCoords(2));
        
    end

% % Method for splitting roi.

    function roiBabies = split(obj, nPieces)
        tmpmask = obj.mask;
        newRoiMasks = signalExtraction.fissa.splitneuropilmask(tmpmask, tmpmask, nPieces);
        nBabies = size(newRoiMasks, 3);
        
        roiBabies(nBabies, 1) = RoI;
        for i = 1:nBabies
            roiBabies(i) = RoI('Mask', newRoiMasks(:,:,i), size(tmpmask));
            roiBabies(i).structure = obj.structure;
        end
    end        
    

    function obj = connect(obj, roi_uid_list)
    %connect Add connected RoIs to list of connected RoIs.
    %   obj.connect(roi_uid_list) add RoIs to list of connected RoIs. 
    %   roi_uid_list is a list of unique ids for RoIs to be connected.
        obj.connectedrois = cat(1, obj.connectedrois, roi_uid_list);
    end
    
    function obj = addParent(obj, roi)
        obj.parentroi = cat(2, obj.parentroi, {roi.uid});
    end
    
    function obj = addChildren(obj, roi)
        obj.connectedrois = cat(2, obj.connectedrois, {roi.uid});
    end
    
    function obj = removeParent(obj, roi)
        obj.parentroi = setdiff(obj.parentroi, {roi.uid});
        if isempty(obj.parentroi); obj.parentroi = {}; end
        % Needed this because setdiff returns a 1x0 col, should be row.
    end
    
    function obj = removeChildren(obj, roi)
        obj.connectedrois = setdiff(obj.connectedrois, {roi.uid});
        if isempty(obj.connectedrois); obj.connectedrois = {}; end
        % Needed this because setdiff returns a 1x0 col, should be row.
    end
    
    
% % Methods for tagging rois and getting tagged rois.
    
    function obj = addTag(obj, tag)
        
        for i = 1:numel(obj)
            if ~contains(tag, obj(i).tags)
                if isempty(obj(i).tags)
                    obj(i).tags = {tag};
                else
                    obj(i).tags = cat(1, obj(i).tags, {tag});
                end
            end
        end
        
    end
    
    
    function obj = removeTag(obj, tag)
        
        if contains(tag, '&')
            tag = strsplit(tag, '&');
        else
            tag = {tag};
        end
        
        for h = 1:numel(tag)
            for i = 1:numel(obj)
                if contains(tag{h}, obj(i).tags)
                    obj(i).tags = setdiff(obj(i).tags, tag{h});
                end
            end
        end
        
    end
    
    
    function [newObj, roiInd] = getTagged(obj, tag)
        
        if contains(tag, '&')
            tag = strsplit(tag, '&');
            isTagged = true(size(obj));
            operator = @and;
            
        elseif contains(tag, '|')
            tag = strsplit(tag, '|');
            isTagged = false(size(obj));
            operator = @or;
        else
            tag = {tag};
            isTagged = true(size(obj));
            operator = @and;
        end
                
        for i = 1:numel(tag)
            tmptag = tag{i};
            
            if contains(tmptag, '~')
                tmptag = strrep(tmptag, '~', '');
                isTaggedTmp = arrayfun(@(roi) ~any(contains(roi.tags, tmptag)), obj);
            else
                isTaggedTmp = arrayfun(@(roi) any(contains(roi.tags, tmptag)), obj);
            end
            
            isTagged = operator(isTagged, isTaggedTmp);

        end
        
        newObj = obj(isTagged);
        
        if nargout == 2
            roiInd = find(isTagged);
        end
            
        
    end
    
    
% % Method for copying a roi (not necessary if class is not handle)

    function twinRoi = copy(obj)
    %copy Copy RoI object. Only useful if RoI class is handle 
        nRois = numel(obj);
        twinRoi(nRois, 1) = RoI;
        
        for n = 1:nRois
            twinRoi(n) = RoI(obj(n).shape, obj(n).coordinates, size(obj(n).mask) );
            propertyList = {'uid', 'connectedrois', 'group', 'celltype', ...
                            'structure', 'xyz', 'layer', 'tags'};
            for i = 1:numel(propertyList)
                twinRoi(n).(propertyList{i}) = obj(n).(propertyList{i});
            end
        end
    end
    
    
% % Methods for checking various things related to position etc.
    

    function ul = getUpperLeftCorner(obj, offset, boxSize)
    %getUpperLeftCorner Get coordinate of upper left corner of "local" box
    
        if nargin < 2; offset = []; end
    
        if nargin < 3
            boxSize = size(obj.enhancedImage);
        end
        
        if ~isempty(offset)
            assert(offset >= 0, 'Offset can not be negative')
        end
        
        if isempty(boxSize) || sum(boxSize) == 0
            error('Box size is not defined')
        end
        
        if isempty(offset)
            [I, J] = obj.getThumbnailCoords(boxSize);
            minX = min(I(:)); minY = min(J(:));
        else
            switch obj.shape
                case {'Circle', 'Polygon'}
                    [y, x] = find(obj.mask);
                case {'Mask', 'Donut'}
                    y = obj.coordinates(:, 2);
                    x = obj.coordinates(:, 1);
            end

            minX = min(x)-offset;
            minY = min(y)-offset;

            if minX < 1; minX = 1; end 
            if minY < 1; minY = 1; end 

        end
        
        ul = [minX, minY];

        
    end

    
    function roiIndNeighbor = getNeighboringRoiIndices(obj, roiInd)
    %getNeighboringRoiIndices Get indices of neighboring rois.

        N_HOOD = 2; % n * radius;
        
        roiCenter = cat(1, obj.center);
        
        thisRoiCenter = roiCenter(roiInd, :);
        thisRoiRadius = sqrt( obj(roiInd).area / pi );
        
        lowerBound = thisRoiCenter - thisRoiRadius * N_HOOD;
        upperBound = thisRoiCenter + thisRoiRadius * N_HOOD;
        
        isNeighbor = roiCenter > lowerBound & roiCenter < upperBound;
        
        roiIndNeighbor = find(sum(isNeighbor,2)==2);
        
    end
    

    function tf = isRoiInRect(obj, rectCoords)
       
        % Should this be a roimanager method?
        % work in progress
        tf = false;
        
        switch obj.shape
            case 'Polygon'

            case 'Circle'

            case {'Mask', 'Donut'}

        end
    end
    
    
    function tf = isOverlap(obj, roiOrMask)
        
        tf = false(numel(obj), 1);
        
        for i = 1:numel(obj)
        
            if isa(roiOrMask, 'RoI')
                masktmp = roiOrMask.mask;
            elseif isa(roiOrMask, 'logical') && isequal(size(roiOrMask), obj(i).imagesize)
                masktmp = roiOrMask;
            else
                error('invalid input')
            end

            roiMask = obj(i).mask;

            tf(i) = any(intersect(find(roiMask), find(masktmp)));
            
        end
    end
    
    
    function tf = isInRoi(obj, x, y)
    %isInRoi Check if the point (x,y) is a part of the roi.
    %   bool = isInRoi(roi, x, y) returns true if x and y is within the RoI
    %   and false otherwise
    %
    % roi       - Single RoI object.
    % x         - (int) Position in image as pixels.
    % y         - (int) Position in image s pixels.
    
    % Should this be a roimanager method?
    
        tf = false;
    
        switch obj.shape
            case 'Polygon'
                xv = obj.coordinates(:,1); yv = obj.coordinates(:,2);
                [in, on] = inpolygon(x, y, xv,yv);
                if in || on; tf = true; end

            case 'Circle'
                xyr = obj.coordinates;
                if (x-xyr(1))^2 + (y-xyr(2))^2 <= xyr(3)^2
                    tf = true;
                end

            case {'Mask', 'Donut'}
                
                if isa(obj.coordinates, 'logical')
                    if obj.coordinates(round(y), round(x))
                        tf = true;
                    end
                else
                    if any(sum(round(obj.coordinates) == round([x, y]), 2) == 2)
                        tf = true;
                    end
                end

        end
            
    end
    
    
    function tf = isOnBoundary(obj)
        
        tf = false;
        
        x = obj.center(1); y = obj.center(2);
        
        if x < 10 || x > obj.imagesize(2)-10
            tf = true; 
        end
        
        if y < 10 || y > obj.imagesize(1)-10
            tf = true; 
        end
               
    end
    
    
    function tf = isOutsideImage(obj)
        
        tf = false(size(obj));
        
        for i = 1:numel(obj)
            x = obj(i).center(1); y = obj(i).center(2);

            if x < 1 || x > obj(i).imagesize(2)
                tf(i) = true; 
            end

            if y < 1 || y > obj(i).imagesize(1)
                tf(i) = true; 
            end
        end
        
    end
    
    
    function tf = assertImageSize(obj, imageSize)
    %assertImageSize Check whether RoI size and imageSize corresponds
        tf = true;
        for i = 1:numel(obj)
            if ~isequal(obj(i).imagesize, imageSize)
                tf = false;
            end
        end
    end
                
    
% % Methods for setting/getting property values.
    
    function obj = set.imagesize(obj, imageSize)
    % Update coordinates if imagesize is set/re-set.
    %
    % If imagesize is set on a RoI object for the first time, nothing else 
    % happens. If imagesize is re-set, the default behavior is to reset the
    % coordinates of the RoI object according to the following rule:
    %   The RoI coordinates are shifted so that their relationship to
    %   the center of the image remains the same.

        for i = 1:numel(obj)
           
            if isempty(imageSize)
                obj(i).imagesize = [];
                continue
            end
            
            % First time intialization
            if isempty(obj(i).imagesize)
                obj(i).imagesize = imageSize; 
                return
            end

            % Check if value is different. Use AbortSet instead?
            if isequal(obj(i).imagesize, imageSize)
                return
            % Update coordinates
            else 
                % Find the image size difference:
                sizeDiff = imageSize - obj(i).imagesize; 
                shift = sizeDiff/2;
                
                % Handle shapes differently
                switch obj(i).shape
                    case {'Circle', 'Polygon'}
                        obj(i) = obj(i).move(fliplr(floor(shift)));
                    case {'Mask', 'Donut'}
                        shiftPre = abs(floor(shift));
                        shiftPost = abs(ceil(shift));
                        
                        oldMask = obj(i).mask;
                        newMask = false(imageSize);
                        
                        if all(shift >= 0) % Equivalent to padding
                            newMask(1+shiftPre(1):end-shiftPost(1), ...
                                    1+shiftPre(2):end-shiftPost(2)) = oldMask;
                        elseif all(shift <= 0) % Equivalent to cropping
                            newMask = oldMask(1+shiftPre(1):end-shiftPost(1), ...
                                              1+shiftPre(2):end-shiftPost(2) );
                        else
                            error('So sorry, currently there is no implementation for the case where the image size grows in one dimension and shrinks in the other')                            
                        end
                        
                        obj(i) = obj(i).reshape('Mask', newMask);
                    otherwise
                            error('Unknown shape "%s" for a RoI', obj(i).shape)
                end
            
                obj(i).imagesize = imageSize;
            
            end
        end
    end

    
    function mask = get.mask(self)
        
        imsize = self.imagesize;
        
        switch self.shape
            case 'Polygon'
                x = self.coordinates(:, 1);
                y = self.coordinates(:, 2);
                mask = poly2mask(x, y, imsize(1), imsize(2));
            case 'Circle'
                mask = false(imsize);
                ind = self.getPixelIdxList();
                mask(ind) = true;
                
            case {'Mask', 'Donut'}

                % Preallocate a mask.
                mask = false(imsize);
                
                coordInt = round(self.coordinates);
                
                % Keep all indices which are within the image boundaries
                keep = sum(coordInt < 1, 2) == 0 & sum(coordInt > fliplr(imsize), 2) == 0;
                
                % Get linear indices for where the mask is true.
                ind = sub2ind(imsize, coordInt(keep, 2), coordInt(keep, 1));
                mask(ind) = true;
                
            case 'IMask'
                mask = false(imsize);
                coordInt = round(self.coordinates);

                keep = self.pixelweights > self.MaskWeightCutoff;
                ind = sub2ind(imsize, coordInt(keep, 2), coordInt(keep, 1));
                mask(ind) = true;

        end
    end
    
    function tag = get.tag(self)
        if ~isempty(self.celltype)
            tag = [self.celltype(1), self.structure(1)];
        else
            tag = self.structure(1:2);
        end
    end
    
    function obj = addImage(obj, imdata)
        
        nRois = numel(obj);
        assert(size(imdata, 3) == nRois)
        
        for i = 1:nRois 
            roi = obj(i);
            roi.enhancedImage = imdata(:, :, i);
            obj(i) = roi;
        end
        
    end
    
    function obj = setGroup(obj, group)
    % Unnecessary function because of stupid properties definitions.
        for i = 1:numel(obj)

            roi = obj(i);

            if nargin < 2
                group = roi.group;
            end

            roi.group = group;
            switch group
                case 'Neuronal Soma'
                    roi.celltype = 'Neuron';
                    roi.structure = 'Soma';
                case {'Neuronal Dendrite', 'Dendrite'}
                    roi.celltype = 'Neuron';
                    roi.structure = 'Dendrite';
                case {'Neuronal Axon', 'Axon'}
                    roi.celltype = 'Neuron';
                    roi.structure = 'Axon';
                case {'Neuropill', 'NeuroPil', 'Neuropil'}
                    roi.celltype = 'Neuron';
                    roi.structure = 'pil';
                    roi.group = 'Neuropil';
                case 'Astrocyte Soma'
                    roi.celltype = 'Astrocyte';
                    roi.structure = 'Soma';     
                case {'Astrocyte Endfoot', 'Endfoot'}
                    roi.celltype = 'Astrocyte';
                    roi.structure = 'Endfoot';
                case 'Astrocyte Process'
                    roi.celltype = 'Astrocyte';
                    roi.structure = 'Process';
                case 'Gliopill'
                    roi.celltype = 'Astrocyte';
                    roi.structure = 'Gliopil';
                case 'Artery'
                    roi.celltype = [];
                    roi.structure = 'Artery';
                case 'Vein'
                    roi.celltype = [];
                    roi.structure = 'Vein';                
                case 'Capillary'
                    roi.celltype = [];
                    roi.structure = 'Capillary';
            end

            obj(i) = roi;

        end

    end
    
    function obj = setappdata(obj, name, value)

        for i = 1:numel(obj)
            if isempty(value) % In case value is empty.
                obj(i).ApplicationData.(name) = [];
            else
                obj(i).ApplicationData.(name) = value(i);
            end
        end
        
    end
    
    function data = getappdata(obj, name)
        
        data = cell(numel(obj), 1);
        
        for i = 1:numel(obj)
            if ~isfield(obj(i).ApplicationData, name)
                data{i} = [];
            else
                data{i} = obj(i).ApplicationData.(name);
            end
        end
        
        % concatenate data for rois into vector/qarray     
        if iscell(data) && isstruct(data{1})
            data = utility.struct.structcat(1, data{:});
        else
            data = cat(1, data{:});
        end
    end
    
    function pixelIdxList = getPixelIdxList(obj)
        imsize = obj.imagesize;
        
        switch obj.shape
            case 'Circle'                
                x = obj.coordinates(1);
                y = obj.coordinates(2);
                r = obj.coordinates(3);
                
                % Create small local mask with radius r
                [xx, yy] = meshgrid((-r:r) - mod(x,1), (-r:r) - mod(y,1));
                localMask = (xx.^2 + yy.^2) < r^2 ;
                [X,Y] = find(localMask);
                
                % Compute mask coordinates of local mask in full mask
                x0 = mean(X);
                y0 = mean(Y);
                
                X = round(X + x - x0 );
                Y = round(Y + y - y0 );
                [X, Y] = obj.validateCoordinates(X,Y);
                pixelIdxList = sub2ind(imsize, Y, X);
                
            case {'Mask', 'IMask'}
                pixelIdxList = sub2ind(imsize, round(obj.coordinates(:,2)), round(obj.coordinates(:,1)));
            case 'Polygon'
                pixelIdxList = find(obj.mask);
                
                
        end
    end
    
    function [localMask, globalSubs] = getLocalMask(obj)
        imsize = obj.imagesize;
        
        switch obj.shape
            case 'Circle'  
                x = obj.coordinates(1);
                y = obj.coordinates(2);
                r = obj.coordinates(3);

                [xx, yy] = meshgrid((-r:r) - mod(x,1), (-r:r) - mod(y,1));
                localMask = (xx.^2 + yy.^2) < r^2 ;
                [X, Y] = find(localMask);
                x0 = mean(X);
                y0 = mean(Y);
                
                X = round(X + x - x0 - 1); % Subtract 1 to account for pixel indices starting at 1??
                Y = round(Y + y - y0 - 1);
                
%                 X = min(X):max(X);
%                 Y = min(Y):max(Y);
                
                [X, Y] = meshgrid( min(X):max(X),  min(Y):max(Y) );
                
                globalSubs = sub2ind(imsize, Y, X);
                
                
                keepRows = sum(localMask, 2) ~= 0;
                keepCols = sum(localMask, 1) ~= 0;
                
                localMask = localMask(keepRows, keepCols);
                
        end
        
    end
   
    function [X, Y] = validateCoordinates(obj, X, Y)
    %validateCoordinates Make sure coordinates are within image bounds    
        isValidX = X >= 1 & X <= obj.imagesize(2);
        isValidY = Y >= 1 & Y <= obj.imagesize(1);
        
        X = X (isValidX & isValidY);
        Y = Y (isValidX & isValidY);
    end
    
    
% % Methods for getting old property values

    function group = get.Group(self)
        if isempty(self.Group)
            group = self.group;
        else
            group = self.Group;
        end
    end

    
    function PixelsX = get.PixelsX(self)
        [~, PixelsX] = find(self.Mask);
    end
    
    
    function PixelsY = get.PixelsY(self)
        [PixelsY, ~] = find(self.Mask);
    end
    

    function center = get.Center(self)
        if isempty(self.Center)
            center = self.center;
        else
            center = self.Center;
        end
    end

    
    function boundary = get.Boundary(self)
        if isempty(self.Boundary)
            boundary = self.boundary;
        else
            boundary = self.Boundary;
        end
    end
    
    
    function mask = get.Mask(self)
        if isempty(self.Mask)
            mask = self.mask;
        else
            mask = self.Mask;
        end
    end
    
    
    function tag = get.Tag(self)
        if ~isempty(self.celltype)
            tag = [self.celltype(1), self.structure(1)];
        else
            tag = self.structure(1:2);
        end
    end
  
    
end


% Following methods are only accessible to class and subclasses
methods (Access = protected)
    

    function obj = findCenter(obj)
        % Find and set center of RoI.
        switch obj.shape
            case 'Circle'
                obj.center = obj.coordinates(1:2);
            case {'Polygon', 'Mask', 'Donut'}
                obj.center = mean(obj.coordinates, 1);
            case 'IMask'
                % Todo: get center of mass based on pixel weights
                obj.center = mean(obj.coordinates, 1);

%             case {'Mask', 'Donut'}
%                 [y, x] = find(obj.coordinates);
%                 obj.center = [mean(x), mean(y)];
        end
    end
    
    
    function obj = setCoordinates(obj, coordinates)
    %checkCoordinates check that coordinates are valid according to shape
    
    % Todo: Change to set.coordinates
        switch obj.shape
            case 'Polygon'
                sizeCoord = size(coordinates);
                assert(numel(sizeCoord) == 2, 'Coordinates for polygon must be 2D')
                assert(any(sizeCoord==2), 'Coordinates for polygon must be have 2 rows or 2 columns')
                if sizeCoord(1) == 2 % make it two column vectors.
                    coordinates = coordinates';
                end
                obj.coordinates = coordinates;
            case 'Circle'
                msg = 'Circle is specified by a vector of 3 values; x, y and radius';
                assert( numel(coordinates) == 3, msg )
                obj.coordinates = coordinates;
            case {'Mask', 'Donut'}
                assert( numel(size(coordinates)) == 2, 'Mask must be 2D')

%                 assert( isa(coordinates, 'logical'), 'Coordinates for mask must be logicals')
                if isa(coordinates, 'logical')
                    [y, x] = find(coordinates);
                elseif ismatrix(coordinates) && size(coordinates,2)==2
                    x = coordinates(:, 1); y = coordinates(:, 2);
                else
                    error('Roi coordinates should be logical or a 2-column vector')
                end

                obj.coordinates = [x, y];
                
            case 'IMask' % intensity mask
                assert( numel(size(coordinates)) == 2, 'Coordinates must be 2D')
                
                if ismatrix(coordinates) && size(coordinates,2) == 3
                    x = coordinates(:, 1); y = coordinates(:, 2);
                    obj.pixelweights = coordinates(:, 3);
                elseif ismatrix % assume a mask was given.
                    pixelsKeep = coordinates~=0;
                    obj.pixelweights = coordinates(pixelsKeep);
                    [y, x] = find(pixelsKeep);
                else
                    error('Unknown size of coordinates for intensity mask') 
                end
                
                obj.coordinates = [x, y];

        end
        
    end
       
    
    function obj = setBoundaries(obj)
        % Find and set boundary of RoI
        
        BW = obj.mask;

        switch obj.shape
            case 'Mask'
                CC = struct('Connectivity', 8, 'ImageSize', obj.imagesize, 'NumObjects', 1);
                keepX = round(obj.coordinates(:,1)) >= 1 & round(obj.coordinates(:,1)) <= obj.imagesize(2);
                keepY = round(obj.coordinates(:,2)) >= 1 & round(obj.coordinates(:,2)) <= obj.imagesize(1);
                keep = keepX & keepY;
                CC.PixelIdxList = { sub2ind(obj.imagesize, round(obj.coordinates(keep,2)), round(obj.coordinates(keep,1))) };
                bboxOffset = 0.5;
                correctionOffset = -0.5;
                
            case 'IMask'
                pixelsKeep = obj.pixelweights > obj.MaskWeightCutoff;
                CC = struct('Connectivity', 8, 'ImageSize', obj.imagesize, 'NumObjects', 1);
                CC.PixelIdxList = { sub2ind(obj.imagesize, round(obj.coordinates(pixelsKeep,2)), round(obj.coordinates(pixelsKeep,1))) };
                bboxOffset = 0.5;
                correctionOffset = -0.5;

            otherwise
                CC = bwconncomp(BW);
                bboxOffset = 0.5;
                correctionOffset = -0.5;
        end
        
        stats = regionprops(CC, 'BoundingBox');
        xInd = stats.BoundingBox(1) + (1:stats.BoundingBox(3)) - bboxOffset;
        yInd = stats.BoundingBox(2) + (1:stats.BoundingBox(4)) - bboxOffset;

        BWsmall = BW(round(yInd), round(xInd));
        B = bwboundaries(BWsmall);
        
        %B = bwboundaries(obj.mask);        
        
        % Standardize output B, so that boundary property is a cell of two
        % column vectors, where the first is y-coordinates and the seconds
        % is x-coordinates. Should ideally be an nx2 matrix of x and y.
        if numel(B) > 1
            B = cellfun(@(b) vertcat(b, nan(1,2)), B, 'uni', 0);
            B = vertcat(B{:});
            B(end, :) = []; % Just remove the last nans...
        elseif isempty(B)
            B = [nan, nan];
        else
            B = B{1};
        end
        
        B = B + fliplr( stats.BoundingBox(1:2) );
        B = B + [correctionOffset, correctionOffset];
        obj.boundary = {B};

    end
       
    
    function obj = setArea(obj)
        % Find and set area of RoI 
        switch obj.shape
            case 'Circle'
                A = pi*obj.coordinates(3)^2 ;
            case 'Polygon'
                A = polyarea(obj.coordinates(:, 1), obj.coordinates(:, 2));
            case {'Mask', 'Donut', 'IMask'}
                A = size(obj.coordinates, 1);
        end
        
        obj.area = round(A);
    end
    
    
end


methods(Static)
    

    function overlap = calculateOverlap(roi1, roi2)
        % Find fraction of area overlap between two RoIs.
        area1 = roi1.area;
        area2 = roi2.area;
        
        if ~assertImageSize(roi1, roi2.imagesize)
            roi1.imagesize = roi2.imagesize;
        end
        
        overlappingArea = sum(sum(roi1.mask & roi2.mask));
        overlap = overlappingArea / min(area1, area2);

    end
    
    
    function mergedRoi = mergeRois(listOfRois, mergeOperation)
    %    
    %   
    %   mergeOperation: 'union', 'intersect'  
    
        if nargin < 2
            mergeOperation = 'union';
        end
        
        combinedMasks = sum(cat(3, listOfRois.mask),3);
        
        switch mergeOperation
            case 'union'
                newMask = combinedMasks ~= 0;
            case 'intersect'
                newMask = combinedMasks == numel(listOfRois);
        end
        
        
        mergedRoi = RoI('Mask', newMask, listOfRois(1).imagesize);
        
        mergedRoi.structure = listOfRois(1).structure;
        mergedRoi.group = listOfRois(1).group;
        mergedRoi.celltype = listOfRois(1).celltype;
    end
    
    
    % Custom loadobj function to take care of loading older versions of RoI
    function obj = loadobj(s)
        
        if isa(s, 'struct') % Object not resolved. Old version?
            
            propertyNames = fieldnames(s);
            
            if contains('ID', propertyNames) % Ancient version. 
                % This has to be changed I believe. Ancient version is
                % loaded as an obj, not a struct.
                
                shape = s.Shape;
                imsize = [s.ImageDimX, s.ImageDimY]; %This is intentional
                num = s.ID;

                % impoints was not a property back then, so use the mask to
                % generate new roi
                if isempty(s.imPointsX)
                    shape = 'Mask';
                end
        
                switch shape
                    case 'Polygon'
                        % make impoint coordinates nx2 array
                        if isrow(s.imPointsX)
                            coordinates = [s.imPointsX; s.imPointsY]';
                        else
                            coordinates = [s.imPointsX, s.imPointsY];
                        end
                    case 'Autothreshold'
                        shape = 'Mask';
                        coordinates = s.Mask;
                    case {'Mask', 'Donut'}
                        coordinates = s.Mask;
                end
        
                % Get old group
                group = s.Group;

                % Create new RoI
                obj = RoI(shape, coordinates, imsize);
                % Set new group properties
                obj = setGroup(obj, group);
                obj.num = num;
                 
            elseif contains('mask', propertyNames)
                imsize = size(s.mask);
                obj = RoI(s.shape, s.coordinates, imsize);

                skip = {'shape', 'coordinates', 'imagesize', ...
                        'center', 'area', 'boundary', 'mask'};
                propertyNames = setdiff(propertyNames, skip);

                for fNo = 1:numel(propertyNames)
                    obj.(propertyNames{fNo}) = s.(propertyNames{fNo});
                end
                %disp('updated RoI while loading...')
                
            elseif contains('refpoint', propertyNames) % Unfortunate bieffect of adding a useless property during dev.
                obj = RoI(s.shape, s.coordinates, s.imagesize);
                
                skip = {'shape', 'coordinates', 'imagesize', ...
                        'center', 'area', 'boundary', 'mask', 'refpoint'};
                propertyNames = setdiff(propertyNames, skip);

                for fNo = 1:numel(propertyNames)
                    obj.(propertyNames{fNo}) = s.(propertyNames{fNo});
                end
            else
                obj = utilities.struct2roiarray(s);

            end

            if contains('labels', propertyNames)
                obj.tags = s.labels;
            end
            
        else
            obj = s;
            
% % %             propertyNames = properties(s);
% % %             propertyNames = cat(2, propertyNames', findPropertyWithAttribute(s, 'Hidden'));
% % %             
% % %              if contains('ID', propertyNames) % Ancient version. 
% % %                 % This has to be changed I believe. Ancient version is
% % %                 % loaded as an obj, not a struct.
% % %                 
% % %                 shape = s.Shape;
% % %                 imsize = [s.ImageDimX, s.ImageDimY]; %This is intentional
% % %                 num = s.ID;
% % % 
% % %                 % impoints was not a property back then, so use the mask to
% % %                 % generate new roi
% % %                 if isempty(s.imPointsX)
% % %                     shape = 'Mask';
% % %                 end
% % %         
% % %                 switch shape
% % %                     case 'Polygon'
% % %                         % make impoint coordinates nx2 array
% % %                         if isrow(s.imPointsX)
% % %                             coordinates = [s.imPointsX; s.imPointsY]';
% % %                         else
% % %                             coordinates = [s.imPointsX, s.imPointsY];
% % %                         end
% % %                     case 'Autothreshold'
% % %                         shape = 'Mask';
% % %                         coordinates = s.Mask;
% % %                     case {'Mask', 'Donut'}
% % %                         coordinates = s.Mask;
% % %                 end
% % %         
% % %                 % Get old group
% % %                 group = s.Group;
% % % 
% % %                 % Create new RoI
% % %                 obj = RoI(shape, coordinates, imsize);
% % %                 % Set new group properties
% % %                 obj = setGroup(obj, group);
% % %                 obj.num = num;
% % %              end
            
            
            % 2019-08-20 - Changed coordinates of rois with shape "mask"
            % from being a sparse logical to being a list of pixel
            % coordinates.
            if isa(obj.coordinates, 'logical')
                mask = full(obj.coordinates);
                obj = obj.setCoordinates(mask);
            end
            
            % Fix mistake of setting boundary to empty if roi is outside of
            % the image. Also, make sure boundary is only one cell. Updated
            % version of setBoundaries concatenates all boundaries with
            % nans inbetween.
            if isempty(obj.boundary) || numel(obj.boundary) > 1
                obj = obj.setBoundaries();
            end
            
        end
    end
    
    
end


end

