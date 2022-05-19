classdef FluFinder < imviewer.ImviewerPlugin
%FluFinder Imviewer plugin for FluFinder autosegmentation method
%
%   SYNTAX:
%       flufinderPlugin = FluFinder(imviewerObj)
%
%       flufinderPlugin = FluFinder(imviewerObj, optionsManagerObj)


    properties (Constant, Hidden = true)
        USE_DEFAULT_SETTINGS = false    % Ignore settings file
        DEFAULT_SETTINGS = []           % This class uses an optionsmanager
    end
    
    properties (Constant)
       Name = 'FluFinder'
    end
    
    properties (Access = private)
        hGridLines
        hCellTemplates
        gobjectTransporter
    end
    
    properties (Access = protected)
        CachePreprocessed
        CacheBinarized
        
        StaticBackground
        BackgroundOffset = 0;
    end
    
    methods % Structors
        
        function obj = FluFinder(varargin)
        %FluFinder Create an instance of the FluFinder plugin for imviewer
        %
        %   flufinderPlugin = FluFinder(imviewerObj)
        %
        %   flufinderPlugin = FluFinder(imviewerObj, optionsManagerObj)
        
            obj@imviewer.ImviewerPlugin(varargin{:})
            
            obj.addPreviewOptions()
            
            if not( obj.PartialConstruction )
                obj.openControlPanel()
            end
            
            if ~nargout
                clear obj
            end
        end
        
        function delete(obj)
            %delete(obj.hGridLines)
            delete(obj.hCellTemplates)
            delete(obj.gobjectTransporter)
        end
        
    end
    
    methods (Access = {?applify.mixin.AppPlugin, ?applify.AppWithPlugin} )
        
        function tf = keyPressHandler(obj, src, evt)
            tf = false;
        end
        
        %onMousePressed(src, evt)

    end
    
    methods
        
        function openControlPanel(obj, mode)
            obj.editSettings()
        end
        
        function loadSettings(~)
            % This class does not have to load settings
        end
        function saveSettings(~)
            % This class does not have to save settings
        end
        
        function changeSetting(obj, name, value)
            obj.onSettingsChanged(name, value)
        end

        function showTip(obj, message)
            
            msgTime = max([1.5, numel(message)./30]);
            obj.PrimaryApp.displayMessage(message, [], msgTime)

        end
        
    end
    
    methods (Access = protected)
        
        function addPreviewOptions(obj)
            
            S = struct();
            S.Show = 'Preprocessed';
            S.Show_ = {'Preprocessed', 'Binarized'};
            
            obj.settings_.Preview = S;
            
        end
        
        function onPluginActivated(obj)
            
        end
        
        function onSettingsChanged(obj, name, value)
            
            switch name
                case 'RoiDiameter'
                    obj.settings.General.RoiDiameter = value;
                    obj.plotCellTemplates(value/2)   
                    
                case 'Show'
                    obj.settings.Preview.Show = value;
                    obj.changeImageToDisplay();
                    
                case 'PrctileForBinarization'
                    obj.settings.Preprocessing.PrctileForBinarization = value;
                    
                    if strcmp(obj.settings.Preview.Show, 'Binarized')
                        obj.updateImviewerDisplay()
                    end
                    
                case 'PrctileForBaseline'
                    obj.settings.Preprocessing.PrctileForBaseline = value;
                    obj.updateBackgroundImage()
                    obj.BackgroundOffset = 0;

                    if strcmp(obj.settings.Preview.Show, 'Static Background')
                        obj.showImageInImviewer(obj.StaticBackground, 'Static Background')
                    elseif strcmp(obj.settings.Preview.Show, 'Preprocessed')
                        obj.updateImviewerDisplay()
                    end
                    
                case 'SmoothingSigma'
                    obj.settings.Preprocessing.SmoothingSigma = value;
                    obj.BackgroundOffset = 0;
                    if strcmp(obj.settings.Preview.Show, 'Preprocessed')
                        obj.updateImviewerDisplay()
                    end
                    
                    
            end

        end
                        
    end
    
    methods (Static) % Inherited... 
        function getPluginIcon()
            
        end
    end
    
    methods (Access = private)
        
        function changeImageToDisplay(obj)
            
            hRoimanager = obj.PrimaryApp.getPluginHandle('Roimanager');
            imArray = hRoimanager.prepareImagedata();
            
            switch obj.settings.Preview.Show
                
                case 'Preprocessed'
                    updateFcn = @obj.getPreprocessedImage;
                    obj.setImviewerUpdateFunction(updateFcn)
                    obj.updateImviewerDisplay()

                case 'Binarized'
                    updateFcn = @obj.getBinarizedImage;
                    obj.setImviewerUpdateFunction(updateFcn)
                    obj.updateImviewerDisplay()
                    
                case 'Static Background'
                    image = obj.getBackgroundImage();
                    obj.showImageInImviewer(image, 'Static Background')
                

                otherwise
                    imArray = [];
                    
            end

        end
        
        function imArray = getPreprocessedImageArray(obj, imArray)
            
            import nansen.wrapper.abstract.OptionsAdapter
            opts = OptionsAdapter.ungroupOptions(obj.settings);
            
            if isempty(obj.CachePreprocessed)
                imArray = flufinder.module.preprocessImages(imArray, opts);
                obj.CachePreprocessed = imArray;
            else
                imArray = obj.CachePreprocessed;
            end
        end
            
        function imArray = getBinarizedImageArray(obj, imArray)
            
            import nansen.wrapper.abstract.OptionsAdapter
            opts = OptionsAdapter.ungroupOptions(obj.settings);
            
            if isempty(obj.CacheBinarized)
                imArray = obj.getPreprocessedImageArray(imArray);
                imArray = flufinder.module.binarizeImages(imArray, opts);
                obj.CacheBinarized = imArray;
            
            else
                imArray = obj.CacheBinarized;
            end
        end
        
        function image = getPreprocessedImage(obj, image)
            opts = obj.getUngroupedSettings();

            % Preprocess (subtract dynamic background)
            optsNames = {'SpatialFilterType', 'SmoothingSigma'};
            optsTmp = utility.struct.substruct(opts, optsNames);
            
            imageType = class(image);
            image = single(image);
            
            minValue = min(image(:));
            maxValue = max(image(:));
            
            image = flufinder.preprocess.removeBackground(image, optsTmp);
    
            % "Remove" the background
            image = image - obj.getBackgroundImage();
            
            obj.BackgroundOffset = min([obj.BackgroundOffset, mean(image(:))]);

            image = image - obj.BackgroundOffset;
            image = cast(image, imageType);

        end
        
        function image = getBinarizedImage(obj, image)
            
            opts = obj.getUngroupedSettings();
            imageType = class(image);
            
            image = obj.getPreprocessedImage(image);
            image = single(image);
            image = flufinder.module.binarizeImages(image, opts);

            image = image .* 255;
            image = cast(image, imageType);
            
        end
        
        function image = getBackgroundImage(obj)
            if isempty(obj.StaticBackground)
                obj.updateBackgroundImage()
            end
            image = obj.StaticBackground;
        end
        
        function updateBackgroundImage(obj)
            
            import flufinder.preprocess.computeStaticBackgroundImage
            
            imageArray = obj.getImageArray();
            opts = obj.getUngroupedSettings();
            
            bgImage = computeStaticBackgroundImage(imageArray, opts);
            
            obj.StaticBackground = bgImage;
            
        end
            
        function resetBackgroundImage(obj)
            obj.StaticBackground = [];
        end
        
        function plotGrid(obj)
            
        end
        
        function plotCellTemplates(obj, radius)
            
            % Todo: create a roimap and add a couple of round rois???
            
            if isempty(radius) || radius == 0
                return
            end
            
            [X, Y] = uim.shape.circle(radius);
            
            if isempty(obj.gobjectTransporter)
                obj.gobjectTransporter = applify.gobjectTransporter(obj.Axes);
            end
            
            
            % Assign the Ancestor App of the roigroup to the app calling
            % for its creation.
            
            
            if ~isempty(obj.hCellTemplates) % Update radius
                x0 = arrayfun(@(h) mean(h.XData), obj.hCellTemplates);
                y0 = arrayfun(@(h) mean(h.YData), obj.hCellTemplates);
                
                for i = 1:numel(x0)
                    h = obj.hCellTemplates(i);
                    h.XData = x0(i) + X - radius;
                    h.YData = y0(i) + Y - radius;
                end
                
            else % Initialize plots
                obj.hCellTemplates = gobjects(0);
                
                n = 25;
                theta = rand(1,n)*(2*pi);
                imRadius = min([obj.PrimaryApp.imWidth, obj.PrimaryApp.imHeight])./2;
                r = sqrt(rand(1,n)) * imRadius;
                [x0, y0] = pol2cart(theta, r);
                x0 = x0+imRadius;
                y0 = y0+imRadius;
                
                for i = 1:numel(x0)
                    h = patch(obj.Axes, x0(i)+X, y0(i)+Y, 'w', 'FaceAlpha', 0.4);
                    h.ButtonDownFcn = @(s,e) obj.gobjectTransporter.startDrag(h,e);
                    obj.hCellTemplates(i) = h;
                end

            end
            
        end
        
        function imArray = getImageArray(obj)
            persistent hRoimanager
            if isempty(hRoimanager)
                hRoimanager = obj.PrimaryApp.getPluginHandle('Roimanager');
            end
            
            imArray = hRoimanager.prepareImagedata();
        end
        
        function opts = getUngroupedSettings(obj)
            import nansen.wrapper.abstract.OptionsAdapter
            opts = OptionsAdapter.ungroupOptions(obj.settings);
        end
        
     end
end