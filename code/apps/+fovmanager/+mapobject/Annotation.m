classdef Annotation < fovmanager.mapobject.BaseObject
    
    % What style should this thing be, and how should style be applied?
    % Local methods, abstract properties?
    %
    % Should be possible to add image to an annotation. Then image can be
    % added without first adding a window, and then a fov.
    
    properties
        
        name
        color
        radius % in micrometers
    
    end
    
    properties (Transient)
        boundaryWidth = 2;
        boundaryColor = 'k'
    end
    
    methods
        
        function obj = Annotation(varargin)
             
            if isa(varargin{1}, 'fovmanager.App')
                fmHandle = varargin{1};
                varargin = varargin(2:end);
            end
            
            % Temporary fix (object was saved as object...):
            if isa(varargin{1}, 'fovmanager.mapobject.Annotation')
                varargin{1} = varargin{1}.toStruct();
            end

            if isa(varargin{1}, 'struct')
                obj.fromStruct(varargin{1})
            end
            
            obj.boundaryColor = obj.color;

            [x, y] = obj.getBoundaryCoords();
            obj.edge = [x, y];

            if exist('fmHandle', 'var')
                obj.displayObject(fmHandle)
                setLineStyle(obj)
            end
        end
        
        function infoText = getInfoText(obj)
        
            infoText = '';

            if ~isempty(obj.name)
                infoText = sprintf('%s', obj.name);
            end
        end
        
        function createContextMenu(obj, fmHandle)

            m = uicontextmenu;

            if ~isempty(obj.image)
                mitem = uimenu(m, 'Text', 'Replace Image...');
            else
                mitem = uimenu(m, 'Text', 'Add Image...');
            end
            mitem.Callback = @(src, event) obj.addImage();
            
            mitem = uimenu(m, 'Text', 'Set Image Transparency');
            mitem.Callback = @fmHandle.showTransparencySlider;
            if isempty(obj.image); mitem.Enable = 'off'; end
            
            mitem = uimenu(m, 'Text', 'Set Color');

            alternatives = {'Red', 'Green', 'Blue', 'Yellow'};
            for i = 1:numel(alternatives)
                tmpItem = uimenu(mitem, 'Text', alternatives{i});
                tmpItem.Callback = {@obj.changeColor, alternatives{i}};
            end
            
            mitem = uimenu(m, 'Text', 'Always Show');
            mitem.Callback = @obj.togglePersistentState;
            
            if obj.isMovable
                mitem = uimenu(m, 'Text', 'Lock Position', 'Separator', 'on');
            else
                mitem = uimenu(m, 'Text', 'Unlock Position', 'Separator', 'on');
            end
            
            mitem.Callback = @obj.togglePositionLock;
            
            mitem = uimenu(m, 'Text', 'Resize Annotation');
            mitem.Callback = @fmHandle.startResizeFov;

            mitem = uimenu(m, 'Text', 'Delete Annotation', 'Separator', 'on');
            mitem.Callback = @obj.requestdelete;

            obj.guiHandle.UIContextMenu = m;

        end
        
        function changeColor(obj, ~, ~, color)
        
            obj.color = lower(color(1));
            obj.boundaryColor = obj.color;
            hTmp = findobj(obj.guiHandle, 'Tag', 'Map Annotation Outline');
            set(hTmp, 'EdgeColor', obj.color)

        end
        
        function setLineStyle(obj)
            hTmp = findobj(obj.guiHandle, 'Tag', 'Map Annotation Outline');
            set(hTmp, 'LineStyle', '-')
            
        end
        
        function addImage(obj)
            addImage@fovmanager.mapobject.BaseObject(obj)
            
            % Resize annotation to fit with image aspectRatio.
            imageSize = size(obj.image);
            imageAr = imageSize(2) / imageSize(1);
            
            obj.radius = [1, 1/imageAr] .* obj.radius;
            [xCoords, yCoords] = obj.getBoundaryCoords('resetEdge', true);
            newPos = [min(xCoords), min(yCoords), range(xCoords), range(yCoords)];
            obj.resize(newPos);
            obj.updateImage();
        end
        
        function resize(obj, newPos)
            
            resize@fovmanager.mapobject.BaseObject(obj, newPos);
            
            % Update edge coordinates. Omg, ffs...
            [xCoords, yCoords] = obj.getBoundaryCoords();
            
            % Radius is in micrometer, so multiply with 1000
            obj.radius = [range(xCoords)/2, range(yCoords)/2] * 1000;

        end
        
        function togglePersistentState(obj, src, event)
            
            switch src.Text
                case 'Always Show'
                    obj.guiHandle.UserData.isPersistent = true;
                    src.Text = 'Show on Selection';
                    uistack(obj.guiHandle, 'top')
                    
                case 'Show on Selection'
                    obj.guiHandle.UserData.isPersistent = false;
                    src.Text = 'Always Show';
            end
        end
    end
    
    methods (Access = protected)
        
        function [x, y] = getBoundaryCoords(obj, varargin)
            
            % resetEdge is a temporary solution I hope. Sometimes, the edge
            % should be recalculated from the radius/size property. %Todo:
            % Should implement something more general across all objects...
            
            opt = struct('resetEdge', false);
            opt = parsenvpairs(opt, [], varargin);
            
            if opt.resetEdge
                obj.edge = [];
            end
            
            if isempty(obj.edge)
                radiusMapCoords = obj.radius / 1000;
            else
                radiusMapCoords = range(obj.edge) / 2;
            end
            
            switch obj.shape
            
                case {'circle', 'disk', 'sphere'}
                    theta = linspace(0,2*pi,200);
                    rho = ones(size(theta)) .* mean(radiusMapCoords);

                    [x, y] = pol2cart(theta, rho);

                    x(end+1)=x(1);
                    y(end+1)=y(1);

                    % Transpose to outpot column vectors.
                    x = x' + obj.center(1);
                    y = y' + obj.center(2);
                case 'rectangle'
                    % Slightly abusing the radius property here...
                    if numel(radiusMapCoords) == 1
                        radiusMapCoords = repmat(radiusMapCoords, 1, 2);
                    end
                    
                    x = obj.center(1) + [-1;-1;1;1] .* (radiusMapCoords(1));
                    y = obj.center(2) + [1;-1;-1;1] .* (radiusMapCoords(2));

            end
            
            % Since x & y is calculated from radius, divide by 1000 to get
            % from micrometer to millimeter (map coordinate units)
            obj.edge = [x, y];

        end
    end
    
    methods (Static)
        
        function S = interactiveDialog()
            
            shapes = fovmanager.mapobject.Annotation.getShapes();
            
            S = struct('name', '', 'shape_', {shapes.Alternatives}, ...
                'shape', shapes.Selection, 'color', 'k', 'radius', 0);
            S = tools.editStruct(S);
        end
        
        function shapes = getShapes()

            % Todo: implement point
%             availableShapes = {'circle', 'disk', 'sphere'};

            availableShapes = {'rectangle', 'circle', 'disk', 'sphere'};

            shapes = struct('Alternatives', {availableShapes}, ...
                            'Selection', 'circle');
            
        end
    end
end
