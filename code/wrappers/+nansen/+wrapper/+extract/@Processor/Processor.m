classdef Processor < nansen.processing.RoiSegmentation & ...
                        nansen.wrapper.abstract.ToolboxWrapper
%nansen.wrapper.extract.Processor Wrapper for running EXTRACT on nansen
%
%   h = nansen.wrapper.extract.Processor(imageStackReference)
%
%   This class provides functionality for running EXTRACT within
%   the nansen package.

% Rename to ExtractorS??


    properties (Constant) % Attributes inherited from nansen.DataMethod
        MethodName = 'Autosegmentation (EXTRACT)'
        IsManual = false        % Does method require manual supervision
        IsQueueable = true      % Can method be added to a queue
        OptionsManager nansen.manage.OptionsManager = ...
            nansen.OptionsManager('nansen.wrapper.extract.Processor')
    end
    
    properties (Constant) % From imagestack...
        ImviewerPluginName = 'EXTRACT'
    end
    
    properties
        MergedResults
    end
    
    
    methods % Constructor 
        
        function obj = Processor(varargin)
        %nansen.wrapper.extract.Processor Construct normcorre processor
        %
        %   h = nansen.wrapper.extract.Processor(imageStackReference)
            
            obj@nansen.processing.RoiSegmentation(varargin{:})
        
            % Return if there are no inputs.
            if numel(varargin) == 0
                return
            end

            % Todo. Move to superclass
            obj.Options.Export.FileName = obj.SourceStack.Name;
            
            % Call the appropriate run method
            if ~nargout
                obj.runMethod()
                clear obj
            end
            
        end
        
    end
    
    methods
        
        function saveResults(obj)
           
            tempResults = obj.Results;
            obj.saveData('extractResultsTemp1', tempResults) 
        end
        
    end
    
    methods (Access = protected) % Implementation of abstract, public methods
        
        function opts = getToolboxSpecificOptions(obj, varargin)
        %getToolboxSpecificOptions Get EXTRACT options from parameters or file
        %
        %   OPTS = getToolboxSpecificOptions(OBJ, STACKSIZE) return a
        %   struct of parameters for the EXTRACT pipeline.
        %
        %
        %   Todo: Need to adapt to aligning on multiple channels/planes.
            % validate/assert that arg is good
            %stackSize = varargin{1};
            
            import nansen.wrapper.extract.Options
            opts = Options.convert(obj.Options);%, stackSize);
            
            optionsVarname = 'extractOptions';
            
            % Initialize options (Load from session if options already
            % exist, otherwise save to session)
            opts = obj.initializeOptions(opts, optionsVarname);
            
        end
        
        function tf = checkIfPartIsFinished(obj, partNumber)
        %checkIfPartIsFinished Check if shift values exist for given frames
                    
            msg = 'Number of parts is not matched';
            assert(obj.NumParts == numel(obj.Results), msg)
            
            tf = ~isempty(obj.Results{partNumber});
            
        end
        
    end
    
    methods (Access = protected) % Run the motion correction / image registration

        function result = segmentPartition(obj, Y)
            
            % This should only be done once... (internal check ensures)
            obj.adjustNumCellsToFind()
            
            options = obj.ToolboxOptions;
            result = extractor(Y, options);
            
        end

        function onInitialization(obj)
            
            onInitialization@nansen.processing.RoiSegmentation(obj)
            
            filePath = obj.getDataFilePath('extractResultsTemp1', '-w',...
                'Subfolder', 'image_segmentation');
            
            if isfile(filePath)
                obj.Results = obj.loadData('extractResultsTemp1');
            end
            
        end

        function onCompletion(obj)
            
            % Combine spatial segments
            if numel(obj.Results) > 1
                obj.mergeSpatialComponents()
            end
            
            
            % Get temporal segments
            
            tExtracor = nansen.wrapper.extract.ProcessorT(...
                obj.OriginalStack, obj.Options, obj.MergedResults);
            tExtracor.Options.Run.numFramesPerPart = 2000;
            tExtracor.runMethod()
            
            results = tExtractor.getResults;
            
            % Concatenate temporal profiles...
            
        end
        
    end
    
    methods (Access = private)
        
        function mergeSpatialComponents(obj)
            
            mergedResults = obj.Results{1};
            [h, w, n] = size(mergedResults.spatial_weights);
            
            for i = 2:numel(obj.Results)
                
                S{1} = mergedResults.spatial_weights;
                S{1} = reshape(S{1}, [], size(S{1}, 3));
                
                S{2} = obj.Results{i}.spatial_weights;
                S{2} = reshape(S{2}, [], size(S{2}, 3));
                
                idx_match = match_sets(S{1}, S{2});
                
                Skeep = cell(1,2);
                
                for j = 1:2
                    Skeep{j} = S{j}(:, idx_match(j, :));
                    Skeep{j} = reshape(Skeep{j}, h, w, []);
                end
                
                SMerged = mean( cat(4, Skeep{:}), 4 );
                mergedResults.spatial_weights = SMerged;
                
                T{1} = mergedResults.temporal_weights(:, idx_match(1, :));
                T{2} = obj.Results{i}.temporal_weights(:, idx_match(2, :));
                
                TMerged = cat(1, T{:});

                mergedResults.temporal_weights = TMerged;
                
            end
            
            obj.MergedResults = mergedResults;
            
        end
        
        function mergeTemporalComponents(obj)
            
        end
        
        function adjustNumCellsToFind(obj)
        %adjustNumCellsToFind Adjust number of cells to find if multiple
        %spatial partitions will be used. 

            numPartitions = obj.ToolboxOptions.num_partitions_x * ...
                                obj.ToolboxOptions.num_partitions_y;
            
            if numPartitions > 1
                if ~isfield(obj.ToolboxOptions, 'cellfind_max_steps_orig')
                    obj.ToolboxOptions.cellfind_max_steps_orig = obj.ToolboxOptions.cellfind_max_steps;
                    obj.ToolboxOptions.cellfind_max_steps = obj.ToolboxOptions.cellfind_max_steps ./ numPartitions;
                end
            end
            
        end

    end
    
    
    methods (Static) % Method in external file.
        options = getDefaultOptions()
        
        pathList = getDependentPaths()
    end

end