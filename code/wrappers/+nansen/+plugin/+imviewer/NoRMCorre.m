classdef NoRMCorre < imviewer.ImviewerPlugin
%NoRMCorre Imviewer plugin for NoRMCorre method
%
%   SYNTAX:
%       normcorrePlugin = NoRMCorre(imviewerObj)
%
%       normcorrePlugin = NoRMCorre(imviewerObj, optionsManagerObj)
%
%   INHERITANCE:
%       |- imviewer.ImviewerPlugin
%           |- applify.mixin.AppPlugin
%               |-  applify.mixin.UserSettings
%               |-  matlab.mixin.Heterogeneous
%               |-  uiw.mixin.AssignPVPairs


%   TODO:
%       [v] Subclass from imviewer plugin class.
%       [ ]  migrate plugin to new instance if results open in new window
%       [v] Implement options based on OptionsManager & normcorre options.
%       [ ] Should it have a DataIoModel property? Then its easy to plug in
%           whatever model (i.e) a session model and save data consistently.
    
    
    properties (Constant, Hidden = true)
        USE_DEFAULT_SETTINGS = false    % Ignore settings file
        DEFAULT_SETTINGS = []           % This class uses an optionsmanager
    end
        
    properties (Constant) % Implementation of AppPlugin property
        Name = 'NoRMCorre'
    end
    
    properties
        TestResults struct      % Store results from a pretest correction
    end
    
    properties (Access = private)
        hGridLines
        hGridOverlaps
        hShiftArrows
        frameChangeListener
    end
    
    
    methods % Structors 
        
        function obj = NoRMCorre(varargin)
        %NoRMCorre Create an instance of the NoRMCorre plugin for imviewer

            obj@imviewer.ImviewerPlugin(varargin{:})
                        
            obj.plotGrid()
            obj.editSettings()
            
            if ~nargout; clear obj; end

        end
        
        function delete(obj)
            if ~isempty(obj.hGridLines)
                delete(obj.hGridLines)
                delete(obj.hGridOverlaps)
            end
            
            if ~isempty(obj.frameChangeListener)
                delete(obj.frameChangeListener)
            end
        end
        
        function loadSettings(~) % override to do nothing
            % This class does not have to load settings
        end 
        function saveSettings(~) % override to do nothing
            % This class does not have to save settings
        end
        
    end
    
    methods (Access = protected) % Plugin derived methods
        
        function createSubMenu(obj)
        %createSubMenu Create sub menu items for the normcorre plugin
        
            m = findobj(obj.ImviewerObj.Figure, 'Text', 'Align Images');
            
            obj.MenuItem(1).PlotShifts = uimenu(m, 'Text', 'Plot NoRMCorre Shifts', 'Enable', 'off');
            obj.MenuItem(1).PlotShifts.Callback = @obj.plotResults;
            
        end
        
        function onSettingsEditorClosed(obj)
        %onSettingsEditorClosed "Callback" for when settings editor exits
            delete(obj.hGridLines)
            delete(obj.hGridOverlaps)
        end
        
        function assignDefaultOptions(obj)
            functionName = 'nansen.wrapper.normcorre.Processor';
            obj.OptionsManager = nansen.manage.OptionsManager(functionName);
            obj.settings = obj.OptionsManager.getOptions;
        end
        
    end
    
    methods % Methods for running normcorre motion correction
        
        function run(obj)
        %RUN Superclass method for running the plugin algorithm
            obj.runAlign()
        end
        
        function imArray = loadSelectedFrameSet(obj)
        %loadSelectedFrameSet Load images for frame interval in settings
            
            imArray = [];
                        
            % Get frame interval from settings
            firstFrame = obj.settings.Preview.firstFrame;            
            lastFrame = (firstFrame-1) + obj.settings.Preview.numFrames;
            
            % Make sure we dont grab more than is available.
            firstFrame = max([1, firstFrame]);
            firstFrame = min(firstFrame, obj.ImviewerObj.ImageStack.NumTimepoints);
            lastFrame = min(lastFrame, obj.ImviewerObj.ImageStack.NumTimepoints);
            
            if lastFrame-firstFrame < 2
                errMsg = 'Error: Need at least two frames to run motion correction';
                obj.ImviewerObj.displayMessage(errMsg)
                pause(2)
                obj.ImviewerObj.clearMessage()
                return
            end
            
            obj.ImviewerObj.displayMessage('Loading Data...')

            % Todo: Enable imagestack preprocessing...
                
            imArray = obj.ImviewerObj.ImageStack.getFrameSet(firstFrame:lastFrame);
            imArray = imArray(8:end, :, :);
            
        end
        
        function runTestAlign(obj)
        %runTestAlign Run test correction and open results in new window
        %
        %   Todo: Should develop this further, and implement a way to save
        %   the results of the test aligning...
        
        % Run a motion correction processor on frames instead?
        
            Y = obj.loadSelectedFrameSet();
                      
            imClass = class(Y);
            stackSize = size(Y);
            
            import nansen.wrapper.normcorre.*
            ncOptions = Options.convert(obj.settings, stackSize);
            
            if ~isa(Y, 'single') || ~isa(Y, 'double') 
                Y = single(Y);
            end
            
            obj.ImviewerObj.displayMessage('Running NoRMCorre...')
            [M, ncShifts, ref] = normcorre_batch(Y, ncOptions);
            
            obj.TestResults.Shifts = ncShifts;
            obj.TestResults.Parameters = ncOptions;
            

            obj.MenuItem.PlotShifts.Enable = 'on';
            
            M = cast(M, imClass);
            
            obj.ImviewerObj.clearMessage;
            
            
            if obj.settings.Preview.showResults
                h = imviewer(M);
                h.stackname = sprintf('%s - %s', obj.ImviewerObj.stackname, 'NoRMCorre Test Correction');                
            else
                
