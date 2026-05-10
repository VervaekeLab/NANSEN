classdef FluFinder < imviewer.ImviewerPlugin & applify.mixin.ModalMethodPreviewController
%FluFinder Preview FluFinder ROI segmentation parameters in imviewer.
%
%   FluFinder is an imviewer plugin for adjusting FluFinder preprocessing
%   and segmentation options while previewing their effect on the current
%   image stack.
%
%   SYNTAX:
%       flufinderPlugin = nansen.plugin.imviewer.FluFinder(imviewerHandle)
%       flufinderPlugin = nansen.plugin.imviewer.FluFinder(imviewerHandle, options)
%       flufinderPlugin = nansen.plugin.imviewer.FluFinder(imviewerHandle, options, Name, Value, ...)

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
        
        function obj = FluFinder(imviewerHandle, varargin)
        %FluFinder Create a FluFinder plugin for an imviewer app.
        %
        %   flufinderPlugin = FluFinder(imviewerHandle) creates the plugin
        %   using default FluFinder options.
        %
        %   flufinderPlugin = FluFinder(imviewerHandle, options, Name, Value, ...)
        %   creates the plugin using a struct or nansen.manage.OptionsManager
        %   for options. Remaining arguments are plugin flags or property-value
        %   pairs, such as '-p' for partial construction.

            arguments
                imviewerHandle applify.AppWithPlugin
            end
            arguments (Repeating)
                varargin
            end

            [options, pluginArgs] = ...
                applify.mixin.HasOptionsManager.splitOptionsArgument(varargin);

            obj@applify.mixin.ModalMethodPreviewController(options)
            obj@imviewer.ImviewerPlugin(imviewerHandle, pluginArgs{:})

            hasRunMethodOnFinishArgument = any(cellfun(@(arg) ...
                (ischar(arg) || (isstring(arg) && isscalar(arg))) && ...
                strcmp(arg, 'RunMethodOnFinish'), pluginArgs));
            if ~hasRunMethodOnFinishArgument
                obj.RunMethodOnFinish = false;
            end
            
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
        
        %onMousePressed(obj, src, evt)

    end
    
    methods
        
        function openControlPanel(obj, mode)
            obj.editOptions()
        end

        function optionsEditor = openOptionsEditor(obj)
        %openOptionsEditor Open editor for method options.
            optionsEditor = openOptionsEditor@applify.mixin.ModalMethodPreviewController(obj);
            obj.arrangeAppWindows(optionsEditor)
        end

        function run(~)
        %run Run FluFinder segmentation.
            error('nansen:plugin:imviewer:FluFinder:RunNotImplemented', ...
                'FluFinder does not implement run yet.')
        end
        
        function changeOption(obj, name, value)
            obj.onOptionsChanged(name, value)
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
            
            obj.Options_.Preview = S;
            
        end
        
        function onPluginActivated(obj)
            onPluginActivated@imviewer.ImviewerPlugin(obj)
            % Placeholder in case specialized operations need to run here
        end
        
        function onOptionsChanged(obj, name, value)
            
            switch name
                case 'RoiDiameter'
                    obj.Options.General.RoiDiameter = value;
                    obj.plotCellTemplates(value/2)
                    
                case 'Show'
                    obj.Options.Preview.Show = value;
                    obj.changeImageToDisplay();
                    
                case 'PrctileForBinarization'
                    obj.Options.Preprocessing.PrctileForBinarization = value;
                    
                    if strcmp(obj.Options.Preview.Show, 'Binarized')
                        obj.updateImviewerDisplay()
                    end
                    
                case 'PrctileForBaseline'
                    obj.Options.Preprocessing.PrctileForBaseline = value;
                    obj.updateBackgroundImage()
                    obj.BackgroundOffset = 0;

                    if strcmp(obj.Options.Preview.Show, 'Static Background')
                        obj.showImageInImviewer(obj.StaticBackground, 'Static Background')
                    elseif strcmp(obj.Options.Preview.Show, 'Preprocessed')
                        obj.updateImviewerDisplay()
                    end
                    
                case 'SmoothingSigma'
                    obj.Options.Preprocessing.SmoothingSigma = value;
                    obj.BackgroundOffset = 0;
                    if strcmp(obj.Options.Preview.Show, 'Preprocessed')
                        obj.updateImviewerDisplay()
                    end
            end
        end
    end
    
    methods (Access = private)
        
        function changeImageToDisplay(obj)
            
            hRoimanager = obj.PrimaryApp.getPluginHandle('Roimanager');
            imArray = hRoimanager.prepareImagedata();
            
            switch obj.Options.Preview.Show
                
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
            opts = OptionsAdapter.ungroupOptions(obj.Options);
            
            if isempty(obj.CachePreprocessed)
                imArray = flufinder.module.preprocessImages(imArray, opts);
                obj.CachePreprocessed = imArray;
            else
                imArray = obj.CachePreprocessed;
            end
        end
            
        function imArray = getBinarizedImageArray(obj, imArray)
            
            import nansen.wrapper.abstract.OptionsAdapter
            opts = OptionsAdapter.ungroupOptions(obj.Options);
            
            if isempty(obj.CacheBinarized)
                imArray = obj.getPreprocessedImageArray(imArray);
                imArray = flufinder.module.binarizeImages(imArray, opts);
                obj.CacheBinarized = imArray;
            
            else
                imArray = obj.CacheBinarized;
            end
        end
        
        function image = getPreprocessedImage(obj, image)
            opts = obj.getUngroupedOptions();

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
            
            opts = obj.getUngroupedOptions();
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
            opts = obj.getUngroupedOptions();
            
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
        
        function opts = getUngroupedOptions(obj)
            import nansen.wrapper.abstract.OptionsAdapter
            opts = OptionsAdapter.ungroupOptions(obj.Options);
        end
     end
end
