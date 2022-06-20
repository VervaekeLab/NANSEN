classdef RoiSignalVideo < uim.handle & applify.mixin.HasSettings
    
    properties (Constant, Hidden = true)
        USE_DEFAULT_SETTINGS = false        % Ignore settings file
        DEFAULT_SETTINGS = struct(...       % Struct with default settings
            'sessiondataFilepath', '', ...
            'exportFolder_', 'uigetdir', ...
            'exportFolder', '', ...
            'exportAs_', {{'video', 'images'}}, ...
            'exportAs', 'video', ...
            'quality_', {{'high', 'medium', 'low'}}, ...
            'quality', 'medium', ...    
            'startingFrame', 1, ...
            'numberOfSamples', 1000, ...
            'speed', 5, ...
            'numberOfRois', 50, ...
            'roiColormap_', {{'Viridis', 'Inferno', 'Magma','Plasma'}}, ...
            'roiColormap', 'Viridis', ...
            'backgroundColor_', 'uisetcolor', ...
            'backgroundColor', [0,0,0], ...
            'foregroundColor_', 'uisetcolor', ...
            'foregroundColor', [70,90,90]./255, ...
            'fontSize', 16, ...
            'aspectRatio_', {{'16/9', '4/3'}}, ...
            'aspectRatio', '16/9', ...
            'addScalebar', false )
        
        % Maybe this should just be a long function instead of a class
        % Implement with roimanager. So that rois are interactively
        % selected, and then video is exported based on selection
    end
   
    
    properties
        imviewerRef
    end
    
    properties (Access = private)
        hFigure
        hAxImageDisplay
        hAxSignalDisplay
        hScalebar
        
        hRoiArray 
        hColoredRois
        hSignalData
        
        roiArray
        roiInd
        dffStacked
        timeVector
        umPerPix
        
        imageArray
        
        currentSample = 1;
        frameCount = 0;
        
        orignalImageDisplayUnits
        orignalImageDisplayPosition
    end
   
   
    
    
    methods
        function obj = RoiSignalVideo(imvieverRef)
            obj.imviewerRef = imvieverRef;
            
            obj.loadSettings()
            obj.imviewerRef.displayMessage('Preparing video export')
            
            sEditor = clib.structEditor(obj.settings, 'Set preferences for video export');
            sEditor.waitfor()

            if sEditor.wasCanceled
                obj.imviewerRef.clearMessage
                return
            else
                obj.settings = sEditor.dataEdit;
                obj.saveSettings()
            end
            
            %obj.editSettings()
            
            obj.setupFigure()
            obj.prepareData()
            
            obj.borrowImageDisplay()
            obj.plotRoisAndSignals()
            
            obj.imviewerRef.displayMessage('Creating video')
            obj.loopVideo()
            
            if strcmp(obj.settings.exportAs, 'video')
                obj.saveFramesToVideo()
            end
            
            obj.giveBackImageDisplay()
            obj.imviewerRef.clearMessage
            
            close(obj.hFigure)
            
            delete(obj)
            
        end
        
        
        function onFigureClosed(obj, ~, ~)
            obj.giveBackImageDisplay()
            obj.imviewerRef.clearMessage

            delete(obj.hFigure)
            delete(obj)
        end
        
        
        function setupFigure(obj)
        %setupFigure Setup figure for image and signal display.    
            figureHeight = obj.imviewerRef.imHeight;
            panelSpacing = 70;
            
            switch obj.settings.aspectRatio
                case '16/9'
                    figureAr = 900/400;
                case '4/3'
                    figureAr = 874/495;
            end
            
            figureWidth = figureHeight .* figureAr;
            figurePosition = [100, 100, figureWidth, figureHeight];
            
            obj.hFigure = figure('Position', figurePosition);
            obj.hFigure.MenuBar = 'none';
            
            % Create axes for image display and signal display
            obj.hAxImageDisplay = axes(obj.hFigure);
            obj.hAxSignalDisplay = axes(obj.hFigure);
            
            obj.hAxImageDisplay.Visible = 'off';

            obj.hAxImageDisplay.Units = 'pixel';
            obj.hAxSignalDisplay.Units = 'pixel';
            
            % Position the first axes with images.
            axPos = [0, 0, obj.imviewerRef.imWidth, obj.imviewerRef.imHeight];
            obj.hAxImageDisplay.Position = axPos;
                   
            % Position the second axes for signals.
            axPos(1) = axPos(3) + panelSpacing;
            axPos(3) = figureWidth - axPos(1) - 10;
            axPos(2) = panelSpacing;
            axPos(4) = axPos(4) - panelSpacing*1.5;
            
            obj.hAxSignalDisplay.Position = axPos;
            
            % Set background color of images and axes.
            obj.hFigure.Color = obj.settings.backgroundColor;
            obj.hAxImageDisplay.Color = obj.settings.backgroundColor;
            obj.hAxSignalDisplay.Color = obj.settings.backgroundColor;
            hold(obj.hAxSignalDisplay, 'on')
            
            set(obj.hFigure, 'InvertHardCopy', 'off');
            
        end
        
        
        function prepareData(obj)
            
            % Specify which sample indices to subset data with.
            numSamples = obj.settings.numberOfSamples;
            sampleInd = obj.settings.startingFrame + (0:numSamples-1);
            
            numRois = obj.settings.numberOfRois;
            
            % Load session data
            S = load(obj.settings.sessiondataFilepath);

            sdataVarname = {'sdata', 'sessionData', 'sData'};
            
            fields = fieldnames(S);
            
            isMatch = contains(sdataVarname, fields);
            field = sdataVarname{isMatch};
            
            sData = S.(field);
            
            obj.umPerPix = sData.meta2P.umPerPx_x .* 1e6;
            
            % Get roi array, dff and time vector from sData.
            obj.roiArray = sData.roiArray;
            
            obj.timeVector = sData.time(sampleInd); 
            dff = squeeze( sData.roisignals(2).dff );
            
            
            obj.roiInd = sort( randperm(numel(obj.roiArray), numRois) );

            
            % Prepare dff as lines stacked on top of each other
            dff = dff(:, sampleInd);
            dffN = dff ./ max(dff(:));
            dffN = dffN(obj.roiInd, :);

            % Stack lineedata on top of each other
            dffN = dffN + (1:size(dffN,1))';
             
            obj.dffStacked = dffN;
            
        end
        
        
        function borrowImageDisplay(obj)
            
            obj.imviewerRef.Axes.Parent = obj.hFigure;
            obj.orignalImageDisplayUnits = obj.imviewerRef.Axes.Units;
            obj.orignalImageDisplayPosition = obj.imviewerRef.Axes.Position;
            
            obj.imviewerRef.Axes.Units = 'pixel';
            obj.imviewerRef.Axes.Position = obj.hAxImageDisplay.Position;
            
            delete(obj.hAxImageDisplay)
            obj.hAxImageDisplay = obj.imviewerRef.Axes;
            
            obj.hFigure.CloseRequestFcn = @obj.onFigureClosed;
        end
        
        
        function giveBackImageDisplay(obj)
            obj.imviewerRef.Axes.Parent = obj.imviewerRef.Figure;
            uistack(obj.imviewerRef.Axes, 'bottom')
            uistack(obj.imviewerRef.Axes, 'up', 1)
            
            obj.imviewerRef.Axes.Units = obj.orignalImageDisplayUnits;
            obj.imviewerRef.Axes.Position = obj.orignalImageDisplayPosition;
            obj.hAxImageDisplay = [];
            
            delete(obj.hRoiArray)
            %delete(obj.hColoredRois)
            
            if obj.settings.addScalebar
                delete(obj.hScalebar.Text)
                delete(obj.hScalebar.Line)
            end
        end
        
        
        function plotRoisAndSignals(obj)
            [hl, ~] = drawRoiOutlines(obj.hAxImageDisplay, obj.roiArray);
            %set(hl, 'LineWidth', 1)
            
            obj.hRoiArray = hl;
            
            % Set colormap
            numRois = obj.settings.numberOfRois;
            
            % Use colormap for rois from settings...
            cMapFunc = str2func( lower(obj.settings.roiColormap) );
            
            cMap = cMapFunc(round( numRois*1.2) );
            numColors = size(cMap, 1);

            count = 1;
            for i = obj.roiInd
                hl(i).Color = cMap(numColors-numRois+count, :);
                hl(i).LineWidth = 1;
                count = count + 1;
            end
            
            
            if obj.settings.addScalebar
                
                obj.hScalebar = scalebar(obj.hAxImageDisplay, 'x', 100, 'microm', ...
                    'UnitFactor', obj.umPerPix, 'Location', 'southeastinside', ...
                    'marginX', 20, 'marginY', 20, 'Color', ones(1,3).*0.5);
                obj.hScalebar.Text.FontSize = obj.settings.fontSize;
                obj.hScalebar.Text.Color = obj.settings.foregroundColor;
                obj.hScalebar.Line.Color = obj.settings.foregroundColor;
            end
            
            
            
            % patch roi with a color;
