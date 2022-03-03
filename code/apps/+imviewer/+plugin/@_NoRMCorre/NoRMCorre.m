classdef NoRMCorre < uim.handle % & applify.mixin.UserSettings
    
    % Todo: migrate plugin to new instance if results open in new window
    
    % Todo: Start from file/session/imviewer
    %   [ ] Add fileref property
    %   [ ] Subclass from imviewer plugin class.
    %   [ ] Add session ref property (or combine with previous)
    %   [ ] Implement options based on OptionsManager & normcorre options.
    %   [ ] Improve implementation of options! Right now its not very
    %       clear how data is flowing...
    
    properties (Constant, Hidden = true)
        USE_DEFAULT_SETTINGS = false        % Ignore settings file
        DEFAULT_SETTINGS = imviewer.plugin.NoRMCorre.getNormCorreDefaultSettings()
    end
    
    properties
        imviewerRef
        shifts
        opts
        
        wasAborted
        
        settings
        settingsName
    end
    
    properties (Access = private)
        
        hGridLines
        hGridOverlaps
        
        hShiftArrows
        mItemPlotResults
        
        frameChangeListener
        
    end
    
    
    methods
        
        function obj = NoRMCorre(hViewer, optsStruct)
            
            if any( contains({hViewer.plugins.pluginName}, 'normcorre') )
                IND = contains({hViewer.plugins.pluginName}, 'normcorre');
                obj = hViewer.plugins(IND).pluginHandle;
                %return;
            else
                hViewer.plugins(end+1).pluginName = 'normcorre';
                hViewer.plugins(end).pluginHandle = obj;  
                obj.imviewerRef = hViewer;
                %obj.loadSettings()
                
                if nargin < 2 || isempty(optsStruct)
                    [obj.settings, obj.settingsName] = nansen.OptionsManager('nansen.wrapper.normcorre.Processor').getOptions;
                else
                    obj.settings = optsStruct;
                end
                obj.addMenuItem()
            end
            

            obj.plotGrid()
            obj.editSettings()
            
            if ~nargout; clear obj; end

        end
        
        
        function delete(obj)
            if ~isempty(obj.hGridLines)
                delete(obj.hGridLines)
                delete(obj.hGridOverlaps)
            end
        end
        
        
        function addMenuItem(obj)
            
            m = findobj(obj.imviewerRef.Figure, 'Text', 'Align Images');
            
            obj.mItemPlotResults = uimenu(m, 'Text', 'Plot NoRMCorre Shifts', 'Enable', 'off');
            obj.mItemPlotResults.Callback = @obj.plotResults;
            
        end
        
        
        function runTestAlign(obj)
            
            % Get images
            firstFrame = obj.settings.Preview.firstFrame;            
            lastFrame = (firstFrame-1) + obj.settings.Preview.numFrames;
            
            
            
            % Make sure we dont grab more than is available.
            firstFrame = min(firstFrame, obj.imviewerRef.ImageStack.NumTimepoints);
            lastFrame = min(lastFrame, obj.imviewerRef.ImageStack.NumTimepoints);
            
            if lastFrame-firstFrame < 2
                errMsg = 'Error: Need at least two frames to run motion correction';
                obj.imviewerRef.displayMessage(errMsg)
                pause(2)
                obj.imviewerRef.clearMessage()
                return
            end
            
            Y = obj.imviewerRef.ImageStack.getFrameSet(firstFrame:lastFrame);
            
            obj.imviewerRef.displayMessage('Loading Data...')
            
            imClass = class(Y);

            Y = Y(8:end, :, :);
            
            %Y = stack.makeuint8(Y);

            
            % Get normcorre settings
            %[d1,d2,d3] = size(Y);
            
            stackSize = size(Y);
            
            import nansen.wrapper.normcorre.*
            ncOptions = Options.convert(obj.settings, stackSize);
            
            
            if ~isa(Y, 'single') || ~isa(Y, 'double') 
                Y = single(Y);
            end
            
            
            obj.imviewerRef.displayMessage('Running NoRMCorre...')
            [M, ncShifts, ref] = normcorre_batch(Y, ncOptions);
            
            obj.shifts = ncShifts;
            obj.opts = ncOptions;
            
            obj.mItemPlotResults.Enable = 'on';
            
            M = cast(M, imClass);
            
            obj.imviewerRef.clearMessage;
            
            
            if obj.settings.Preview.showResults
                h = imviewer(M);
                h.stackname = sprintf('%s - %s', obj.imviewerRef.stackname, 'NoRMCorre test correction');                
            else
