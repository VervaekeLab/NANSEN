classdef RoiSignalArray < handle
%RoiSignalArray
%
%   Implementation of signal array with multiple channels and signal
%   variations. 
%
%   Purpose: 
%       - Framework for organizing signals for multiple channels and
%         variations.
%       - Handle class: Share between multiple classes 
%
%   EXAMPLES:
%
%   Alternative 1: Signal array
%          
%   Alternative 2: Roi array and image stack... 
%
%   Alternative 2:
%       RoiSignalArray(filePath) opens a signal array instance based on
%       file given as input
%
%  Alternative 3:
%       RoiSignalArray(roiGroup, imageStack) opens a signal array instance
%       based on an instance of a roigroup and an imagestack

%   QUESTIONS:
%    - Why do I need this??
%    - Make 2 classes? One for loaded signals, and one for "live" signals


    % NOTE: Multiple channels are not implemented yet.

    % Todo
    %   [ ] Improve performance when removing rois, should not rearrange
    %   data, only indices for accessing data. 
    
    
    %   [ ] Generalize so that signalArray can be loaded from file
    %   [ ] Come up with better names for signals
    %   [ ] What parameters should be included?
    %   [ ] What parameters are used if none are given?
    %   [ ] Where to get settings from? A handle class?
    %
    
    
    
    properties (Constant)
        SIGNAL_NAMES = {'roiMeanF', 'npilMediF', 'demixedMeanF', 'dff', ...
            'deconvolved', 'denoised' ...
            };
                        
        PARAMETER_NAMES = {'spkThr', 'spkSnr', 'lamPr', 'taurise', 'taudecay'}
        
        STEPSIZE = 100; % NAME??? How many rois to expand array by
    end
    
    properties % Options properties
        UpdateMode = 'OnRequest'; % 'OnDemand' | 'OnRequest' 
        
        % Todo: Rename? Active vs Passive. Active: always update if signal is reset. Passive, only update if signal is requested.
    end
    
    
    properties % Data properties
        Data = struct           % Struct array (1 x nCh) with fields for each signal type. Each field is numSamples x numRois
        Parameters = struct     % Struct array (1 x nCh) with fields for each signal type. Each field is 1 x numRois
    
        SignalExtractionOptions = nansen.twophoton.roisignals.extract.getDefaultParameters();
        DffOptions = nansen.twophoton.roisignals.computeDff();
        DeconvolutionOptions = nansen.twophoton.roisignals.getDeconvolutionParameters();
    end
    
    properties
        % Should these be properties of the roi signal array class???
        ImageStack
        RoiGroup
    end
    
    properties (Dependent) % Info properties
        NumChannels         % int : Number of channels
        NumFrames           % vector : 1 x numCh with number of frames per channel
        NumRois             % vector : 1 x numCh with number of rois per channel
    end
    
    
    
    properties (Access = private)
        RoisChangedListener
    end
    
    events
        RoiSignalsChanged % Triggered when one or more signals are changed
    end
    
    

    methods % Constructor
        
        function obj = RoiSignalArray(imageStack, roiGroup)
        % 
        %   Todo: Generalize so that signalArray can be loaded from file
        
            if ~nargin
                return
            end
        
        %   Data and Parameters arrays are set when ImageStack is set.
            obj.RoiGroup = roiGroup;
            obj.ImageStack = imageStack;
            
        end
        
    end
    
    methods % Set/get
        
        function set.ImageStack(obj, newValue)
            VALID_CLASS = 'nansen.stack.ImageStack';
            obj.validatePropertValue('ImageStack', newValue, VALID_CLASS)

            obj.ImageStack = newValue;
            obj.onImageStackSet()
        end
        
        function set.RoiGroup(obj, newValue)
            VALID_CLASS = 'roimanager.roiGroup';
            obj.validatePropertValue('RoiGroup', newValue, VALID_CLASS)
            
            obj.RoiGroup = newValue;
            obj.onRoiGroupSet()
        end
        
        function numRois = get.NumRois(obj)
            if isempty(obj.RoiGroup)
                numRois = 0;
            else
                numRois = obj.RoiGroup.roiCount;
            end
        end
        
        function numFrames = get.NumFrames(obj)
            if isempty(obj.ImageStack)
                numFrames = 0;
            else
                numFrames = obj.ImageStack.NumTimepoints;
            end
        end
        
        function numChannels = get.NumChannels(obj)
            if isempty(obj.ImageStack)
                numChannels = 1;
            else
                numChannels = obj.ImageStack.NumChannels;
            end
        end
                
    end
    
    methods (Access = protected)
        
        function initializeSignalArray(obj, channelInd)
        %initializeSignalArray Initialize signalArray for given channels
        %
        %   initializeSignalArray(obj, channelInd) initializes one struct
        %   for each channel and adds them the the Data struct array. Does
        %   the same for the Parameters struct
            
            % Set default channel ind if none is given (1 channel)
            if nargin < 2 || isempty(channelInd)
                channelInd = 1;
            end
            
            if obj.isVirtual; return; end
                        
            % Temp function for rounding up to the nearest given integer
            ceilN = @(x, int) ceil(x/int) * int;
            INT = 100;
            
            % Get field names for Data and Parameters struct arrays
            signalNames = obj.SIGNAL_NAMES;
            paramNames = obj.PARAMETER_NAMES;
            
            % Initialize arrays across channels
            for i = channelInd
                
                nSamples = obj.NumFrames(i);
                nRois = max( [INT, ceilN(obj.NumRois(i), INT)] );
                
                for j = 1:numel(signalNames)
                    obj.Data(i).(signalNames{j}) = nan(nSamples, nRois);
                end
                
                for j = 1:numel(paramNames)
                    obj.Parameters(i).(paramNames{j}) = nan(1, nRois);
                end

            end
                        
        end
        
        function modifySignalArray(obj, roiInd, action, chInd, editFields)
        %modifySignalArray
        %
        %
        %   INPUTS:
        %       obj : handle to class instance
        %       roiInd : a list of roi indices
        %       action : 'reset', 'insert', 'remove' (How to modify signal array)
        %       chInd : channel indices to apply actions to
        %       editFields : name of fields, for applying actions to a subset of fields
        
            % Editfield was added to only reset some (not all fields).
            
            % Set default values for options inputs.
            if nargin < 4 || isempty(chInd); chInd = 1; end
            if nargin < 5 || isempty(editFields); editFields = 'all'; end
            
            if obj.isVirtual; return; end

            
            % Get field names to modify
            fields = obj.SIGNAL_NAMES;
            
            if strcmp(editFields, 'all')
                editFields = fields;
            end
            
            if isequal(action, 'initialize')
                obj.initializeSignalArray(obj, chInd)
                return
            end
            
            % Temp function for rounding up to the nearest given integer
            ceilN = @(x, int) ceil(x/int) * int;
            INT = 100;
            
            for iCh = chInd
                
                % Expand array if necessary
                numExpand = 0;
                nCol = size(obj.Data(iCh).(fields{1}), 2);
                
                switch action 
                    case {'append', 'insert'}
                        if nCol < obj.NumRois(iCh)
                            numMissingCols = obj.NumRois(iCh) - nCol;
                            numExpand = ceilN(numMissingCols, INT);
                        end
                end
                
                for fNo = 1:numel(fields)
                    
                    thisField = fields{fNo};
                    
                    if numExpand > 0
                        obj.Data(iCh).(thisField)(:, end:end+numExpand) = nan;
                        nCol = size(obj.Data(iCh).(thisField), 2);
                    end

                    switch action
                        case 'reset'
                            if isequal(thisField, 'spikeThreshold')
                                continue
                            elseif ~contains(thisField, editFields)
                                continue
                            end
                            obj.Data(iCh).(thisField)(:, roiInd) = nan;

                        case 'insert'
                            remappedInd = 1:nCol;
                            remappedInd = setdiff(remappedInd, roiInd);
                            orignalInd = 1:numel(remappedInd);
                            
                            % Place data from original indices into
                            % new indices and set rest to nans.
                            obj.Data(iCh).(thisField)(:, remappedInd) = ...
                                obj.Data(iCh).(thisField)(:, orignalInd);
                            obj.Data(iCh).(thisField)(:, roiInd) = nan;

                        case 'remove'
                            if ~isempty(roiInd)
                                remappedInd = 1:nCol;
                                remappedInd = setdiff(remappedInd, roiInd);
                                newInd = 1:numel(remappedInd);
                                
                                % Remove 
                                obj.Data(iCh).(thisField)(:, newInd) = ...
                                    obj.Data(iCh).(thisField)(:, remappedInd);
                                obj.Data(iCh).(thisField)(:, roiInd) = nan;
                            end
                    end
                end 
            end
            
            % TODO: Make sure this is correct and working.
            if strcmp(action, 'reset')
                fields = editFields;
            end
            
            evtData = roimanager.eventdata.RoiSignalsChanged(roiInd, fields, action);
            obj.notify('RoiSignalsChanged', evtData);
            
            
        end
        
        function [TF, roiInd] = isSignalMissing(obj, signalName, ...
                                                        roiInd, channelNum)
        
            signalData = obj.Data(channelNum).(signalName)(:, roiInd);
            isMissingSignal = any(isnan(signalData));
            
            if any(isMissingSignal)
                TF = true;
                roiInd = roiInd(isMissingSignal);
            else
                TF = false;
                roiInd = [];
            end

        end
        
    end
        
    
    methods 
        
        function tf = isVirtual(obj)
            if isempty(obj.ImageStack)
                tf = true;
            else
                tf = obj.ImageStack.IsVirtual;
            end
        end
        
        function signalData = getSignals(obj, roiInd, signalName, options, channelNum, forceUpdate)
            
            if nargin < 6 || isempty(forceUpdate)
                forceUpdate = false; 
            end
            
            if nargin < 5 || isempty(channelNum)
                channelNum = 1; 
            end
            
            if nargin < 4
                options = struct;
            end
            
            signalData = [];
            if obj.isVirtual; return; end
            
            % Get image stack and roi array based on channel number
            
            % Get frames based on image stack (and virtual stack options)
            
            if forceUpdate
            	obj.updateSignals(roiInd, signalName, options)
                signalData = obj.Data(channelNum).(signalName)(:, roiInd);
                return
            end
            
            % Get signal for requested signal type.
            signalData = obj.Data(channelNum).(signalName)(:, roiInd);
            isMissingSignal = any(isnan(signalData));

            % Update and get signals again if they are missing.
            if any(isMissingSignal)
                obj.updateSignals(roiInd(isMissingSignal), signalName, options)
                signalData = obj.Data(channelNum).(signalName)(:, roiInd);
            end
            
        end
        
        function resetSignals(obj, roiInd, signalNames, channelNum)
            if nargin < 4
                channelNum = 1;
            end
            
            if ischar(roiInd) && strcmp(roiInd, 'all')
                roiInd = 1:obj.NumRois;
            end
            
            obj.modifySignalArray(roiInd, 'reset', channelNum, signalNames)
        end
        
    end
    
    methods (Access = private) % Listener callback methods
        
        function onImageStackSet(obj)
            if obj.NumRois > 0
                obj.initializeSignalArray()
            end
        end
        
        function onRoiGroupSet(obj)
                        
            if ~isempty(obj.RoisChangedListener)
                delete(obj.RoisChangedListener)
            end
            
            % Add listener for roisChanged event on RoiGroup object
            el = addlistener(obj.RoiGroup, 'roisChanged', @obj.onRoisChanged);
            obj.RoisChangedListener = el;
            
            
            obj.Data = [];
            if ~obj.isVirtual
                obj.initializeSignalArray()
            end
        end

        function onRoisChanged(obj, src, evtData)
            
            % Todo: 
            %   Rois are added      obj.modifySignalArray(roiInd, mode, ch)
            %   Rois are removed    obj.modifySignalArray(roiInd, 'remove', ch)
            %   Rois are modified   obj.modifySignalArray(obj.selectedRois, 'reset')
            
            
            % Todo: 
            %   [ ] add handling of parameters struct
            
            if obj.isVirtual; return; end
            
            
            % Make needed changes to the data
            switch evtData.eventType
                case 'initialize'
                    obj.initializeSignalArray()
                case 'append'
                    if obj.NumRois > size(obj.Data(1).(obj.SIGNAL_NAMES{1}), 2)
                        obj.modifySignalArray(evtData.roiIndices, evtData.eventType)
                    end
                    
                case 'modify'
                    if strcmpi(obj.UpdateMode, 'ondemand')
                        obj.updateSignals(evtData.roiIndices, 'all', struct, true)
                    else
                        obj.modifySignalArray(evtData.roiIndices, 'reset')
                    end
                case 'remove'
                    obj.modifySignalArray(evtData.roiIndices, 'remove')

            end
            
            switch evtData.eventType
                case {'initialize', 'append'}
                    if strcmpi(obj.UpdateMode, 'ondemand')
                        obj.updateSignals(evtData.roiIndices, 'all')
                    end
            end
        end

    end
    
    methods (Access = private)
        
        function updateSignals(obj, roiInd, signalTypes, options, triggerEvent)
            
            if nargin < 5
                triggerEvent = false;
            end
            
            if nargin < 4
                options = struct;
            end
            
            chNo = 1;
            
            if nargin < 3 || isempty(signalTypes) || strcmp(signalTypes, 'all')
                signalTypes = obj.SIGNAL_NAMES;
            end
            
            if ischar(signalTypes)
                signalTypes = {signalTypes};
            end
            
            % Simplify (when multiple signals are computed together)
            if sum(contains(signalTypes, {'deconvolved', 'denoised'})) == 2
                signalTypes(strcmp(signalTypes, 'denoised')) = [];
            end
            if sum(contains(signalTypes, {'roiMeanF', 'npilMediF'})) == 2
                signalTypes(strcmp(signalTypes, 'denoised')) = [];
            end
            
            for i = 1:numel(signalTypes)
                
                switch signalTypes{i}
                    
                    case {'roiMeanF', 'npilMediF'}
                        obj.extractSignals(roiInd, chNo, options);
                        
                    case 'dff'
                        obj.getDeltaFOverF(roiInd, chNo);
                        
                    case {'deconvolved', 'denoised'}
                        options = obj.DeconvolutionOptions;
                        obj.getDeconvolved(roiInd, chNo, options);
                        
                    otherwise
                        signalData = nan(obj.NumFrames, numel(roiInd));
                        obj.Data(chNo).(signalTypes{i})(:, roiInd) = signalData;
                
                end
                
            end
            
            if triggerEvent
                % TODO: Make sure this is correct and working.
                evtData = roimanager.eventdata.RoiSignalsChanged(roiInd, signalTypes, 'updated');
                obj.notify('RoiSignalsChanged', evtData);
            end

        end
        
        function signalData = extractSignals(obj, roiInd, channelNum, options) %[signal] = extractSignal(obj, roiInd, signalName)

            % Todo: 
            %   [ ] Need roi numbers, channel numbers, sample numbers (?) and
            %       signal name
            %
            %   [ ] Sample numbers will depend on whether stack is virtual or
            %       not. If stack is virtual, use a options selection to
            %       determine if signals are extracted from cache, from a
            %       subset of frames or fram the whole stack.
            
            if nargin < 4; options = struct(); end
            
            options = obj.SignalExtractionOptions;
            
            import nansen.twophoton.roisignals.extractF
            
            imageStack = obj.ImageStack(channelNum);
            roiArray = obj.RoiGroup(channelNum).roiArray;
            
            % Todo: What to do with virtual stacks????

            % Todo: get options from somewhere!
            signalData = extractF(imageStack, roiArray, options, 'roiInd', roiInd);

            obj.Data(channelNum).roiMeanF(:, roiInd) = signalData(:, 1, :);
            
            if size(signalData,2) == 2
                obj.Data(channelNum).npilMediF(:, roiInd) = signalData(:, 2, :);
            elseif size(signalData,2) > 2
                obj.Data(channelNum).npilMediF(:, roiInd) = mean(signalData(:, 2:end, :), 2);
            end
            
        end
        
        function signalData = getDeltaFOverF(obj, roiInd, channelNum)
            % Todo: get options from somewhere!
            
            %import nansen.twophoton.roisignals.process.dff.*
            
            signalDataRoi = obj.getSignals(roiInd, 'roiMeanF');
            signalDataNpil = obj.getSignals(roiInd, 'npilMediF');
            
            signalData = cat(3, signalDataRoi, signalDataNpil);
            signalData = permute(signalData, [1,3,2]);
            
            dff = nansen.twophoton.roisignals.computeDff(signalData, obj.DffOptions);
            
            obj.Data(channelNum).dff(:, roiInd) = dff;
            
        end
        
        function getDeconvolved(obj, roiInd, channelNum, options)
            % Todo: get options from somewhere!
            
            import nansen.twophoton.roisignals.deconvolveDff
            
            global fprintf; if isempty(fprintf); fprintf = str2func('fprintf'); end
            fprintf('Deconvolving signal...\n')
            
            options = obj.DeconvolutionOptions;

            dff = obj.getSignals(roiInd, 'dff');
            
            [dec, den, ~] = deconvolveDff(dff, options);%, options)
            
            obj.Data(channelNum).deconvolved(:, roiInd) = dec;
            obj.Data(channelNum).denoised(:, roiInd) = den;
           
            % Normalize deconvolved signals?
            %signalData = signalData ./ max(signalData(:));

        end
        
        function discretizeSignals(obj, roiInd, channelNum)
            
        end
        
    end
    
    
    methods (Static, Access = 'private')
        
        function validatePropertValue(propertyName, newValue, validClass)
                        
            msg = sprintf('%s must be an instance of %s', propertyName, ...
                validClass);
            
            assert(isa(newValue, validClass), msg)
            
        end
        
    end
    
end