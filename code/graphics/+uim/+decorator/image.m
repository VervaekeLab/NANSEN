classdef image < uim.abstract.Component

    
    properties (Constant)
        Type = 'image'
    end
    
    properties
        Image = []
        Alpha = []
        
        LockAspectRatio = true; 
        
        ColorMap = []
    end
    
    properties (Access = private)
        hImage
    end
    
    properties (Transient, Dependent)
        AspectRatio
    end

    
    methods
        function obj = image(hParent, varargin)
        
            obj@uim.abstract.Component(hParent, varargin{:})
            
            % Image specific construction....
            
            % Todo: might want to keep bg...
            delete( obj.hBackground )
            obj.hBackground = [];
            
            obj.IsConstructed = true;
            
            obj.plotImage()
            
        
        end
        
        function delete(obj)
            if ~isempty(obj.hImage) && isvalid(obj.hImage)
                delete(obj.hImage)
            end
        end
        
    end
    
    
    methods % Set/get
        function set.Image(obj, newValue)
            
            isValidDim = ismatrix(newValue) || ndims(newValue) == 3;
            isValidSize = size(newValue, 3) == 1 || size(newValue, 3) == 3;
            
            assert(isValidDim & isValidSize, 'Value must be an image matrix')
            
            obj.Image = flipud(newValue);
            
            obj.plotImage()
        end
        
        function set.Alpha(obj, newValue)
            % Todo: Validate size (same size as image)

            obj.Alpha = flipud(newValue);
            obj.onAlphaSet()
        end
        
        
        function ar = get.AspectRatio(obj)
            imSize = size(obj.Image);
            ar = imSize(1) / imSize(2);
        end
    end
    
    methods
        function resize(obj)
            resize@uim.abstract.Component(obj)
            obj.setImagePosition()
        end
        
        function relocate(obj, shift)
            relocate@uim.abstract.Component(obj, shift)

            obj.hImage.XData = obj.hImage.XData + shift(1);
            obj.hImage.YData = obj.hImage.YData + shift(2);
        end
        
    end
    
    
    methods (Hidden, Access = protected)

        function onVisibleChanged(obj, ~)
            if ~obj.IsConstructed; return; end
            
            % Set visibility of graphics components.
            obj.hImage.Visible =  obj.Visible;
        end
        
        function onAlphaSet(obj)
            
            if ~obj.IsConstructed; return; end
            if isempty(obj.hImage); return; end

            obj.hImage.AlphaData = obj.Alpha;
            
        end
    end
    
    methods (Access = protected)
        
        function plotImage(obj)
            if ~obj.IsConstructed; return; end
            
            if ~isempty(obj.hImage)
                delete(obj.hImage)
                obj.hImage=[];
            end
            
            obj.hImage = image(obj.CanvasAxes, 'CData', obj.Image);
            obj.hImage.AlphaData = obj.Alpha;
            
            obj.hImage.HitTest = 'off';
            obj.hImage.PickableParts = 'none';
            
            obj.setImagePosition()

        end
        
        function setImagePosition(obj)
            
            imSize = obj.Size;

            if obj.LockAspectRatio
                if obj.AspectRatio > obj.Size(1) / obj.Size(2)
                    imSize(1) = imSize(2) ./ obj.AspectRatio;
                else
                    imSize(2) = imSize(1) .* obj.AspectRatio;
                end
            end
                
            xPos = obj.Position(1) + [0, imSize(1)];
            yPos = obj.Position(2) + [0, imSize(2)];
            
            obj.hImage.XData = xPos;
            obj.hImage.YData = yPos;
            
        end
        
        
        
    end
    
end