% %                 filePath = obj.imviewerRef.ImageStack.FileName;
% %                 delete(obj.imviewerRef.ImageStack)
% %                 
% %                 obj.imviewerRef.ImageStack = imviewer.ImageStack(M);
% %                 obj.imviewerRef.ImageStack.filePath = filePath;
% %                 obj.imviewerRef.updateImage();
% %                 obj.imviewerRef.updateImageDisplay();
% %                 
% %                 obj.mItemPlotResults.Enable = 'on';
                
            end
            
            if ~isempty(obj.settings.Export.PreviewSaveFolder)
                
                saveDir = obj.settings.Export.PreviewSaveFolder;
                if ~exist(saveDir, 'dir'); mkdir(saveDir); end
                
                [~, fileName, ~] = fileparts(obj.imviewerRef.ImageStack.filePath);
                
                fileNameShifts = sprintf(fileName, '_nc_shifts.mat');
                fileNameOpts = sprintf(fileName, '_nc_opts.mat');
                
                save(fullfile(saveDir, fileNameShifts), 'ncShifts')
                save(fullfile(saveDir, fileNameOpts), 'ncOptions')

            end
            
        end
        
        
        function runAlign(obj)
            
            pathStr = obj.imviewerRef.ImageStack.FileName;
            
            hSession = nansen.metadata.schema.dummy.TwoPhotonSession( pathStr );

            %%hSession = nansen.metadata.type.Session( pathStr );
            
            ophys.twophoton.process.motionCorrection.normcorre(hSession, obj.settings);
            
        end
        
        
        function plotGrid(obj)
            
            xLim = [1,obj.imviewerRef.imWidth];
            yLim = [1,obj.imviewerRef.imHeight];
            
            numRows = obj.settings.Configuration.numRows;
            numCols = obj.settings.Configuration.numCols;

            xPoints = linspace(xLim(1),xLim(2), numCols+1);
            yPoints = linspace(yLim(1),yLim(2), numRows+1);
            
            xPoints = xPoints(2:end-1);
            yPoints = yPoints(2:end-1);

            xDataVert = cat(1, xPoints, xPoints);
            yDataVert = [repmat(yLim(1), 1, numCols-1); repmat(yLim(2), 1, numCols-1)];
            xDataHorz = [repmat(xLim(1), 1, numRows-1); repmat(xLim(2), 1, numRows-1)];
            yDataHorz = cat(1, yPoints, yPoints);

            
            if ~isempty(obj.hGridLines)
                delete(obj.hGridLines)
                delete(obj.hGridOverlaps)
            end
            
            h = plot(obj.imviewerRef.Axes, xDataVert, yDataVert, xDataHorz, yDataHorz);
            obj.hGridLines = h;
            set(obj.hGridLines, 'Color', ones(1,3)*0.5);
            set(obj.hGridLines, 'HitTest', 'off', 'Tag', 'NorRMCorre Gridlines');
            
            
            xDataVert = cat(1, xDataVert, xDataVert);
            xDataVert(1:2, :) = xDataVert(1:2, :) - obj.settings.Configuration.patchOverlap(2)/2;
            xDataVert(3:4, :) = xDataVert(3:4, :) + obj.settings.Configuration.patchOverlap(2)/2;
            yDataVert = cat(1, yDataVert, flipud(yDataVert));
            
            h2 = patch(obj.imviewerRef.Axes, xDataVert, yDataVert, 'w');
            set(h2, 'FaceAlpha', 0.15, 'HitTest', 'off', 'Tag', 'NorRMCorre Grid Overlaps')
            
            xDataHorz = cat(1, xDataHorz, flipud(xDataHorz));
            yDataHorz = cat(1, yDataHorz, yDataHorz);
            yDataHorz(1:2, :) = yDataHorz(1:2, :) - obj.settings.Configuration.patchOverlap(1)/2;
            yDataHorz(3:4, :) = yDataHorz(3:4, :) + obj.settings.Configuration.patchOverlap(1)/2;
            
            h3 = patch(obj.imviewerRef.Axes, xDataHorz, yDataHorz, 'w');
            set(h3, 'FaceAlpha', 0.15, 'HitTest', 'off')
            
            obj.hGridOverlaps = [h2, h3];
            set(obj.hGridOverlaps, 'EdgeColor', 'none')
            
            % could do: implement 64x2 handles with nans and update x/ydata
            % of appropriate number of handles.
            
        end
        
        
        function plotResults(obj, ~, ~)
            
            % Convert shifts indices to x,y coordinates
            
            iFrame = obj.imviewerRef.currentFrameNo;
            if iFrame > numel(obj.shifts); return; end
            
            tmpShifts = obj.shifts(iFrame).shifts_up;
            
            [numRows, numCols, ~, ~] = size(tmpShifts);
            
            Y = linspace(1, obj.imviewerRef.imHeight, numRows+1);
            X = linspace(1, obj.imviewerRef.imWidth, numCols+1);
            
            Y = Y(2:end) - mean(diff(Y))/2;
            X = X(2:end) - mean(diff(X))/2;
            
            [xx, yy] = ndgrid(X, Y);
            
            dy = tmpShifts(:, :, :, 1);
            dx = tmpShifts(:, :, :, 2);

            if isempty(obj.hShiftArrows)
                h = quiver(obj.imviewerRef.Axes, xx', yy', -dx, -dy, 0);
                h.Color = ones(1,3)*0.8;
                obj.hShiftArrows = h;
                obj.hShiftArrows.LineWidth = 1;
                obj.hShiftArrows.AutoScaleFactor = 0.2;
                obj.hShiftArrows.HitTest = 'off';
                
                el = addlistener(obj.imviewerRef, 'currentFrameNo', 'PostSet', @(s,e)obj.plotResults(s,e) );
                obj.frameChangeListener = el;
            else
                set(obj.hShiftArrows, 'XData', xx', 'YData', yy', 'UData', dx, 'VData', dy)
            end
        end
        
        
        function updateResults(obj)
            
            
        end
        
        
        function editSettings(obj)
