classdef MultiSessionFovSwitcher < applify.ModularApp & applify.mixin.UserSettings


    properties (Constant)
        AppName = 'Multisession Fov Selector'
    end
    
    properties (Constant)
        USE_DEFAULT_SETTINGS = false
        DEFAULT_SETTINGS = struct
    end

    properties (Constant, Hidden = true) % Move to appwindow superclass
        DEFAULT_THEME = nansen.theme.getThemeColors('dark-gray');
    end
    
    properties
        TiledImageAxes
        Axes
    end

    methods 
        
        function obj = MultiSessionFovSwitcher(imdata)

            obj.TiledImageAxes = uim.graphics.tiledImageAxes(obj.Panel, ...
                'gridSize', [1,3], 'imageSize', [256, 256], ...
                'normalizedPadding', 0.02, 'Visible', 'on');

            obj.isConstructed = true; %obj.onThemeChanged()

            obj.TiledImageAxes.highlightTileOnMouseOver = true;
            
            
            [imHeight, imWidth, nImages] = size(imdata);
            nImages = min([nImages, obj.TiledImageAxes.nTiles]);
            
            
            if ndims(imdata) == 3
                obj.TiledImageAxes.updateTileImage(imdata(:, :, 1:nImages), 1:nImages)
            elseif ndims(imdata) == 4
                obj.TiledImageAxes.updateTileImage(imdata(:, :, :, 1:nImages), 1:nImages)
            end


            obj.Axes = obj.TiledImageAxes.Axes;
            obj.TiledImageAxes.fitAxes;
            
            % Set this property so that text outside the axes is clipped.
            obj.Axes.ClippingStyle = 'rectangle';
            
            obj.onVisibleChanged()

        end
        
        function onVisibleChanged(obj)
            if obj.isConstructed
                set(obj.Axes.Children, 'Visible', true)
                %obj.hScrollbar.Visible = obj.Visible;
            end
        end
        
    end

    methods (Access = protected)
        function onSettingsChanged(obj)

        end

        function onSizeChanged(app, src, evt)
        %onSizeChanged Callback for size changed event on panel
            % Update cached pixel position value;
            onSizeChanged@applify.ModularApp(obj)
            obj.Panel.Position = [0,0,1,1];
        end
    end

end