% %                 filePath = obj.ImviewerObj.ImageStack.FileName;
% %                 delete(obj.ImviewerObj.ImageStack)
% %                 
% %                 obj.ImviewerObj.ImageStack = imviewer.ImageStack(M);
% %                 obj.ImviewerObj.ImageStack.filePath = filePath;
% %                 obj.ImviewerObj.updateImage();
% %                 obj.ImviewerObj.updateImageDisplay();
% %                 
% %                 obj.MenuItem.PlotShifts.Enable = 'on';
                
            end
            
         	% Todo: implement saving of results from test aliging
            
% %             if ~isempty(obj.settings.Export.PreviewSaveFolder)
% %                 
% %                 saveDir = obj.settings.Export.PreviewSaveFolder;
% %                 if ~exist(saveDir, 'dir'); mkdir(saveDir); end
% %                 
% %                 [~, fileName, ~] = fileparts(obj.ImviewerObj.ImageStack.filePath);
% %                 
% %                 fileNameShifts = sprintf(fileName, '_nc_shifts.mat');
% %                 fileNameOpts = sprintf(fileName, '_nc_opts.mat');
% %                 
% %                 save(fullfile(saveDir, fileNameShifts), 'ncShifts')
% %                 save(fullfile(saveDir, fileNameOpts), 'ncOptions')
% %             end
            
        end
        
        function runAlign(obj)
         %runAlign Run correction on full image stack using a dummy session
   
            pathStr = obj.ImviewerObj.ImageStack.FileName;
            
            hSession = nansen.metadata.schema.dummy.TwoPhotonSession( pathStr );

            %%hSession = nansen.metadata.type.Session( pathStr );
            
            ophys.twophoton.process.motionCorrection.normcorre(hSession, obj.settings);
            
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
    
    methods (Access = private) % Methods for plotting on imviewer
        
        function plotGrid(obj)
            
            xLim = [1,obj.ImviewerObj.imWidth];
            yLim = [1,obj.ImviewerObj.imHeight];
            
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
            
            h = plot(obj.ImviewerObj.Axes, xDataVert, yDataVert, xDataHorz, yDataHorz);
            obj.hGridLines = h;
            set(obj.hGridLines, 'Color', ones(1,3)*0.5);
            set(obj.hGridLines, 'HitTest', 'off', 'Tag', 'NorRMCorre Gridlines');
            
            
            xDataVert = cat(1, xDataVert, xDataVert);
            xDataVert(1:2, :) = xDataVert(1:2, :) - obj.settings.Configuration.patchOverlap(2)/2;
            xDataVert(3:4, :) = xDataVert(3:4, :) + obj.settings.Configuration.patchOverlap(2)/2;
            yDataVert = cat(1, yDataVert, flipud(yDataVert));
            
            h2 = patch(obj.ImviewerObj.Axes, xDataVert, yDataVert, 'w');
            set(h2, 'FaceAlpha', 0.15, 'HitTest', 'off', 'Tag', 'NorRMCorre Grid Overlaps')
            
            xDataHorz = cat(1, xDataHorz, flipud(xDataHorz));
            yDataHorz = cat(1, yDataHorz, yDataHorz);
            yDataHorz(1:2, :) = yDataHorz(1:2, :) - obj.settings.Configuration.patchOverlap(1)/2;
            yDataHorz(3:4, :) = yDataHorz(3:4, :) + obj.settings.Configuration.patchOverlap(1)/2;
            
            h3 = patch(obj.ImviewerObj.Axes, xDataHorz, yDataHorz, 'w');
            set(h3, 'FaceAlpha', 0.15, 'HitTest', 'off')
            
            obj.hGridOverlaps = [h2, h3];
            set(obj.hGridOverlaps, 'EdgeColor', 'none')
            
            % could do: implement 64x2 handles with nans and update x/ydata
            % of appropriate number of handles.
            
        end
        
        function plotResults(obj, ~, ~)
            
            % Convert shifts indices to x,y coordinates
            
            iFrame = obj.ImviewerObj.currentFrameNo;
            shifts = obj.TestResults.Shifts;
            if iFrame > numel(shifts); return; end
            
            tmpShifts = shifts(iFrame).shifts_up;
            
            [numRows, numCols, ~, ~] = size(tmpShifts);
            
            Y = linspace(1, obj.ImviewerObj.imHeight, numRows+1);
            X = linspace(1, obj.ImviewerObj.imWidth, numCols+1);
            
            Y = Y(2:end) - mean(diff(Y))/2;
            X = X(2:end) - mean(diff(X))/2;
            
            [xx, yy] = ndgrid(X, Y);
            
            dy = tmpShifts(:, :, :, 1);
            dx = tmpShifts(:, :, :, 2);

            if isempty(obj.hShiftArrows)
                h = quiver(obj.ImviewerObj.Axes, xx', yy', -dx, -dy, 0);
                h.Color = ones(1,3)*0.8;
                obj.hShiftArrows = h;
                obj.hShiftArrows.LineWidth = 1;
                obj.hShiftArrows.AutoScaleFactor = 0.2;
                obj.hShiftArrows.HitTest = 'off';
                
                el = addlistener(obj.ImviewerObj, 'currentFrameNo', 'PostSet', @(s,e)obj.plotResults(s,e) );
                obj.frameChangeListener = el;
            else
                set(obj.hShiftArrows, 'XData', xx', 'YData', yy', 'UData', dx, 'VData', dy)
            end
        end
        
        function updateResults(obj)
            % Todo
        end

    end
    
end