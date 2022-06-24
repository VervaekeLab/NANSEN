classdef NoRMCorre < imviewer.ImviewerPlugin & nansen.processing.MotionCorrectionPreview
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
        TestResults struct = struct     % Store results from a pretest correction
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
            
            if ~ obj.PartialConstruction && isempty(obj.hSettingsEditor)
                obj.openControlPanel()
            end
            
            if ~nargout
                clear obj
            end
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
        
        function openControlPanel(obj)
            obj.plotGrid()
            obj.editSettings()
        end
        
        function run(obj)
        %RUN Superclass method for running the plugin algorithm
            obj.runAlign()
        end
        
        function runTestAlign(obj)
        %runTestAlign Run test correction and open results in new window
        
        % Run a motion correction processor on frames instead?
        
            % Check if saveResult or showResults is selected
            obj.assertPreviewSettingsValid()
            
            % Prepare save directory
            if obj.settings.Preview.saveResults
                [saveFolder, datePrefix] = obj.prepareSaveFolder();
                if isempty(saveFolder); return; end
            end
            
            % Get image data
            Y = obj.loadSelectedFrameSet();
                      
            imClass = class(Y);
            stackSize = size(Y);
            
            
            import nansen.wrapper.normcorre.*
            ncOptions = Options.convert(obj.settings, stackSize);
            
            if ~isa(Y, 'single') || ~isa(Y, 'double') 
                Y = single(Y);
            end
        
            [Y, ~, ~] = nansen.wrapper.normcorre.utility.correctLineOffsets(Y, 100);
            
            obj.ImviewerObj.displayMessage('Running NoRMCorre...')
            
            warning('off', 'MATLAB:mir_warning_maybe_uninitialized_temporary')
            [M, ncShifts, ref] = normcorre_batch(Y, ncOptions);
            warning('on', 'MATLAB:mir_warning_maybe_uninitialized_temporary')
            
            obj.TestResults(end+1).Shifts = ncShifts;
            obj.TestResults(end+1).Parameters = ncOptions;
            
            obj.MenuItem.PlotShifts.Enable = 'on';
            
            M = cast(M, imClass);
            
            obj.ImviewerObj.clearMessage;
            
         	% Show results from test aliging:
            if obj.settings.Preview.showResults
                h = imviewer(M);
                h.stackname = sprintf('%s - %s', obj.ImviewerObj.stackname, 'NoRMCorre Test Correction');                
            end
            
         	% Save results from test aliging:
            if obj.settings.Preview.saveResults
                getSavepath = @(name) fullfile(saveFolder, ...
                    sprintf('%s_%s', datePrefix, name ) );
                                
                save(getSavepath('nc_shifts.mat'), 'ncShifts')
                save(getSavepath('nc_opts.mat'), 'ncOptions')
                
                obj.saveProjections(Y, M, getSavepath)           
            end
        end
        
        function runAlign(obj)
         %runAlign Run correction on full image stack using a dummy session
         %
   
            folderPath = obj.settings.Export.SaveDirectory;
            if ~isfolder(folderPath); mkdir(folderPath); end

            dataSet = nansen.dataio.dataset.SingleFolderDataSet(folderPath, ...
                'DataSetID', obj.settings.Export.FileName );
            
            dataSet.addVariable('TwoPhotonSeries_Original', ...
                'Data', obj.ImviewerObj.ImageStack)
            
            nansen.wrapper.normcorre.Processor(obj.ImviewerObj.ImageStack,...
                obj.settings, 'DataIoModel', dataSet)
        end

        function sEditor = openSettingsEditor(obj)
        %openSettingsEditor Open editor for method options.    
        
        % Note: Override superclass method in order to set an extra
        % callback function (ValueChangedFcn) on the sEditor object
        
            sEditor = openSettingsEditor@imviewer.ImviewerPlugin(obj);
            %sEditor.ValueChangedFcn = @obj.onValueChanged;
            
            % Create default folderpath for saving results
            [folderPath, fileName] = fileparts( obj.ImviewerObj.ImageStack.FileName );
            folderPath = fullfile(folderPath, 'motion_correction_normcorre');
            
            % Need a better solution for this!
            idx = strcmp(sEditor.Name, 'Export');
            sEditor.dataOrig{idx}.SaveDirectory = folderPath;
            sEditor.dataEdit{idx}.SaveDirectory = folderPath;
            obj.settings_.Export.SaveDirectory = folderPath;
            
            sEditor.dataOrig{idx}.FileName = fileName;
            sEditor.dataEdit{idx}.FileName = fileName;
            obj.settings_.Export.FileName = fileName;
        end

    end
    
    methods (Access = protected)
        
        function onSettingsChanged(obj, name, value)
            
            % Call superclass method to deal with settings that are
            % general motion correction settings.
            onSettingsChanged@nansen.processing.MotionCorrectionPreview(obj, name, value)

            patchesFields = fieldnames(obj.settings.Configuration);
            templateFields = fieldnames(obj.settings.Template);
            
            switch name
                % Note: this needs to go before the patchesfield!
                case {'numRows', 'numCols', 'patchOverlap'}
                    obj.settings.Configuration.(name) = value;
                    obj.plotGrid()

                case patchesFields
                    obj.settings.Configuration.(name) = value;
                    
                case templateFields
                    obj.settings.Template.(name) = value;

                case {'firstFrame', 'numFrames', 'saveResults', 'showResults'}
                    obj.settings.Preview.(name) = value;
                    
                case 'runAlign'
                    obj.runAlign()
            end
        end
        
    end
    
    methods (Access = private) % Methods for plotting on imviewer
        
        function plotGrid(obj)
            % todo: use function from imviewer.plot 
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