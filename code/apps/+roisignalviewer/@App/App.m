classdef App < signalviewer.App & roimanager.roiDisplay
% Class for interactively plotting and exploring roi signals    
%
%
%   EXAMPLES:
%       
%   Alternative 1:
%       roiSignalViewer.App() opens a signal viewer instance without any data
%
%   Alternative 2:
%       roiSignalViewer.App(filePath) opens a signal viewer instance based on
%       file given as input
%
%   Alternative 3:
%       roiSignalViewer.App(roiSignalArray) opens a signal viewer instance
%       based on an instance of a RoiSignalArray
%


%   Todo:
%       [X] Bug when selecting rois and plotting signals. Sometimes many
%           rois are selected when only one roi is selected. Can be reproduced
%           by placing a drawnow in updateSignalPlot.
%   
%       [x] Legend does not work when lines are deleted. Should update it
%           whenever lines are reset

%       [ ] Also, use context menu for adding or removing signals from
%           signals to show... (not legend)
%
%
%       [x] Signals are calculated twice... Fix!
%
%       [ ] Y limits should be fixed based on magnitude of full signals.
%       Also, need to set ylimExtreme on each update...
%
%       [ ] HOW DO I ORGANIZE PLOT HANDLES???
%           - I want to plot signal type by signaltype. That means, for
%           each signal type i will plot one ore more signals in a go.
%           - The number of plots for each signal type should always be the
%           same
%           -  The number of lines might increase or decrease. Is this
%           fine, or should I expand handles when needed....?
%           - Need a method for creating many time series arrays in one go.
%            - Should multiple signals belong to one time series array or
%            multiple??
%   
%       [ ] Should this class inherit the roidisplay??? i guess...
%       [ ] Implement one color for each signal and color each roi in a
%           color shade.
%       [ ] Implement alternative way of displaying deconvolved signals...
%       [ ] Implement construction based on nSamples x nRois matlab array.
%       [ ] Implement method for when gui is activated... (made visible)
%       [ ] Store handles for the roi plots. 
%       [ ] Keep handle for each roi? Keep handle for each signal type?
%       [ ] Use tsArray??? There were some time delays in debug mode, but
%           otherwise its not a problem.Test with many rois....
%       [ ] Implement modes, multiroi, multisignaltype, history plot
%
%       [x] Implement buttons for selecting which signals to show
%       [x] Implement methods for plotting different signal types?
%       [x] Reset signals but only of given roi indices...
%       [ ] Is there a clean way to update color of roi in roiMap when 
%           signals are plotted given some color here?
%       [x] Implement a 'history plot'. I.e when roi is updated, keep older
%           versions but fade them
%       [x] Set options for signal extraction / processing and live update on plot. 
%       [ ] Organize above point better. 
%
%       [ ] Label showing number of roi(s) that are selected

    
%       Roimanager functionality that can be made into methods
%       [ ] Switching between left and right y-axis and making sure each
%           ylim is updated.
%       [ ] handles for lines are stored in struct array with fieldnames
%           for each signaltype.. Can I find a cleaner way?
%       [ ] Prepare colors for lines.
%       [x] Append and overwrite modes


