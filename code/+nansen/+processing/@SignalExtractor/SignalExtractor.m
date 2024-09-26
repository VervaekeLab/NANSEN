classdef SignalExtractor < nansen.stack.ImageStackProcessor
%SignalExtractor Extract roi signals for imagestack

%   Todo:
%       [ ] Better documentation and parsing of inputs in constructor.
%       [ ] Use DATA_SUBFOLDER and VARIABLE_PREFIX for saving
%       [ ] Set start and stop metadata

    properties (Constant)
        MethodName = 'Extract Signals'
        IsManual = false        % Does method require manual supervision
        IsQueueable = true      % Can method be added to a queue
        OptionsManager = nansen.OptionsManager('nansen.processing.SignalExtractor')
    end
    
    properties (Constant, Hidden) % Inherited from DataMethod (not implemented yet)
        DATA_SUBFOLDER = 'roisignals' %'image_pixel_stats';
        VARIABLE_PREFIX = 'SignalData'
    end
    
    properties %Options
        %ChannelMode = 'serial'  % Compute values for each channel individually
        %PlaneMode = 'serial'    % Compute values for each plane individually
    end
    
    properties (Access = private) % Signal extraction specific properties
        % Note: All properties in this property block is an object array 
        % or a cell array with size numPlanes x numChannels.

        RoiGroupArray               % Roi groups for all channels/planes...
        RoiDataArray cell           % Roi data (prepared for efficient signal extraction) for all channels/planes...
        ExtractionParameters cell   % Signal extraction parameters for all channels/planes
        SignalExtractionFcn cell    % Cell array of function handles to us for signal extraction
    end
    
    methods (Static)

        function S = getDefaultOptions()
            S = struct();
            S.Extraction = nansen.twophoton.roisignals.extract.getDefaultParameters();
            
            S.Extraction.showTimer      = false;    %V.showTimer = @(x) assert(islogical(x), 'Value must be logical');
            S.Extraction.verbose        = false;    %V.verbose = @(x) assert(islogical(x), 'Value must be logical');
            S.Extraction.signalDataType = 'single'; %V.signalDataType = @(x) assert(any(strcmp(x, {'single', 'double'})), 'Value must be ''single'' or ''double''');

            className = mfilename('class');
            superOptions = nansen.mixin.HasOptions.getSuperClassOptions(className);
            S = nansen.mixin.HasOptions.combineOptions(S, superOptions{:});
            S.Run = rmfield(S.Run, 'runOnSeparateWorker');
        end
    end
    
    methods % Structor
        
        function obj = SignalExtractor(varargin)
            % Todo: Document and parse input arguments properly
            obj@nansen.stack.ImageStackProcessor(varargin{1:2})
            
            obj.RoiGroupArray = varargin{3};
            obj.DataIoModel = varargin{4};

            if ~nargout
                obj.runMethod()
                clear obj
            end
        end
        
    end
    
    methods (Access = protected)
        
        function onInitialization(obj)
            
            % Run initialization for all planes and channels.
            for i = 1:obj.StackIterator.NumIterations
                
                obj.StackIterator.next()
                iC = obj.StackIterator.CurrentChannel;
                iZ = obj.StackIterator.CurrentPlane;

                iRoiArray = obj.RoiGroupArray(iZ, iC).roiArray;
                if ~isempty(iRoiArray)
                    % Prepare extraction parameters for each channel and plane
                    obj.ExtractionParameters{iZ, iC} = obj.updateParameters(....
                        obj.Options.Extraction, obj.SourceStack, iRoiArray);
                    
                    % Prepare array of RoIs for efficient signal extraction:
                    obj.RoiDataArray{iZ, iC} = nansen.processing.roi.prepareRoiMasks( ...
                        iRoiArray, obj.ExtractionParameters{iZ, iC});
                    
                    % Signal extraction function depends on number of rois and is 
                    % assigned individually per channel and plane.
                    obj.assignSignalExtractionFcn(iZ, iC)
                else
                    obj.SignalExtractionFcn{iZ, iC} = {};
                end
            end
        end

    end
    
    methods (Access = protected) % Implement methods from ImageStackProcessor
        
        function [Y, results] = processPart(obj, Y)
            signalExtractionFcn = obj.SignalExtractionFcn{obj.CurrentPlane, obj.CurrentChannel};
            if ~isempty(signalExtractionFcn)
                results = signalExtractionFcn(Y);
            else
                results = [];
            end
            Y = [];
        end

        function saveResults(obj)
            % Skip for now, extraction is fast, dont need to save temporary
            % results.
        end

        function saveMergedResults(obj)
        %saveMergedResults Save final results.

            % Concatenate results along the roi dimensions.
            signalArray = cat(3, obj.MergedResults{:});

            % Save signals to session using predefined variable names (todo: generalize)
            obj.saveData('RoiSignals_MeanF', squeeze(signalArray(:, 1, :)))
            obj.saveData('RoiSignals_NeuropilF', squeeze(signalArray(:, 2:end, :)) )

            % Determine channel indices and plane indices for each roi:
            roiCount = arrayfun(@(c) c.roiCount, obj.RoiGroupArray);
            [numPlanes, numChannels] = size(roiCount);

            [channelInd, planeInd] = deal(arrayfun(@(i) ones(1,i), roiCount, 'UniformOutput',0));
            for iPlane = 1:numPlanes
                for jChannel = 1:numChannels
                    planeInd{iPlane,jChannel} = planeInd{iPlane,jChannel} * iPlane;
                    channelInd{iPlane,jChannel} = channelInd{iPlane,jChannel} * jChannel;
                end
            end
            
            PlaneIndices = [planeInd{:}];
            ChannelIndices = [channelInd{:}];

            % Save vectors with channel & plane indices to the signal file
            filePath = obj.getDataFilePath('RoiSignals_MeanF');
            save(filePath, 'PlaneIndices', '-append')
            save(filePath, 'ChannelIndices', '-append')

            % Save options
            obj.saveData('OptionsSignalExtraction', obj.Options.Extraction, ...
                'Subfolder', 'roisignals', 'IsInternal', true)
            
            % Inherit metadata from image stack
            fileAdapter = obj.DataIoModel.getFileAdapter('RoiSignals_MeanF');
            fileAdapter.setMetadata('SampleRate', obj.SourceStack.getSampleRate(), 'Data')

            %fileAdapter.setMetadata('StartTimeNum', imageStack.getStartTime('number'), 'Data')
            %fileAdapter.setMetadata('StartTimeStr', imageStack.getStartTime('string'), 'Data')
        end
    
        function runOnWorker(obj)
            error('Run on separate worker is not implemented for signal extractor')
        end
    
    end
    
    methods (Access = private) 

        function params = updateParameters(~, params, imageStack, roiArray)
        %updateParameters Update parameters that depend on data dimensions
        %
        %   Set value of imageMask if it is empty. (Depends on imageStack)
        %   Set roi indices if roiInd is set to 'all'. (Depends on roiArray)
        %   Set extractionFcn and roiMaskFormat if they are not set. (Depends on number of rois)
        
            % Create the imageMask if it is empty
            if isempty(params.imageMask) 
                imageSize = [imageStack.ImageHeight, imageStack.ImageWidth];
                params.imageMask = true(imageSize);
            end
            
            % Specify roi indices if the value is set to 'all'
            if strcmp(params.roiInd, 'all')
                numRois = numel(roiArray);
                params.roiInd = 1:numRois;
            end
            
            % Only serial extract supports median/percentile methods.
            if ~strcmp( params.pixelComputationMethod, 'mean' )
                params.extractFcn = @nansen.twophoton.roisignals.extract.serialExtract;
            end
            
            % Count number of rois to extract signals for.
            numRois = numel(params.roiInd);
        
            % Determine which extraction function to use. SerialExtract is faster
            % for fewer rois and batchExtract is faster for more rois.
            % Todo: Find out if the 200 threshold depends on memory/cpu
            if numRois < 200 && isempty(params.extractFcn)
                params.extractFcn = @nansen.twophoton.roisignals.extract.serialExtract;
                params.roiMaskFormat = 'struct';
                
            elseif numRois >= 200 && isempty(params.extractFcn)
                params.extractFcn = @nansen.twophoton.roisignals.extract.batchExtract;
                params.roiMaskFormat = 'sparse';
                
            elseif isequal(params.extractFcn, @nansen.twophoton.roisignals.extract.serialExtract)
                if ~strcmp(params.roiMaskFormat, 'struct')
                    params.roiMaskFormat = 'struct';
                    msg = ['Roi mask format was changed to ''struct'' because ', ...
                        'the selected extraction function is "serialExtract".'];
                    warning(msg);
                end 
                
            elseif isequal(params.extractFcn, @nansen.twophoton.roisignals.extract.batchExtract)
                if ~strcmp(params.roiMaskFormat, 'sparse')
                    params.roiMaskFormat = 'sparse';
                    msg = ['Roi mask format was changed to ''sparse'' because ', ...
                        'the selected extraction function is "batchExtract".'];
                    warning(msg);
                end
            end
        
        end

        function assignSignalExtractionFcn(obj, iZ, iC)
        %assignSignalExtractionFcn Assign signal extraction function 
        %
        %   Assign a signal extraction function per plane and channel. The
        %   signal extraction function depends on how many rois are present
        %   and is therefore dependent on the channel/plane.

            assert(~isempty(obj.RoiGroupArray), ...
                ['Roi Group must be assigned to property before ', ...
                 'assigning the signal extraction function'])
            assert(~isempty(obj.ExtractionParameters), ...
                ['Signal extraction parameters must be assigned to ', ...
                 'property before assigning the signal extraction function'])
            
            signalExtractionFcn = obj.ExtractionParameters{iZ, iC}.extractFcn;
            
            obj.SignalExtractionFcn{iZ,iC} = @(Y) signalExtractionFcn(Y, ...
                obj.RoiDataArray{iZ,iC}, obj.ExtractionParameters);
        end

    end
    
end