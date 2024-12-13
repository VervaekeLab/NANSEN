classdef Processor < nansen.processing.RoiSegmentation & ...
                        nansen.wrapper.abstract.ToolboxWrapper
%nansen.wrapper.extract.Processor Wrapper for running EXTRACT within nansen
%
%   h = nansen.wrapper.extract.Processor(imageStackReference) runs extract
%   on the ImageStack referred to by the imageStackReference. Valid
%   references are an ImageStack object or a filepath to a file that can be
%   opened as an ImageStack object.
%
%   h = nansen.wrapper.extract.Processor(__, options) additionally
%       specifies the options to use for the processor.
%
%   To get the default options:
%       defOptions = nansen.wrapper.extract.Processor.getDefaultOptions()
%
%   For additional optional parameters that can be used for configuring the
%   processor;
%   See also nansen.stack.ImageStackProcessor
%
%
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

% Todo: Load temp results

% Rename to ExtractorS??

    properties (Constant, Hidden)
        DATA_SUBFOLDER = fullfile('roi_data', 'autosegmentation_extract')
        VARIABLE_PREFIX = 'Extract';
    end

    properties (Constant) % Attributes inherited from nansen.processing.DataMethod
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
        %   h = nansen.wrapper.extract.Processor(imageStack) specifies the
        %   given ImageStack as a SourceStack for the EXTRACT processor.
        %
        %   See also nansen.stack.ImageStackProcessor/ImageStackProcessor

            obj@nansen.processing.RoiSegmentation(varargin{:})

            obj.assertAddonInstalled()

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
    
    methods (Access = protected) % Implementation of superclass methods
        
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
                
                % % % Todo: The following should be a separate session method...
                % % if isempty(obj.OriginalStack)
                % %     sourceStack = obj.SourceStack;
                % % else
                % %     sourceStack = obj.OriginalStack;
                % % end
                % % 
                % % % Get temporal segments 
                % % tExtracor = nansen.wrapper.extract.ProcessorT(...
                % %     sourceStack, obj.Options, obj.MergedResults);
                % % tExtracor.Options.Run.numFramesPerPart = 2000;
                % % tExtracor.DataIoModel = obj.DataIoModel;
                % % 
                % % tExtracor.runMethod()
            end
            
            %obj.createRoiClassificationData()
        end
    end
    
    methods (Access = protected) % Implementation of RoiSegmentation methods
        
        function opts = getToolboxSpecificOptions(obj, varargin)
        %getToolboxSpecificOptions Get EXTRACT options from parameters or file
        %
        %   OPTS = getToolboxSpecificOptions(OBJ) return a
        %   struct of parameters for the EXTRACT pipeline.
            
            import nansen.wrapper.extract.Options
            opts = Options.convert(obj.Options);
            
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

            % Initialize options (Load from data folder if options already
            % exist, otherwise initialize and save to data folder)
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
        %mergeSpatialComponents Merge spatial components.

            iMergedResults = obj.Results{1, iPlane, iChannel};
            [h, w, ~] = size(iMergedResults.spatial_weights);
            
            numParts = size(obj.Results, 1);

            for i = 2:numParts

                % Find matching indices between two sets of spatial masks
                S{1} = iMergedResults.spatial_weights;
                S_{1} = reshape(S{1}, [], size(S{1}, 3)); % pixel x n

                S{2} = obj.Results{i, iPlane, iChannel}.spatial_weights;
                S_{2} = reshape(S{2}, [], size(S{2}, 3));

                idx_match = match_sets(S_{1}, S_{2});

                % Merge components that are matched
                Smerged = cell(1,2);

                for j = 1:2
                    Smerged{j} = S_{j}(:, idx_match(j, :));
                    Smerged{j} = reshape(Smerged{j}, h, w, []);
                    S{j}(:, :, idx_match(j, :)) = [];
                end
                
                % Merge rois by finding the average of the masks.
                % Todo: weight by number of parts.
                SMerged = mean( cat(4, Smerged{:}), 4 );

                % Insert merged components back to original rois and combine
                S{1} = utility.insertIntoArray(S{1}, SMerged, idx_match(1, :), 3);
                iMergedResults.spatial_weights = cat(3, S{:});

                % For merging temporal weights (deprecated)
                % % % T{1} = iMergedResults.temporal_weights;
                % % % T{2} = obj.Results{i, iPlane, iChannel}.temporal_weights;

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
        %getRoiAppData Extends superclass method to include spatial weights
        %
        %   Include spatial weights as images for all rois.

            getRoiAppData@nansen.processing.RoiSegmentation(obj)
                        
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
            
            % Note: Similar to getRoiAppData, but looks like it's
            % deprecated

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
        %   Add the spatial weights from the extract output as thumbnail
        %   images for each roi.

            if isempty(obj.RoiArray{iZ, iC}); return; end
        
            % Get initial data.
            spatialWeights = obj.MergedResults{iZ, iC}.spatial_weights;

            roiArray = obj.RoiArray{iZ, iC};
            roiImages = obj.RoiImages{iZ, iC};
            numRois = numel(roiArray);

            % Get spatial weights as uin8 roi thumbnail images.
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

        function assertAddonInstalled()
            if ~exist('run_extract', 'file')
                error('EXTRACT was not found on MATLAB''s search path')
            end
        end
    end
end