% % %             for i = 1:numRois
% % %                [pObj(i), tObj] = patchTunedNeurons(obj.hAxImageDisplay, ...
% % %                    obj.roiArray, i, cMap(numColors-numRois+i, :));
% % %                pObj(i).FaceAlpha = 0.15;
% % %                delete(tObj)
% % %             end
% % %             
% % %             obj.hColoredRois = pObj;
            
            %numSamples = obj.settings.numberOfFrames;
            
            t = obj.timeVector(1:2);
            dff = obj.dffStacked(:, 1:2);
            
            h2 = plot(t, dff(:, 1:2)');
            set(h2, {'Color'}, arrayfun(@(i) cMap(i, :), numColors-numRois+1:numColors, 'uni', 0 )' )
            set(h2, 'LineWidth', 1)
            
            obj.hSignalData = h2;
            
            hold(obj.hAxSignalDisplay, 'on')
            obj.hAxSignalDisplay.XLim = obj.timeVector([1,end]);
            obj.hAxSignalDisplay.YLim = [0, numRois+1];

            
            obj.hAxSignalDisplay.XLabel.Color = obj.settings.foregroundColor;
            obj.hAxSignalDisplay.XLabel.String = 'Time (s)';
            obj.hAxSignalDisplay.XAxis.Color = obj.settings.foregroundColor;
            obj.hAxSignalDisplay.YLabel.Color = obj.settings.foregroundColor;
            obj.hAxSignalDisplay.YLabel.String = 'Number of Rois';
            obj.hAxSignalDisplay.YAxis.Color = obj.settings.foregroundColor;
            obj.hAxSignalDisplay.XAxis.FontSize = obj.settings.fontSize;
            obj.hAxSignalDisplay.YAxis.FontSize = obj.settings.fontSize;

        end
        

        function updateFrame(obj)
                        
            i = obj.currentSample;
            
            currentFrame = (i-1) + obj.settings.startingFrame;
            
            % Change image in imviewer
            obj.imviewerRef.goToFrame(currentFrame)
            
            % Update plotdata
            t = obj.timeVector(1:i+1);
            dff = obj.dffStacked(:, 1:i+1);
            
            [numRois, numSamples] = size(dff);
            dff = mat2cell(dff, ones(numRois,1), numSamples);
            t = repmat({t}, numRois, 1);
            
            set(obj.hSignalData, {'XData'}, t, {'YData'}, dff)
           
        end
        
        
        function loopVideo(obj)
            
            for i = 1:obj.settings.speed:obj.settings.numberOfSamples
                obj.currentSample = i;
                
                obj.updateFrame()
                
                obj.frameCount = obj.frameCount + 1;
                obj.saveCurrentFrame()
                
            end

        end
        
        
        function saveCurrentFrame(obj)
            
            % todo: implement save as video or save as images
            % todo: implement quality.
            % Todo: Implement export dir
            
            % big todo: why is print made with white bgcolor????
            
            
            if strcmp(obj.settings.exportAs, 'images')
            
                rootPath = fullfile(obj.settings.exportFolder, 'images');
                if ~exist(rootPath, 'dir'); mkdir(rootPath); end
                fileName = sprintf('image_%05d.png', obj.currentSample);
                savePath = fullfile(rootPath, fileName);

                switch obj.settings.quality
                    case 'high'
                        print(obj.hFigure, savePath, '-dpng', '-r300')
                    case 'medium'
                        %print(obj.hFigure, savePath, '-dpng', '-r150')
                        im = frame2im(getframe(obj.hFigure));
                        imwrite(im, savePath)
                    case 'low'
                        im = frame2im(getframe(obj.hFigure));
                        im = imresize(im, 0.5);
                        imwrite(im, savePath)
                end
                
                
            elseif strcmp(obj.settings.exportAs, 'video')
                
                switch obj.settings.quality
                    case 'high'
                        cdata = print(obj.hFigure, '-RGBImage', '-r300');
                    case 'medium'
                        %cdata = print(obj.hFigure, '-RGBImage', '-r150');
                        cdata = frame2im(getframe(obj.hFigure));
                    case 'low'
                        cdata = frame2im(getframe(obj.hFigure));
                        cdata = imresize(cdata, 0.5);
                end

                imSize = size(cdata);
                
                if isempty(obj.imageArray)
                    numFrames = numel(1:obj.settings.speed:obj.settings.numberOfSamples);
                    obj.imageArray = zeros([imSize, numFrames], 'uint8');
                end

                obj.imageArray(:, :, :, obj.frameCount) = cdata;

            end
            
            

        end
        
        
        function saveFramesToVideo(obj)
            % Todo: Implement export dir
            
            savePath = obj.settings.exportFolder;
            fileName = sprintf('%s_roi_demo_video.avi', datestr(now, 'yyyy_mm_dd_HHMMSS'));
            savePath = fullfile(savePath, fileName);
            stack2movie( savePath, obj.imageArray, 31 )
            
        end
        
        
        function convertPngsToVideo(obj)
            % Todo: Implement export dir
            
        end
        
        
    end
    
    methods (Access = protected)
        function onSettingsChanged(obj, name, value)
            
            
        end
    end
    
    
end