%   Inherited properties:
%       RoiGroup            % RoiGroup object



    properties
        DisplayMode = 'normal' % 'stacked' | 'imagesc' | 'normal'
        SignalsToDisplay = {'roiMeanF'};
        HistoryOn = false;
    end
    
    properties (Dependent)
        ShowRoiSignalOptionsOnMenu; % TEMP: should remove
    end
    
    properties 
        RoiSignalArray      % RoiSignalArray object
        DisplayedRoiIndices % List of indices for currently displayed rois
        % Todo: Replace above with SelectedRois and VisibleRois
    end

    properties (Access = protected)
        
        Parameters % signal extraction.
        
        SignalExtractionOptions = nansen.twophoton.roisignals.extract.getDefaultParameters();
        DeconvolutionOptions = nansen.twophoton.roisignals.getDeconvolutionParameters();
        DffOptions = nansen.twophoton.roisignals.computeDff();
                
        hLineObjects = struct()          % Line handle for signals in signal plot
        
        %signalLegend
        roiLegend
        
        SignalSelectionDropdown
        DropdownCloseListener
    end

    properties (Access = private)
        isBusy = false
    end
    
    properties (Transient, Access=private)
        roiSignalsChangedListener event.listener %Listener to changes on roi signal data
    end %properties
    
    
    methods % Constructor
        
        function obj = App(varargin)
            
            obj@signalviewer.App(varargin{:})
            
            tf = cellfun(@(c) isa(c, 'nansen.roisignals.RoiSignalArray'), varargin);
            roiSignalArray = varargin{tf};
            
            obj.RoiSignalArray = roiSignalArray;
            
            % Add listener to listen for event when roi signals are changed 
            obj.roiSignalsChangedListener = addlistener(obj.RoiSignalArray, ...
                'RoiSignalsChanged', @obj.onRoiSignalsChanged );
            
            obj.nSamples = obj.RoiSignalArray.NumFrames;
            
            % Update x limits!
            obj.setNewXLims()
            
            obj.initializeTimeSeriesObjects()

            %obj.createSignalSelectionDropdown()
            delete(obj.hScrollbarX);obj.hScrollbarX=[];
            delete(obj.hScrollPanelX);obj.hScrollPanelX=[];
            
            
            callbackFcn = @obj.onQuickZoomSelectionChanged;
            signalviewer.createQuickZoomLabels(obj.Panel, obj.nSamples, callbackFcn)
            
            %obj.addPlotToolbar()

            % Temp
            obj.hScrollPanelY.Visible = 'off';
            
            obj.setParameters()
            
            obj.addContextMenuItems()
            obj.showLegend()

            if obj.RoiSignalArray.isVirtual
                obj.showVirtualDataDisclaimer;
            end
            
            %obj.ax.ButtonDownFcn = {@obj.interactiveFrameChangeRequest, 'mousepress' };

            obj.isConstructed = true;
        end
        
        function delete(obj)
            delete(obj.roiSignalsChangedListener)
        end
        
    end

    methods % Set/get
        
        function set.ShowRoiSignalOptionsOnMenu(obj, newValue)
            if obj.isConstructed
                if newValue
                    obj.addContextMenuItemsExtra()
                end
            end
        end
        
        function set.SignalsToDisplay(obj, newValue)
            
            validNames = nansen.roisignals.RoiSignalArray.SIGNAL_NAMES;
            isValid = all(contains(newValue, validNames));
            assert(isValid, 'One or more singal names are not valid.')
            
            if ischar(newValue)
                newValue = {newValue};
            end
            
            obj.SignalsToDisplay = newValue;
            obj.onSignalToDisplaySet()
            
        end
        
    end
    
    methods (Access = protected) % General methods
        
        function createAxes(obj)

            createAxes@signalviewer.App(obj)
            
            % Axes customization
            obj.ax.Box = 'off';
            obj.ax.YGrid = 'on';
                        
            obj.ax.XAxis.TickDirection = 'both';
            obj.ax.XAxis.TickLength = [0.002 0.0100];
            obj.ax.XAxis.LineWidth = 1;
            obj.ax.XAxis.FontWeight = 'bold';
            obj.ax.XAxis.FontName = 'verdana';
            
            obj.ax.XAxis.Exponent = 0;
            obj.ax.XAxis.TickLabelFormat = '%d';
            
            obj.ax.YAxis(1).TickLength = [0.00 0.000];

