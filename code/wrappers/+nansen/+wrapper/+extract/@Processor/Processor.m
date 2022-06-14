classdef Processor < nansen.processing.RoiSegmentation & ...
                        nansen.wrapper.abstract.ToolboxWrapper
%nansen.wrapper.extract.Processor Wrapper for running EXTRACT on nansen
%
%   h = nansen.wrapper.extract.Processor(imageStackReference)
%
%   This class provides functionality for running EXTRACT within
%   the nansen package.


%   This class creates the following data variables:
%
%     * <strong>ExtractOptions</strong> : Struct with options used.
%
%     * <strong>ExtractResultsTemp</strong> : Cell array of struct. One struct for each chunk of imagestack. 
%           Struct contains output from EXTRACT
%
%     * <strong>ExtractResultsFinal</strong> : Cell array of structs. One struct for each channel and/or 
%           plane of ImageStack. Struct contains output from EXTRACT
%
%     * <strong>roiArrayExtractAuto</strong> : array of RoI objects
%           resulting from running EXTRACT autosegmentation


% Rename to ExtractorS??

    properties (Constant, Hidden) 
        DATA_SUBFOLDER = fullfile('roi_data', 'autosegmentation_extract')
        VARIABLE_PREFIX = 'Extract';
    end

    properties (Constant) % Attributes inherited from nansen.DataMethod
        MethodName = 'EXTRACT (Autosegmentation)'
        OptionsManager nansen.manage.OptionsManager = ...
            nansen.OptionsManager('nansen.wrapper.extract.Processor')
    end
    
    properties (Constant) % From ImageStack Processor...
        ImviewerPluginName = 'EXTRACT'
    end

    
    methods % Constructor 
        
        function obj = Processor(varargin)
        %nansen.wrapper.extract.Processor Construct extract processor
        %
        %   h = nansen.wrapper.extract.Processor(imageStackReference)
            
            obj@nansen.processing.RoiSegmentation(varargin{:})
        
            % Return if there are no inputs.
            if numel(varargin) == 0
                return
            end

            % Call the appropriate run method
            if ~nargout
                obj.runMethod()
                clear obj
            end
            
        end
        
    end
    
    methods (Access = protected) % Implementation of ImageStackProcessor methods
        
        % Step 1
        function onInitialization(obj)
            onInitialization@nansen.processing.RoiSegmentation(obj)
                        
            % This should only be done once... Adjust the number of cells
            % to find based on the division of the images in x-y. I.e if
            % image is divided in 4 patches, divide the number of cells to
            % find by 4.
            obj.adjustNumCellsToFind()
        end
        
        % Step 2 : Run the autosegmentation on each chunk of ImageStack.
        function result = segmentPartition(obj, Y)
        %segmentPartition Segment subpart of ImageStack
            options = obj.ToolboxOptions;
            result = extractor(Y, options);
        end

        % Step 3
        function onCompletion(obj)

            % Run superclass method first:
            onCompletion@nansen.processing.RoiSegmentation(obj)
            
            if ~isfile(obj.getDataFilePath('ExtractTemporalWeights'))
            
                if isempty(obj.MergedResults)
                    obj.mergeResults()
                end
                
                if isempty(obj.OriginalStack)
                    sourceStack = obj.SourceStack;
                else
                    sourceStack = obj.OriginalStack;
                end
                
                % Get temporal segments %Todo: Should just be a separate method...
                tExtracor = nansen.wrapper.extract.ProcessorT(...
                    sourceStack, obj.Options, obj.MergedResults);
                tExtracor.Options.Run.numFramesPerPart = 2000;
                tExtracor.DataIoModel = obj.DataIoModel;

                tExtracor.runMethod()
            end
            
            %obj.createRoiClassificationData()
            
        end
        
    end
    
    
    methods (Access = protected) % Implementation of RoiSegmentation methods
        
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
                
            optionsVarname = 'ExtractOptions';

            % Initialize options (Load from session if options already
            % exist, otherwise save to session)
            opts = obj.initializeOptions(opts, optionsVarname);
            
        end
        
        function dsFactor = getTemporalDownsamplingFactor(obj)
            
            % Prioritize value from internal pipeline
            dsFactor1 = obj.Options.Downsample.downsample_time_by;
            dsFactor2 = obj.Options.Run.TemporalDownsamplingFactor;
            
            if dsFactor1 > 1
                obj.Options.Downsample.downsample_time_by = 1; % Need to set this to 1, because stack processor takes care of downsampling...
                dsFactor = dsFactor1;
            elseif dsFactor2 > 1
                dsFactor = dsFactor2;
            else
                dsFactor = 1;
            end

        end
        
        function mergeSpatialComponents(obj, iPlane, iChannel)
        %mergeSpatialComponentsLiberal    

            iMergedResults = obj.Results{1, iPlane, iChannel};
            [h, w, ~] = size(iMergedResults.spatial_weights);

            for i = 2:size(obj.Results, 1)

                % Find matching indices between two sets of spatial masks
                S{1} = iMergedResults.spatial_weights;
                T{1} = iMergedResults.temporal_weights;
                S_{1} = reshape(S{1}, [], size(S{1}, 3));

                S{2} = obj.Results{i, iPlane, iChannel}.spatial_weights;
                T{2} = obj.Results{i, iPlane, iChannel}.temporal_weights;
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
                iMergedResults.spatial_weights = cat(3, S{:});

            end

            obj.MergedResults{iPlane, iChannel} = iMergedResults;
        end
        
        function roiArrayCell = getRoiArray(obj)
        %getRoiArray Get results as a roi array
            
            [numZ, numC] = size(obj.MergedResults);
            roiArrayCell = cell(numZ, numC);

            for i = 1:numZ
                for j = 1:numC
                    spatialWeights = obj.MergedResults{i,j}.spatial_weights;
        
                    roiArrayCell{i,j} = nansen.wrapper.extract.convert2rois(...
                        struct('spatial_weights', spatialWeights));
                    
                end
            end
        end
        
        function getRoiAppData(obj)
            getRoiAppData@nansen.processing.RoiSegmentation(obj)
            
            %obj.runMethodOnEachPlane('addSpatialWeightsToRoiImages')
            
            [numZ, numC] = size(obj.RoiArray);
            
            for iZ = 1:numZ
                for iC = 1:numC
                    obj.addSpatialWeightsToRoiImages(iZ, iC)
                end
            end
            
        end

    end
    
    methods (Access = private) % Methods specific to the Extract Processor
        
        function createRoiClassificationData(obj)
            
            % Load subset of downsampled image stack
            N = obj.SourceStack.chooseChunkLength();
            imArray = obj.SourceStack.getFrameSet(1:N);
            
            % Load roiArray
            roiArray = obj.loadData( obj.RoiArrayVarName );
            
            % Load signals
            roiSignals = obj.loadData('ExtractTemporalWeights');

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
            
           
            
            % Add area as a statistical value
            [roiStats(:).Area] = deal(roiArray.area);
            
            
            % Save to roi file...
            filePath = obj.getDataFilePath( obj.RoiArrayVarName );
            S = struct('roiImages', roiImages, 'roiStats', roiStats);
            save(filePath, '-struct', 'S', '-append') 
            
            %tic; S = load(filePath); toc
            
        end
        
        function addSpatialWeightsToRoiImages(obj, iZ, iC)
        %addSpatialWeightsToRoiImages Add spatial weights to roi images
        %

            if isempty(obj.RoiArray{iZ, iC}); return; end
        
            % Get initial data.
            spatialWeights = obj.MergedResults{iZ, iC}.spatial_weights;

            roiArray = obj.RoiArray{iZ, iC};
            roiImages = obj.RoiImages{iZ, iC};
            numRois = numel(roiArray);
            
            

            % Get spatial weigths as uin8 roi thumbnail images.
            imArray = nansen.wrapper.extract.util.convertSpatialWeightsToThumbnails(...
                roiArray, spatialWeights);

            getuint8im = @(idx) stack.makeuint8(imArray(:,:,idx));
            imCellArray = arrayfun(@(i) getuint8im(i), 1:numRois, 'uni', 0);

            % Add to roiImages
            if ~isempty(obj.RoiImages{iZ, iC})
                [roiImages(:).SpatialWeights] = deal(imCellArray{:});
            else
                roiImages = struct;
                [roiImages(1:numRois).SpatialWeights] = deal(imCellArray{:});
            end

            % Reorder fields so that spatial weights are the first one.
            fieldNames = fieldnames(roiImages);
            newFieldnameOrder = ['SpatialWeights', ...
                setdiff(fieldNames, 'SpatialWeights', 'stable')' ];

            obj.RoiImages{iZ, iC} = orderfields(roiImages, newFieldnameOrder);

        end
        
        function mergeSpatialComponentsOld(obj, iPlane, iChannel)
                        
            mergedResults = obj.Results{1, iPlane, iChannel};
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