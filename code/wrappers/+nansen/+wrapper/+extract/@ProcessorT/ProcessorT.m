classdef ProcessorT < nansen.stack.ImageStackProcessor

%   This class creates the following data variables:
%
%     * <strong>ExtractTemporalWeights</strong> : Extracted temporal components
%           (numRois x numTimepoints) single matrix
    
    % Rename to ExtractT

    % Todo: Run per channel and plane...
    
    properties (Constant, Hidden)
        DATA_SUBFOLDER = fullfile('roi_data', 'autosegmentation_extract')
        VARIABLE_PREFIX = 'ExtractTemporal'
    end
    
    properties (Constant)
        MethodName = 'EXTRACT (Signal Extraction)'
        IsManual = false        % Does method require manual supervision
        IsQueueable = true      % Can method be added to a queue
        OptionsManager nansen.manage.OptionsManager = ...
            nansen.OptionsManager('nansen.wrapper.extract.Processor')
    end
    
    properties %Options
        
    end
    
    properties (Access = private)
        SegmentationResults cell % nPlanes x nChannels
        ExtractConfig cell % nPlanes x nChannels
        %Results % cell array with cell for each part..
    end
    
    methods (Static)
        function S = getDefaultOptions()
        end
    end
    
    methods % Structor
        
        function obj = ProcessorT(varargin)
            
            obj@nansen.stack.ImageStackProcessor(varargin{:})
            obj.SegmentationResults = varargin{3};
            
            % Todo: Need to assign options and output from extract!
            
            if ~nargout
                obj.runMethod()
                clear obj
            end
        end
    end
    
    methods (Access = protected)
        
        function onInitialization(obj)
        %onInitialization Initialize variables
        
            filePath = obj.getDataFilePath('ExtractTemporalWeights_temp', '-w',...
                'Subfolder', obj.DATA_SUBFOLDER, 'IsInternal', true);
           
            if isfile(filePath)
                obj.Results = obj.loadData('ExtractTemporalWeights_temp');
            end
        
            % Todo: Load from file....
            if isempty(obj.Results)
                obj.Results = cell(1, obj.NumParts);
            end
        
            if ~isa(obj.SegmentationResults, 'cell')
                obj.SegmentationResults = {obj.SegmentationResults};
            end
            assert(isa(obj.SegmentationResults{1}, 'struct'), ...
                'Expected segmentation results to be a cell array of structs')
            obj.ExtractConfig = cell(size(obj.SegmentationResults));
            
            for i = 1:numel(obj.SegmentationResults)
                spatialWeights = obj.SegmentationResults{i}.spatial_weights;
                [h, w, n] = size(spatialWeights);
                
                config = obj.SegmentationResults{i}.config;
                config.max_iter = 0;
                config.num_iter_stop_quality_checks=0;
                config.S_init = reshape(spatialWeights, h * w, n);
                config.verbose = 0;
            
                obj.ExtractConfig{i} = config;
            end
        end
        
        function onCompletion(obj)
            % Todo: Fix this, need to run on a longer stack to ensure the temporal chunks are correctly merged...
            % Todo: Adapt to work for multi-plane / multi-channel
            % Concatenate temporal signals....
            
            T = cat(2, obj.Results{:});
            signalArray = cat(3, obj.Results{:});

            obj.MergedResults
            % Save temporal profiles
            obj.saveData('ExtractTemporalWeights', T, 'Subfolder', ...
                obj.DATA_SUBFOLDER, 'IsInternal', true)
        end
    end
    
    methods (Access = protected) % Implement methods from ImageStackProcessor
        
        function [YOut, results] = processPart(obj, Y)

            iC = obj.StackIterator.CurrentIterationC;
            iZ = obj.StackIterator.CurrentIterationZ;
            config = obj.ExtractConfig{iZ, iC};
            
            [~, results, ~] = run_extract(Y, config);
            
            YOut = [];
            %obj.Results{obj.CurrentPart} = T;
            %obj.saveData('ExtractTemporalWeights_temp', obj.Results)
            %results = [];
        end

        function tf = checkIfPartIsFinished(obj, partNumber)
            tf = ~isempty(obj.Results{partNumber});
        end
    end
    
    methods (Access = private)

        function loadResults(obj)
        end
    end
end