% % %             obj.ax.XTickLabelMode = 'manual';
% % %             obj.ax.XTickMode = 'manual';
            
        end
        
        function createQuickZoomLabels(obj)
            
        end
        
        function addContextMenuItems(obj)
            
            mItem = uimenu(obj.ax.UIContextMenu, 'Label', 'Stack Signals Vertically', 'Callback', @obj.toggleDisplayMode, 'Separator', 'on', 'Checked', 'off');

        end
        
        function addContextMenuItemsExtra(obj)
            mItem = uimenu(obj.ax.UIContextMenu, 'Label', 'Edit Signal Parameters', 'Callback', @obj.editParameters, 'Separator', 'on');
            mItem = uimenu(obj.ax.UIContextMenu, 'Label', 'Edit Deconvolution Parameters', 'Callback', @obj.editDeconvolutionParameters);
        end
        
        function updateContextMenuSignalsToShow(obj, names)
            updateContextMenuSignalsToShow@signalviewer.App(obj, names)
            
            % make sure checkmarks in menu items reflects SignalsToDisplay
            
            hMenu = findobj(obj.ax.UIContextMenu, 'Label', 'Show Signals');
            
            for i = 1:numel(hMenu.Children)
              
                if any(strcmp(hMenu.Children(i).Label, obj.SignalsToDisplay))
                    hMenu.Children(i).Checked = 'on';
                else
                    hMenu.Children(i).Checked = 'off';
                end
                    
            end
            
            
        end
        
        function createSignalSelectionDropdown(obj)
                    
            strings = nansen.roisignals.RoiSignalArray.SIGNAL_NAMES;

            [obj.SignalSelectionDropdown, hButtons] = signalviewer.createDropdownListbox(obj.Panel, strings);
            obj.SignalSelectionDropdown.Visible = 'off';
                        
            for i = 1:numel(hButtons)
                hButtons(i).ButtonDownFcn = @obj.onSignalSelectionChanged;
                %hButtons(i).Callback = @obj.onSignalSelectionChanged;
            end
            hButtons(i).Value = true;

        end %Create widget?
                       
        function onSignalSelectionChanged(obj, source, ~)
            
            if source.Value
                obj.SignalsToDisplay = union(obj.SignalsToDisplay, source.String);
                obj.updateSignalPlot(obj.DisplayedRoiIndices, 'replace');

            else
                obj.SignalsToDisplay = setdiff(obj.SignalsToDisplay, source.String);
                
                % Keep these for reassignment, since the resetSignalPlot
                % clears the values from the DisplayedRoiIndices property
                roiInd = obj.DisplayedRoiIndices;
                obj.resetSignalPlot(obj.DisplayedRoiIndices, source.String)
                obj.DisplayedRoiIndices = roiInd;
            end
            
            
            if ~isempty(obj.signalLegend) && isvalid(obj.signalLegend)
                obj.showLegend()
            end

        end % Part of widget above

        function onQuickZoomSelectionChanged(obj, src, hBtn, i)
           
            if src.Value

                for iBtn = 1:numel(hBtn)
                    if iBtn ~= i
                        hBtn(iBtn).Value = false;
                    else
                        if strcmp(src.String, 'all')
                            numSamples = obj.nSamples;
                        else
                            numSamples = str2double(src.String);
                        end
                    end
                end
            else
                hBtn(end).Value = true;
                numSamples = obj.nSamples;
            end
            
            currentFrame = obj.currentFrameNo;
            
            if currentFrame > obj.nSamples/2
                maxX = min([obj.nSamples, currentFrame + numSamples/2]);
                minX = max([1, maxX - numSamples]);
            else
                minX = max([1, currentFrame - numSamples/2]);
                maxX = min([obj.nSamples, minX + numSamples]);
            end
            
            obj.setNewXLims([minX, maxX])

        end
        
        function addPlotToolbar(obj)
        
            % Calculate the position of the toolbar.
            toolbarHeight = 30;
            imAxPosition = obj.ax.Position;

            initPosition(1) = imAxPosition(1);
            initPosition(2) = sum(imAxPosition([2,4])) - toolbarHeight - 5;
            initPosition(3) = imAxPosition(3);
            initPosition(4) = toolbarHeight;

            %uicc = getappdata(obj.hFigure, 'UIComponentCanvas');

            % Create toolbar
            hToolbar = uim.widget.toolbar_(obj.Panel, 'Position', ...
                initPosition, 'Margin', [35,5,10,30], ...
                'ComponentAlignment', 'left', 'BackgroundAlpha', 0, ...
                'Spacing', 0, 'Padding', [0,0,0,0], 'NewButtonSize', 25);

            hToolbar.Location = 'northwest';
            buttonProps = {'CornerRadius', 0, 'Style', uim.style.buttonDarkMode};%uim.style.buttonLightMode};

            % Add buttons
            hToolbar.addButton('Icon', obj.ICONS.pin3, 'Padding', [5,5,5,5], 'Mode', 'togglebutton', 'Tag', 'pinToolbar', 'Tooltip', 'Pin Toolbar', 'MechanicalAction', 'Switch when pressed', 'IconAlignment', 'center', buttonProps{:}) %, 'Callback', @obj.pinImageToolbar
            
% %             hButton2 = hToolbar.addButton('Icon', obj.ICONS.graph2, 'Padding', [3,3,3,3], 'Mode', 'togglebutton', 'Tag', 'pinToolbar', 'Tooltip', 'Select Signals', 'MechanicalAction', 'Switch when pressed', 'IconAlignment', 'center', buttonProps{:});
% %             hButton2.Callback = @obj.toggleSignalSelectionDropdown;
            
            hButton3 = hToolbar.addButton('Icon', obj.ICONS.graph5, 'Padding', [3,3,3,3], 'Mode', 'togglebutton', 'Tag', 'pinToolbar', 'Tooltip', 'Stack Signals', 'MechanicalAction', 'Switch when pressed', 'IconAlignment', 'center', buttonProps{:});
            hButton3.Callback = @(s,e,mode)obj.toggleDisplayMode(s,'stacked');

        end % Create widget?
        
        function resizePanel(obj, s, e)
            
            resizePanel@signalviewer.App(obj, s, e)
            
            if ~isempty(obj.signalLegend) && isvalid(obj.signalLegend)
                obj.signalLegend.Position(2) = sum(obj.ax.Position([2,4]))+5;
            end

        end
        
    end
    
    methods (Access = public) % Signal extraction plugin methods...
        
        % Todo: Move to signal extraction / computation plugins:
        function setParameters(obj)
        
            params = nansen.twophoton.roisignals.extract.getDefaultParameters;
        
            obj.Parameters = params;

        end %<- Signal extraction
        
        function editParameters(obj, s, e)

            params = obj.Parameters;
            optManager = nansen.OptionsManager('roiSignalExtraction', params);
        
            params = tools.editStruct(params, nan, '', 'OptionsManager', ...
                optManager, 'Callback', @obj.onSignalParamsChanged); 
            
            obj.Parameters = params;

        end
        
        function editDeconvolutionParameters(obj, s, e)
            
            [P, V] = nansen.twophoton.roisignals.getDeconvolutionParameters();
            P = rmfield(P, 'modelParams');
            
            P = obj.DeconvolutionOptions;
            
            P.modelType_ = {'ar1', 'ar2', 'exp2', 'autoar'};
            P.tauRise_ = struct('type', 'slider', 'args', {{'Min', 0, 'Max', 1000, 'nTicks', 100, 'TooltipPrecision', 0, 'TooltipUnits', 'ms'}});
            P.tauDecay_ = struct('type', 'slider', 'args', {{'Min', 0, 'Max', 5000, 'nTicks', 500, 'TooltipPrecision', 0, 'TooltipUnits', 'ms'}});

            P = tools.editStruct(P, [], 'Set deconvolution parameters', ...
                'Callback', @obj.onDeconvolutionParamsChanged);
            
            obj.DeconvolutionOptions = P;
            obj.RoiSignalArray.DeconvolutionOptions = obj.DeconvolutionOptions;

        end
        
        function onSignalParamsChanged(obj, name, value)

            switch name
                case {'pixelComputationMethod', 'excludeRoiOverlaps', ...
                        'createNeuropilMask', 'excludeRoiFromNeuropil', ...
                        'neuropilExpansionFactor', 'cellNeuropilSeparation', ...
                        'numNeuropilSlices', 'roiMaskFormat' }
                    obj.Parameters.(name) = value;
                	obj.refreshSignalPlot();
            end
        end
        
        function onDeconvolutionParamsChanged(obj, name, value)
            
            % Todo: Find a solution for when changing time constants and
            % many rois are selected.