%             sCell = struct2cell(obj.settings);
            names = fieldnames(obj.settings);
% 
            titleStr = 'NoRMCorre Parameters';
%             
            callbacks = arrayfun(@(i) @obj.onSettingsChanged, 1:numel(names), 'uni', 0);
%             
%             sCellOut = tools.editStruct(sCell, nan, titleStr, ...
%                         'Name', names, 'Callback', callbacks);
            
            optManager = nansen.OptionsManager('nansen.wrapper.normcorre.Processor', obj.settings);
          
            
            
% %             obj.settings = tools.editStruct(obj.settings, nan, titleStr, ...
% %                 'OptionsManager', optManager, 'Callback', callbacks, ...
% %                 'CurrentOptionsSet',  obj.settingsName);
               
            sEditor = structeditor(obj.settings, 'Title', titleStr, ...
                'OptionsManager', optManager, 'Callback', callbacks, ...
                'CurrentOptionsSet',  obj.settingsName);
                    
            sEditor.waitfor()

            if ~sEditor.wasCanceled
                obj.settings = sEditor.dataEdit;
            end
            
            obj.wasAborted = sEditor.wasCanceled;
            delete(sEditor)
                    
            %obj.settings = cell2struct(sCellOut, names);
            %obj.saveSettings()
            
            delete(obj.hGridLines)
            delete(obj.hGridOverlaps)
            
            drawnow
            
            if ~obj.wasAborted
                obj.runAlign;
            end
        end
        
    end
    
    methods (Access = protected)
        function onSettingsChanged(obj, name, value)
            
            patchesFields = fieldnames(obj.settings.Configuration);
            templateFields = fieldnames(obj.settings.Template);
            
            switch name
                case {'numRows', 'numCols', 'patchOverlap'}
                    obj.settings.Configuration.(name) = value;
                    obj.plotGrid()
                    
                case patchesFields
                    obj.settings.Configuration.(name) = value;
                    
                case templateFields
                    obj.settings.Template.(name) = value;
                    
                case {'firstFrame', 'numFrames', 'openResultInNewWindow'}
                    obj.settings.Preview.(name) = value;
                    
                case 'run'
                    obj.runTestAlign()
                    
                case 'runAlign'
                    obj.runAlign()
                    
            end
        end
    end
    
    methods (Static)
        settings = getNormCorreDefaultSettings()
    end
    
    
end