classdef ProcessorT < nansen.stack.ImageStackProcessor
    
    % Rename to ExtractT
    
    properties (Constant, Hidden)
        DATA_SUBFOLDER = fullfile('roi_data', 'autosegmentation_extract')
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
        SegmentationResults
        ExtractConfig
        Results % cell array with cell for each part..
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
        
            filePath = obj.getDataFilePath('extractTemporalWeights_temp', '-w',...
                'Subfolder', obj.DATA_SUBFOLDER);
            
            if isfile(filePath)
                obj.Results = obj.loadData('extractTemporalWeights_temp');
            end
        
            % Todo: Load from file....
            if isempty(obj.Results)
                obj.Results = cell(1, obj.NumParts);
            end
        
            spatialWeights = obj.SegmentationResults.spatial_weights;
            [h, w, n] = size(spatialWeights);
            
            config = obj.SegmentationResults.config;
            config.max_iter = 0;
            config.num_iter_stop_quality_checks=0;
            config.S_init = reshape(spatialWeights, h * w, n); 
            config.verbose = 0;
            
            obj.ExtractConfig = config;
            
        end
        
        function onCompletion(obj)
            
            % Concatenate temporal signals....
            T = cat(2, obj.Results{:});
            
            % Save temporal profiles
            obj.saveData('extractTemporalWeights', T, 'Subfolder', obj.DATA_SUBFOLDER)
        end

    end
    
    methods (Access = protected) % Implement methods from ImageStackProcessor
        
        function results = processPart(obj, Y)

            config = obj.ExtractConfig;
            
            [~, T, ~] = run_extract(Y, config);
            
            obj.Results{obj.CurrentPart} = T;
            obj.saveData('extractTemporalWeights_temp', obj.Results)
            
            results = [];
            
        end

        function tf = checkIfPartIsFinished(obj, partNumber)
            tf = ~isempty(obj.Results{partNumber});
        end
        
    end
    
    methods (Access = private) 

        function loadResults(obj)
        end
        
        function saveResults(obj)
        end

    end
    

end