% %             switch name
% %                 case {'tauDecay', 'tauRise', 'spikeSnr', 'lambdaPr'}
            obj.DeconvolutionOptions.(name) = value;
            obj.RoiSignalArray.DeconvolutionOptions = obj.DeconvolutionOptions;
            obj.RoiSignalArray.resetSignals('all', {'deconvolved', 'denoised'})

            %obj.updateSignalPlot(obj.DisplayedRoiIndices, 'replace', {'deconvolved', 'denoised'}, true);
                    
% %             end
        end
        
        function onDffOptionsChanged(obj, name, value)
            
            obj.DffOptions.(name) = value;
                        
            obj.RoiSignalArray.DffOptions = obj.DffOptions;
            obj.RoiSignalArray.resetSignals('all', {'dff'})
            
            %obj.updateSignalPlot(obj.DisplayedRoiIndices, 'replace', {'dff'}, true);
            
        end
        
    end
    
    methods (Access = protected) % Callback methods (roi specific)
        
% %         function resizePanel(obj, s, e)
% %             resizePanel@signalviewer.App(obj, s, e)
% %         end
        
        function onRoiGroupSet(obj)
        %onRoiGroupSet Is called when roigroup is set.    
            if obj.RoiGroup.roiCount >= 1 % -> Select first roi.
                obj.RoiGroup.changeRoiSelection([], 1) 
            end
        end
        
        function onRoiSelectionChanged(obj, evtData)
            
            C = obj.activateGlobalMessageDisplay(); %#ok<NASGU>
            
            newIndices = evtData.NewIndices;
            
            selectedRoiIdx = setdiff(newIndices, obj.DisplayedRoiIndices);
            deselectedRoiIdx = setdiff(obj.DisplayedRoiIndices, newIndices);
            
            if ~isempty(deselectedRoiIdx)
                obj.resetSignalPlot(deselectedRoiIdx)
            end
            
            if ~isempty(selectedRoiIdx)
                obj.updateSignalPlot(selectedRoiIdx, 'append');
            end
                
            return
            
            switch evtData.eventType
                case 'unselect'
                    
                    if ischar(evtData.roiIndices) && strcmp(evtData.roiIndices, 'all')
                        evtData.roiIndices = obj.DisplayedRoiIndices;
                        if isempty(obj.DisplayedRoiIndices); return; end
                    end
                    
                    obj.resetSignalPlot(evtData.roiIndices)
                    
                case 'select'
                    
