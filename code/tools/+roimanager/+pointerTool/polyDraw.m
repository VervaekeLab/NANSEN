classdef polyDraw < uim.interface.abstractPointer & ...
        roimanager.pointerTool.RoiDisplayInputHandler
    
    properties (Constant)
        exitMode = 'default';
    end
    
    properties % Properties related to displaying polygon during creation
        
        hlineTmpRoi                     % Line handle for temporary lines of roi polygon

        tmpImpoints                     % A list of impoints for the temporary roi polygon
        selectedImpoint                 % Number of selected impoint
        
        tmpRoiPosX                      % X coordinate values of the temporary roi
        tmpRoiPosY                      % Y coordinate values of the temporary roi
                
    end

    properties (Access = private, Hidden)
        defaultImpointColor = [0.5,0.5,0.5]
        selectedImpointColor = [0.8,0.8,0.8]
    end
    
    methods
               
        function obj = polyDraw(hAxes)
            obj.hAxes = hAxes;
            obj.hFigure = ancestor(hAxes, 'figure');
        end
        
        function deactivate(obj)
            deactivate@uim.interface.abstractPointer(obj)
            removeTmpRoi(obj)
        end
        
        function setPointerSymbol(obj)
            obj.hFigure.Pointer = 'crosshair';
        end
        
        function onButtonDown(obj, src, evt)
            
            obj.isActive = true;
            
            currentPoint = obj.hAxes.CurrentPoint(1, 1:2);
            x = currentPoint(1);
            y = currentPoint(2);
            
            idx = obj.isCursorOnImpoint(x, y);
            if idx == 0
                obj.addImpoint(x, y);
                obj.drawPolygonOutline();
            end
        end
        
        function onButtonMotion(obj, src, evt)
            
            if obj.isActive; return; end
            
            currentPoint = obj.hAxes.CurrentPoint(1, 1:2);
            idx = obj.isCursorOnImpoint(currentPoint(1), currentPoint(2));
            
            if idx == 0
                obj.hFigure.Pointer = 'crosshair';
            else
                obj.hFigure.Pointer = 'circle';
            end
        end
        
        function onButtonUp(obj, src, event)
            obj.isActive = false;
        end
        
        function wasCaptured = onKeyPress(obj, src, event)
            
            wasCaptured = true;

            switch event.Key
               
                case 'escape'
                    obj.removeTmpRoi()
                    
                case 'f'
                    [x, y] = obj.getPolygonVertices();
                    obj.RoiDisplay.createPolygonRoi(x, y);
                    obj.removeTmpRoi();

                case 'backspace'
                    
                    if ~isa(gco, 'matlab.ui.control.UIControl')
                        if ~isempty(obj.selectedImpoint)
                            obj.removeImpoint();
                        end
                    end
                    
                otherwise
                    wasCaptured = false;
                    
            end
        end
        
        function [x, y] = getPolygonVertices(obj)
            x = obj.tmpRoiPosX;
            y = obj.tmpRoiPosY;
        end
    end
    
    methods (Access = protected)
        
        function drawPolygonOutline(obj)
        % Draw the lines between the impoints of tmp roi.
        
            % Get list of vertex points
            x = obj.tmpRoiPosX;
            y = obj.tmpRoiPosY;
            
            if length(x) < 2 || length(y) < 2
                if ~isempty(obj.hlineTmpRoi)
                   set(obj.hlineTmpRoi,'XData',nan,'YData',nan);
                end
                return
            end
            
            % Close the circle
            x(end+1) = x(1);
            y(end+1) = y(1);
            
            % There should only be one instance of the tmp roi plot.
            if isempty(obj.hlineTmpRoi) || ~isvalid(obj.hlineTmpRoi)
                obj.hlineTmpRoi = plot(obj.hAxes, 0,0);
                obj.hlineTmpRoi.HitTest = 'off';
                obj.hlineTmpRoi.PickableParts = 'none';
            end
            
            set(obj.hlineTmpRoi,'XData',x, 'YData',y);
        end
        
        function removeTmpRoi(obj)
        %REMOVETMPROI clear the obj.RoiTmpPos or obj.tmpImpoints.

            obj.tmpRoiPosX = [];
            obj.tmpRoiPosY = [];
            for i = 1:numel(obj.tmpImpoints)
                delete(obj.tmpImpoints{i});
            end
            
            delete(obj.hlineTmpRoi)
            obj.hlineTmpRoi = [];

            obj.tmpImpoints = cell(0);
            obj.selectedImpoint = [];
            
        end
        
        function addImpoint(obj, x, y)
        % addImpoint adds a new tmp roi vertex to the axes.
        % After the impoint is created it is also configured.
        %   addImpoint<(obj, ax, x, y)
        %   x, y       - Coordinates in pixels.
        %
        %   See also configImpoint, impoint

            % Find the index of this edge.
            i = numel(obj.tmpImpoints) + 1;

            % Add x and y to lists of coordinates
            obj.tmpRoiPosX(i) = x;
            obj.tmpRoiPosY(i) = y;
            
            % The vertices are impoints that can be moved around.
            %tmpRoiVertex = drawpoint(obj.hAxes, 'Position', [x, y]);
            tmpRoiVertex = impoint(obj.hAxes, x, y);
            tmpRoiVertex.setColor(obj.defaultImpointColor)
            obj.configImpoint(tmpRoiVertex, i);
            obj.tmpImpoints{end+1} = tmpRoiVertex;
            
            % Select the last added impoint
            obj.selectImpoint(i);
            
        end
        
        function selectImpoint(obj, i)
        % select/highlight roivertex at number i in list of impoints.
            if i == 0
                return
            end
            
            if ~isequal(i, obj.selectedImpoint)
                %obj.tmpImpoints{i}.setColor('yellow')
                obj.tmpImpoints{i}.setColor(obj.selectedImpointColor)
                if ~isempty(obj.selectedImpoint)
                    obj.tmpImpoints{obj.selectedImpoint}.setColor(obj.defaultImpointColor)
                end
                obj.selectedImpoint = i;
            end
        end
        
        function removeImpoint(obj)
        % removeImpoint removes a new tmp roi vertex from the axes.

            i = obj.selectedImpoint;

            % Delete the impoint and remove it from the cell array
            delete(obj.tmpImpoints{i})
            obj.tmpImpoints(i) = [];

            % Remove x and y from lists of coordinates
            obj.tmpRoiPosX(i) = [];
            obj.tmpRoiPosY(i) = [];
            
            % Redraw lines between the vertices
            obj.drawPolygonOutline();
            
            % Update position constraint function
            for n = 1:numel(obj.tmpImpoints)
            	obj.tmpImpoints{n}.setPositionConstraintFcn(@(pos)lockImpointInZoomMode(obj, pos, n))
            end
            
            obj.selectedImpoint = [];
            
            % Select new vertex (previous point)
            if i ~= 1
                i = i-1;
            else
                i = numel(obj.tmpImpoints);
            end
            
            obj.selectImpoint(i);
        end
        
        function idx = isCursorOnImpoint(obj, x, y)
        %isCursorOnImpoint Check if point (x, y) is close to tmp roi vertex
        %   idx = isCursorOnImpoint(obj, x, y) returns idx of tmproi vertex
        %   if any tmproi vertex is close to point (x, y). If not idx is 0.
        
            % Get xlim of image and create a scaled vicinity measure for
            % impoints
            
            impoint_extent = diff(obj.hAxes.XLim)/100;
            
            % Check is x coordinate is in vicinity of tmpRoi vertices
            xWithinVertex = abs(obj.tmpRoiPosX - x) < impoint_extent;
            if any(xWithinVertex)
                idx1 = find(xWithinVertex);
                yWithinVertex = abs(obj.tmpRoiPosY(idx1) - y) < impoint_extent;
                % Check is y coordinate is in vicinity of tmpRoi vertex
                if any(yWithinVertex)
                    idx = idx1(yWithinVertex);
                else
                    idx = 0;
                end
            else
                idx = 0;
            end
        end
        
        function configImpoint(obj, impointObj, i)
        %CONFIGIMPOINT configures an impoint.
        % Sets the new position callback of impoints. They are responsible for
        % updating the plot when a vertex is moved.
        %   configImpoint(obj, ax, impointObj, i)
        %   impointObj    - impoint to configure.
        %   i             - Sent to the move callback. Index of the impoint.
        %
        % See also impoint, moveTmpRoiVertex
            impointObj.addNewPositionCallback(@(pos)callbackRoiPosChanged(obj, pos));
            impointObj.setPositionConstraintFcn(@(pos)lockImpointInZoomMode(obj, pos, i))
            impointObj.Deletable = false;
        end
        
        function constrained_pos = lockImpointInZoomMode(obj, new_pos, i)
        % Callback function when dragging impoint. Locks impoint in place
        % during zoom mode.
            if strcmp( obj.state, 'on_hold')
                x = obj.tmpRoiPosX(i);
                y = obj.tmpRoiPosY(i);
                constrained_pos = [x, y];
            else
                constrained_pos = new_pos;
            end
        end
        
        function callbackRoiPosChanged(obj, pos)
        % callback function of impoint.
        % This function is called whenever a impoint is moved (Tmp RoI vertex).
        %
        % See also configImpoint, impoint, moveTmpRoiVertex

            points = cell2mat(cellfun(@(imp) imp.getPosition', obj.tmpImpoints, 'uni', 0));
            obj.tmpRoiPosX = points(1, :);
            obj.tmpRoiPosY = points(2, :);

            id1 = find(obj.tmpRoiPosX == pos(1));
            id2 = find(obj.tmpRoiPosY == pos(2));
            
            if id1 == id2
                % If two points are on top of each other, select one
                obj.selectImpoint(id1(1));
            end

            obj.drawPolygonOutline();
            
        end
    end
end
