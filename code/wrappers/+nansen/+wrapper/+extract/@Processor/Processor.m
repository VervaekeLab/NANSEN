classdef Processor < nansen.processing.RoiSegmentation & ...
                        nansen.wrapper.abstract.ToolboxWrapper
%nansen.wrapper.extract.Processor Wrapper for running EXTRACT on nansen
%
%   h = nansen.wrapper.extract.Processor(imageStackReference)
%
%   This class provides functionality for running EXTRACT within
%   the nansen package.

% Rename to ExtractorS??

    properties (Constant, Hidden)
        DATA_SUBFOLDER = fullfile('roi_data', 'autosegmentation_extract')
    end

    properties (Constant) % Attributes inherited from nansen.DataMethod
        MethodName = 'EXTRACT (Autosegmentation)'
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
        
        function initializeVariables(obj)
            %initializeVariables@nansen.processing.RoiSegmentation()
            
        end
        
        function saveResults(obj)
            tempResults = obj.Results;
            obj.saveData('extractResultsTemp', tempResults) 
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
            
            % Make sure gpu option is turned off if running macOS version
            % 10.14 or above.
            if ismac
                [status, OSVersion] = system('sw_vers -productVersion');
                if ~status && str2double(OSVersion) > 10.14
                    if opts.use_gpu
                        opts.use_gpu = false;
                        warning('Turned off GPU acceleration because GPU acceleration with Parallel Computing Toolbox is not supported on macOS versions 10.14 (Mojave) and above')
                    end
                end
            end
                
            optionsVarname = 'extractOptions';

            % Initialize options (Load from session if options already
            % exist, otherwise save to session)
            opts = obj.initializeOptions(opts, optionsVarname);
            
        end
        
        function dsFactor = getTemporalDownsamplingFactor(obj)
            % Todo:
            %dsFactor = obj.Options.Downsample.downsample_time_by;
            %obj.Options.Downsample.downsample_time_by = 1;
            dsFactor = 10;
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
            
            filePath = obj.getDataFilePath('extractResultsTemp', '-w',...
                'Subfolder', obj.DATA_SUBFOLDER);
            
            if isfile(filePath)
                obj.Results = obj.loadData('extractResultsTemp');
            end
            
        end

        function onCompletion(obj)
            
            if ~isfile(obj.getDataFilePath('roiArrayExtractAuto'))
            
                % Combine spatial segments
                if numel(obj.Results) > 1
                    %obj.mergeSpatialComponents()
                    obj.mergeSpatialComponentsLiberal()
                    spatialWeights = obj.MergedResults.spatial_weights;
                else
                    spatialWeights = obj.Results{1}.spatial_weights;
                end

                % Save (merged) results as spatial weights and roiarray
                obj.saveData('ExtractSpatialWeightsAuto', spatialWeights, ...
                    'Subfolder', obj.DATA_SUBFOLDER)

                roiArray = nansen.wrapper.extract.convert2rois(...
                    struct('spatial_weights', spatialWeights));

                obj.saveData('roiArrayExtractAuto', roiArray, ...
                    'Subfolder', 'roi_data')
            end
            
            if ~isfile(obj.getDataFilePath('extractTemporalWeights'))

                % Get temporal segments %Todo: Should just be a separate method...
                tExtracor = nansen.wrapper.extract.ProcessorT(...
                    obj.OriginalStack, obj.Options, obj.MergedResults);
                tExtracor.Options.Run.numFramesPerPart = 2000;
                tExtracor.DataIoModel = obj.DataIoModel;

                tExtracor.runMethod()
            
            end
            
            
            obj.createRoiClassificationData()
            
        end
        
    end
    
    methods (Access = private)
        
        function createRoiClassificationData(obj)
            
            % Load subset of downsampled image stack
            N = obj.SourceStack.chooseChunkLength();
            N = min([N, obj.SourceStack.NumTimepoints]);
            
            imArray = obj.SourceStack.getFrameSet(1:N);
            
            % Load roiArray
            roiArray = obj.loadData('roiArrayExtractAuto');
            
            % Load signals
            roiSignals = obj.loadData('extractTemporalWeights');

            % Downsample signals
            if isprop(obj.SourceStack, 'DownsamplingFactor')
                
                q = obj.SourceStack.DownsamplingFactor;
                roiSignalsDs = resample(double(roiSignals)', 1, q)';
                roiSignals = roiSignalsDs;
            end
            
            % Choose same subset as for signals
            roiSignals = roiSignals(:, 1:N);
            
            [roiImages, roiStats] = roimanager.utilities.createRoiUserdata(...
                roiArray, imArray, roiSignals);
            
            % Add spatial weights...
            
            spatialWeights = obj.loadData('ExtractSpatialWeightsAuto');
            imArray = nansen.wrapper.extract.util.convertSpatialWeightsToThumbnails(...
                roiArray, spatialWeights);
            
            imCellArray = arrayfun(@(i) stack.makeuint8(imArray(:,:,i)), 1:numel(roiArray), 'uni', 0);
            
            [roiImages(:).spatialWeight] = deal(imCellArray{:});
            
            fieldNames = fieldnames(roiImages);
            fieldNames = ['spatialWeight', setdiff(fieldNames, 'spatialWeight', 'stable')' ];
            roiImages = orderfields(roiImages, fieldNames);
            
            % Add area as a statistical value
            [roiStats(:).Area] = deal(roiArray.area);
            
            
            % Save to roi file...
            filePath = obj.getDataFilePath('roiArrayExtractAuto');
            S = struct('roiImages', roiImages, 'roiStats', roiStats);
            save(filePath, '-struct', 'S', '-append') 
            
            %tic; S = load(filePath); toc
            
        end
        
        function mergeSpatialComponents(obj)
            
            mergedResults = obj.Results{1};
            [h, w, n] = size(mergedResults.spatial_weights);
            
            for i = 2:numel(obj.Results)
                
                % Find matching indices between two sets of spatial masks
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
        
        function mergeSpatialComponentsLiberal(obj)
                        
            mergedResults = obj.Results{1};
            [h, w, n] = size(mergedResults.spatial_weights);
            
            for i = 2:numel(obj.Results)
                
                % Find matching indices between two sets of spatial masks
                S{1} = mergedResults.spatial_weights;
                T{1} = mergedResults.temporal_weights;
                S_{1} = reshape(S{1}, [], size(S{1}, 3));
                
                S{2} = obj.Results{i}.spatial_weights;
                T{2} = obj.Results{i}.temporal_weights;
                S_{2} = reshape(S{2}, [], size(S{2}, 3));
                
                idx_match = match_sets(S_{1}, S_{2});
                                
                % Merge components that are matched
                Smerged = cell(1,2);
                
                for j = 1:2
                    Smerged{j} = S_{j}(:, idx_match(j, :));
                    Smerged{j} = reshape(Smerged{j}, h, w, []);
                    S{j}(:, :, idx_match(j, :)) = [];
                end
                
                SMerged = mean( cat(4, Smerged{:}), 4 );
                
                % Insert merged components back to original rois and combine
                S{1} = utility.insertIntoArray(S{1}, SMerged, idx_match(1, :), 3);
                mergedResults.spatial_weights = cat(3, S{:});
                
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