%                     if numel(evt.roiIndices > 25)
%                         roiIndicesToPlot = evtData.roiIndices(1:25);
%                     else
%                         roiIndicesToPlot = evtData.roiIndices;
%                     end

                    obj.updateSignalPlot(evtData.roiIndices, 'append');
                    
                case 'both'

                    obj.resetSignalPlot(evtData.roiIndices.Deselected)
                    obj.updateSignalPlot(evtData.roiIndices.Selected, 'append');

            end
            
        end
        
        function onRoiClassificationChanged(obj, evtData)
            % pass
        end
        
        function onRoiGroupChanged(obj, evt)
            % pass
        end
        
        
        function onSignalToDisplaySet(obj)
            
            % TODO: Update plots for new signal types.
            
            % need to know what changed, then call update signals...
            
            %updateSignalPlot(obj, obj.selectedRois, 'overwrite');
            %updateSignalPlot(obj, obj.selectedRois, 'append');
            
            
            
        end
        
        function onRoiSignalsChanged(obj, src, evtData)
            
            if obj.HistoryOn && any( strcmp(evtData.action, {'reset', 'updated'}) )
                obj.addLineToHistory(evtData.roiIndices)
            else
                
                if isempty(obj.DisplayedRoiIndices)
                    if strcmp(evtData.action, 'remove')
                       obj.resetSignalPlot(evtData.roiIndices)
                    else
                        obj.updateSignalPlot(evtData.roiIndices, 'append');
                    end
                    
                else
                    % obj.updateSignalPlot(evtData.roiIndices, 'replace');
                    % % Commented this out because it does not work in some
                    % instances.... Is this a bug, or are there reasons I
                    % made it like that? Todo: Debug this!
                    
                    if strcmp(evtData.action, 'remove')
                        obj.resetSignalPlot(evtData.roiIndices)
                    else
                        obj.updateSignalPlot(obj.DisplayedRoiIndices, 'replace', ...
                            evtData.signalType);
                    end
                end
            end
        end

    end
    
    methods
        
        function showSignal(obj, signalName)
            
            if ~isa(signalName, 'cell')
                signalName = {signalName};
            end
            
            for i = 1:numel(signalName)
                % Make sure menus and lines are updated
                obj.onSignalVisibilityChanged(signalName{i}, true)
            end
            
            % Add signal to list of signals to show
            obj.SignalsToDisplay = union(obj.SignalsToDisplay, signalName{i}, 'stable');

            obj.updateSignalPlot(obj.DisplayedRoiIndices, 'replace')

            % Todo: combine/integrate with onSignalSelectionChanged

        end
        
        function onSignalsToShowChanged(obj, src, evt)
            % Todo: protected
            tf = onSignalsToShowChanged@signalviewer.App(obj, src, evt);
            
            src = struct('String', src.Label, 'Value', tf);
            obj.onSignalSelectionChanged(src);
            
        end
        
        function h = getHandle(obj, signalName)
            %Todo: Isthis to naive???
            h = obj.hLineObjects.(signalName);
        end
        
        function addLineToHistory(obj, roiInd)
            
            MAX_NUM_LINES = 10;
            
            % Make sure its only one roi. (Can generalize later)
            
            % Make sure it is the same roi as before.
            
            % make sure only one signal is shown...
            signalName = obj.SignalsToDisplay{1};
            
            
            % Get new signal.
            signalData = obj.RoiSignalArray.getSignals(roiInd, signalName);
            
            
            % Add it to time series matrix
            tsArray = obj.createTimeseriesArray(signalData);
            obj.plotTimeSeries(tsArray)
            
            
            % Plot new line.
            lines = findobj(obj.ax, 'Type', 'Line');
            numLines = numel(lines);
            
            while numLines > MAX_NUM_LINES
                delete(lines(end))
                lines(end) = [];
                numLines = numel(lines);
            end
                
            
            numColors = max([10, numLines]);
            
            % Set color scheme so that the newest is dark.
            colors = cbrewer('seq', 'Blues', numColors, 'spline');
            colors = flipud(colors);
            
            % Correct for bug in color interpolation
            colors(colors<0)=0;
            
            colorCell = arrayfun(@(i) colors(i,:), 1:numLines, 'uni', 0);
            
            set(lines, {'Color'}, colorCell')
        end
        
        function refreshSignalPlot(obj)
            
            obj.updateSignalPlot(obj.DisplayedRoiIndices, 'replace', ...
                obj.SignalsToDisplay, true);

        end
        
        function updateSignalPlot(obj, roiInd, mode, signalNames, forceUpdate)
        % Update signal plot
        %
        %   INPUTS :
        %
        %       mode : 'append' | 'overwrite'
            
         % todo, need append and replace.
               
            if obj.RoiSignalArray.isVirtual; return; end
         
            persistent yMaxLeft yMaxRight
         
            if nargin < 4
                signalNames = obj.SignalsToDisplay;
            else
                signalNames = intersect(obj.SignalsToDisplay, signalNames);
            end
            
            if nargin < 5
                forceUpdate = false;
            end
        
            if ~obj.IsActive; return; end
            
            if isempty(signalNames); return; end
            
            if strcmp(mode, 'append')
                roiInd = setdiff(roiInd, obj.DisplayedRoiIndices, 'stable'); 
            end
            
            if isempty(roiInd); return; end
            
            if ~ishold(obj.ax)
               hold(obj.ax, 'on') 
            end
            
            % Turn on automatic ylim mode so axis adjust according to data.
            set(obj.ax.YAxis, 'LimitsMode', 'auto')
            
            
            %yyaxis(obj.ax, 'left')
            
            fields = fieldnames(obj.RoiSignalArray.Data);
            %fields = setdiff(fields, {'spkThr', 'spkSnr', 'lamPr', 'spikeThreshold'}); % Not a line object
            
            % Overwrite is supposed to work for single and multiple rois
            if isequal(mode, 'overwrite')
                
                %obj.ax.YLim = [0,255];
                %obj.ax.YLim = [ min(0, obj.ax.YLim(1)), max(1, obj.ax.YLim(2)) ];
                
                % Reset data in line handle
%                 for i = 1:numel(fields) 
%                     if ~isempty(obj.hlineSignal.(fields{i}))
%                         set(obj.hlineSignal.(fields{i})(:), 'YData', nan)
%                     end
%                 end
            end
            
            
            % chNo = obj.activeChannel;
            
            numDisplayedLines = numel(obj.DisplayedRoiIndices);
            
            switch mode
                case 'append'
                    numNewLines = numel(roiInd);
                    insertIdx = numDisplayedLines + (1:numNewLines);

                case 'replace'
                    numNewLines = 0;
                    insertIdx = 1:numDisplayedLines;
            end
            
            for i = 1:numel(signalNames)
                
                signalName = signalNames{i};
                
                % Get signaldata based on signal name to plot
                signalData = obj.RoiSignalArray.getSignals(roiInd, signalName, obj.Parameters, 1, forceUpdate);
                
                if isempty(signalData); return; end
                
                
                % Change to left or right y axis depending on signal
                switch signalName
                    case {'dff', 'denoised', 'deconvolved'}
                        yyaxis(obj.ax, 'right')
                        yMax = 4;
                    
                    otherwise
                        yyaxis(obj.ax, 'left')
                        yMax = 255;
                end

                yScale = 1;
                
                if strcmp(obj.DisplayMode, 'stacked')
                    yOffset = (numDisplayedLines + (0:numel(roiInd)-1)) * yMax;
                    signalData = signalData.*yScale + yOffset;
                    %obj.ax.YLim = [0, numel(roiInd)*yMax];
                else
                    %obj.ax.YLim = [0, yMax];
                end
                
                isMatched = strcmp( signalName, obj.tsNames );
                
                if numDisplayedLines + numNewLines > size(obj.tsArray(isMatched).Data, 2)
                    obj.expandLineObjects(signalName, numDisplayedLines + numNewLines)
                end
                
                obj.tsArray(isMatched).Data(:, insertIdx) = signalData;
                
                obj.onTimeseriesDataUpdated(signalName, insertIdx);
                
                
                % Apply colors.
                switch signalName
                    case 'roiMeanF'
                        colorName = 'Greens';
                    case 'npilMediF'
                        colorName = 'Blues';
                    case 'dff'
                        colorName = 'Oranges';
                    case {'denoised', 'deconvolved'}
                        colorName = 'Reds';
                    otherwise
                        colorName = 'Greys';
                end
                
                nRois = numel(roiInd);
                colors = cbrewer('seq', colorName, max([5,nRois*3]), 'spline');
                colors = flipud(colors); colors(colors<0)=0;
                colors = colors(nRois:nRois*2-1,:);
                colorCell = arrayfun(@(i) colors(i,:), 1:nRois, 'uni', 0);
                set(obj.hLineObjects.(signalName)(insertIdx), {'Color'}, colorCell')
                
            end
            
            if strcmp(mode, 'append')
                obj.DisplayedRoiIndices = [obj.DisplayedRoiIndices, roiInd];
            end
            
            % Turn off automatic ylimmode. Keep ylims constant when
            % panning....
            drawnow
            set(obj.ax.YAxis, 'LimitsMode', 'manual')

        end
        
        function onTimeseriesDataUpdated(obj, signalName, insertInd)
            
            isMatched = strcmp( signalName, obj.tsNames );

            yData = obj.tsArray(isMatched).Data(:, insertInd);
            
            yData = mat2cell(yData, size(yData,1), ones(size(yData,2), 1));

            set(obj.hLineObjects.(signalName)(insertInd), {'YData'}, yData')

        end

        function resetSignalPlot(obj, roiInd, signalNames)
            
            % Todo: update timeseries data
            
            if nargin < 3
                signalNames = obj.SignalsToDisplay;
            end
            
            if ischar(signalNames)
                signalNames = {signalNames};
            end
            
%             persistent signalNames
%             if isempty(signalNames)
%                 signalNames = nansen.roisignals.RoiSignalArray.SIGNAL_NAMES;
%             end
            
            resetInd = ismember(obj.DisplayedRoiIndices, roiInd);
            keepInd = ~resetInd;
            
            numLinesToReset = sum(resetInd);
            numKeep = sum(keepInd);
                            
            keepInd = find(keepInd);
            resetInd = find(resetInd);
            
            for i = 1:numel(signalNames)
                
                thisSignal = signalNames{i};
                
                yData = nan(obj.nSamples, numLinesToReset);
                
                yData = mat2cell(yData, size(yData,1), ones(size(yData,2), 1));
                
                set(obj.hLineObjects.(thisSignal)(resetInd), {'YData'}, yData')
                
                
                % Rearrange line objects.
                rearrangedInd = [keepInd, resetInd];
                numDisplayed = numel(rearrangedInd);
                
                obj.hLineObjects.(thisSignal)(1:numDisplayed) = ...
                    obj.hLineObjects.(thisSignal)(rearrangedInd);
                
                if numel(obj.hLineObjects.(thisSignal)) > numKeep
                    obj.trimLineObjects(thisSignal, numKeep)
                end
                
            end
            
            obj.DisplayedRoiIndices = obj.DisplayedRoiIndices(keepInd);
            
            
            
% %             if numKeep == 0
% %             
% %                 % Reset Y limits
% %                 yyaxis(obj.ax, 'left')
% %                 obj.ax.YLim = [0,256];
% %                 yyaxis(obj.ax, 'right')
% %                 obj.ax.YLim = [0,1];
% %                 
% %             end
            
            
        end        
        
        function initializeTimeSeriesObjects(obj)
            
            signalNames = nansen.roisignals.RoiSignalArray.SIGNAL_NAMES;
            
            STEP = 10;
            
            data = nan(obj.nSamples, STEP);

            
            for i = 1:numel(signalNames)
            
                tsArray = timeseries(data);
                tsArray.Name = signalNames{i};
                
                %obj.tsArray(end+1) = tsArray;
            
                
                % Change to left or right y axis depending on signal
                switch signalNames{i}
                    case {'dff', 'denoised', 'deconvolved'}
                        yyaxis(obj.ax, 'right')
                    otherwise
                        yyaxis(obj.ax, 'left')
                end
                
                
                h = obj.plot(tsArray);
                set(h{1}, 'LineStyle', '-', 'Marker', 'none', 'LineWidth', 1)

                obj.hLineObjects.(signalNames{i}) = h{1};
                
            end
            
            obj.showLegend()
            
            %obj.tsNames = {obj.tsArray.Name};
            
        end

        function resetTimeSeriesObjects(obj)
            
            %Todo:Should be a super class method.
            
            signalNames = nansen.roisignals.RoiSignalArray.SIGNAL_NAMES;
            
            obj.tsNames = {}; 
            obj.tsArray = timeseries.empty;
            
            for i = 1:numel(signalNames)
                delete(obj.hLineObjects.(signalNames{i}))
            end
            
            obj.hlineTsArray = [];
            
            obj.resetContextMenuSignalsToShow()
                            
        end
        
        function trimLineObjects(obj, signalType, numTrimmed)
        %trimLineObjects Trim array of line objects to nearest N
        
            if numTrimmed == 0; numTrimmed = 1; end %Dont delete all
        
            STEP = 10;
            ceiln = @(x, n) ceil(x/n)*n;
            numTrimmed = ceiln(numTrimmed, STEP);

            % Find the current timeseries object
            tsIND = find( strcmp( signalType, obj.tsNames ) );    
            
            numLineObjects = numel(obj.hLineObjects.(signalType));

            if numLineObjects > numTrimmed
                delete( obj.hLineObjects.(signalType)(numTrimmed+1 : end) )
                obj.hLineObjects.(signalType)(numTrimmed+1 : end) = [];
                
                obj.tsArray(tsIND).Data(:, (numTrimmed+1 : end)) = [];
            
            
                % Make sure that there is one line object for each data column
                numDataSeries = size(obj.tsArray(tsIND).Data, 2);
                numLineObjects = numel(obj.hLineObjects.(signalType));

                assert(numDataSeries==numLineObjects, 'Something went wrong')
                obj.showLegend()
            end

        end
        
        function expandLineObjects(obj, signalType, numExpanded)
        %expandLineObjects Expand array of line objects to nearest N
        
            STEP = 10;
            ceiln = @(x, n) ceil(x/n)*n;
            numExpanded = ceiln(numExpanded, STEP);
                      
            % Find the current timeseries object
            tsIND = find( strcmp( signalType, obj.tsNames ) );                
            
            % Determine how many new series to create
            numExistingSeries = size(obj.tsArray(tsIND).Data, 2);
            numNewSeries = numExpanded - numExistingSeries;

            % Allocate new data with nans
            yData = nan(obj.nSamples, numNewSeries);
            
            % Expand time series data
            obj.tsArray(tsIND).Data = cat(2, obj.tsArray(tsIND).Data, yData);

            % Create new line objects
            xData = obj.tsArray(tsIND).Time;
            

            % Change to left or right y axis depending on signal
            switch signalType
                case {'dff', 'denoised', 'deconvolved'}
                    yyaxis(obj.ax, 'right')
                otherwise
                    yyaxis(obj.ax, 'left')
            end
            
            newLineObjects = plot(obj.ax, xData, yData);
            set(newLineObjects, 'LineStyle', '-', 'Marker', 'none', 'LineWidth', 1)
            
            % Add new line objects to the hLineObjects property
            obj.hLineObjects.(signalType) = cat(1, ...
                obj.hLineObjects.(signalType), newLineObjects);
            
            % Make sure that there is one line object for each data column
            numDataSeries = size(obj.tsArray(tsIND).Data, 2);
            numLineObjects = numel(obj.hLineObjects.(signalType));
            
            assert(numDataSeries==numLineObjects, 'Something went wrong')
            
        end
        
        function showLegend(obj, ~, ~)
            
            lines = gobjects(numel(obj.SignalsToDisplay),  1);
            
            allNames = obj.RoiSignalArray.SIGNAL_NAMES;
            sortedSignalNames = intersect(allNames, obj.SignalsToDisplay, 'stable');
            
            for i = 1:numel(sortedSignalNames)
                signalName = sortedSignalNames{i};
                lines(i) = obj.hLineObjects.(signalName)(1);
            end
              
            obj.signalLegend = legend(lines, sortedSignalNames, 'AutoUpdate', 'off');
            obj.signalLegend.Orientation = 'horizontal';
            obj.signalLegend.Location = 'northwest';
            obj.signalLegend.Position(2) = 0.85;
            obj.signalLegend.Color = obj.Panel.BackgroundColor;
            obj.signalLegend.TextColor = obj.ax.XAxis.Color;
            obj.signalLegend.Box = 'off';
            obj.signalLegend.FontSize = 10;
            obj.signalLegend.Units = 'pixel';
            obj.signalLegend.Position(2) = sum(obj.ax.Position([2,4]))+5;
            obj.signalLegend.ItemHitFcn = @obj.onLegendItemPressed;
            %obj.signalLegend.ButtonDownFcn = @obj.onButtonPressedInLegend;
            
            
            %l2 = legend(obj.hlineTsArray, {obj.tsArray.Name}, 'AutoUpdate', 'off');
        end
        
        function onLegendItemPressed(obj, src, evt)
            
            signalName = evt.Peer.DisplayName;
            obj.onSignalVisibilityChanged(signalName)
            
        end
        
        function showVirtualDataDisclaimer(obj)
            % Todo: update if limits change...
            
            x = obj.ax.XLim(1) + (obj.ax.XLim(2)-obj.ax.XLim(1))/2;
            y = obj.ax.YLim(1) + (obj.ax.YLim(2)-obj.ax.YLim(1))*0.75;
            
            h = findobj(obj.ax, 'Tag', 'Virtual Stack Disclaimer');
            if ~isempty(h)
                h.Visible = 'on';
                h.Position(1:2)=[x,y];
                return
            end

            str = 'Signals are not available for virtual stacks';
            
            hTxt = text(obj.ax, x, y, str);
            hTxt.FontUnits = 'pixels';
            hTxt.FontSize = 18;
            hTxt.HorizontalAlignment='center';
            hTxt.VerticalAlignment='middle';
            hTxt.Color = [obj.Theme.AxesForegroundColor, 0.5] .* 0.5;
            hTxt.Tag = 'Virtual Stack Disclaimer';
            
        end
        
        function hideVirtualDataDisclaimer(obj)
            
            h = findobj(obj.ax, 'Tag', 'Virtual Stack Disclaimer');
            if ~isempty(h)
                h.Visible = 'off';
            end
            
        end
        
    end
    
    methods (Access = private)
        
        function toggleDisplayMode(obj, src, mode)
            
            if src.Checked % Todo: shoud work for older matlabs..
                obj.DisplayMode = 'normal';
            else
                obj.DisplayMode = 'stacked';
            end
            
            src.Checked = ~src.Checked;
                           
            obj.updateSignalPlot(obj.DisplayedRoiIndices, 'replace');

        end
        
        function toggleSignalSelectionDropdown(obj, src, evt)
            
            if src.Value
                
                obj.SignalSelectionDropdown.Visible = 'on';
                
                obj.DropdownCloseListener = addlistener(obj.Figure, ...
                    'WindowMousePress', ...
                    @(s,e,h) obj.onMousePressedInFigureWithDropdown(src));
                
            else
                obj.SignalSelectionDropdown.Visible = 'off';
                delete(obj.DropdownCloseListener)
            end
            
            
        end
        
        function onMousePressedInFigureWithDropdown(obj, hButton)
            
            % Todo: make sure current point is referenced to the parent of
            % the dropdown. I.e if the dropdown is in a subpanel...
            
            if strcmp(obj.SignalSelectionDropdown.Visible, 'off')
                return
            end
            
            posA = obj.SignalSelectionDropdown.Position;
            posB = getpixelposition(hButton, true);
            
            
            x = obj.Figure.CurrentPoint(1);
            y = obj.Figure.CurrentPoint(2);
            
            isPointerOnDropDown = x > posA(1) && x < sum(posA([1,3])) && ...
                                    y > posA(2) && y < sum(posA([2,4])) ;
            
            isPointerOnButton = x > posB(1) && x < sum(posB([1,3])) && ...
                                    y > posB(2) && y < sum(posB([2,4])) ;
                          
            if isPointerOnDropDown || isPointerOnButton
                % do nothing
            else
%                 eventData = uim.event.ToggleEvent(0);
%                 hButton.toggleState([], eventData)

                % Todo: Callbacks hould be called from inside button...
                hButton.Value = false;
                obj.toggleSignalSelectionDropdown(hButton)
                
            end
            
        end
        
    end
    
    
    
    
end