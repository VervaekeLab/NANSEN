classdef Processor < nansen.processing.RoiSegmentation & ...
                        nansen.wrapper.abstract.ToolboxWrapper
%nansen.wrapper.suite2p.Processor Wrapper for running.suite2p within nansen
%
%   h = nansen.wrapper.suite2p.Processor(imageStackReference) runs suite2p
%   on the ImageStack referred to by the imageStackReference. Valid
%   references are an ImageStack object or a filepath to a file that can be
%   opened as an ImageStack object.
%
%   h = nansen.wrapper.suite2p.Processor(__, options) additionally
%       specifies the options to use for the processor. 
% 
%   To get the default options:
%       defOptions = nansen.wrapper.suite2p.Processor.getDefaultOptions()
%
%   For additional optional parameters that can be used for configuring the 
%   processor;
%   See also nansen.stack.ImageStackProcessor 
%
%
%   This class creates the following data variables:
%
%     * <strong>Suite2pOptions</strong> : Struct with options used.
%
%     * <strong>Suite2pResultsTemp</strong> : Cell array of struct. One struct for each chunk of imagestack. 
%           Struct contains output from suite2p
%
%     * <strong>Suite2pResultsFinal</strong> : Cell array of structs. One struct for each channel and/or 
%           plane of ImageStack. Struct contains output from suite2p
%
%     * <strong>roiArraySuite2pAuto</strong> : array of RoI objects
%           resulting from running suite2p autosegmentation



    properties (Constant, Hidden) 
        DATA_SUBFOLDER = fullfile('roi_data', 'autosegmentation_suite2p')
        VARIABLE_PREFIX = 'Suite2p';
    end

    properties (Constant) % Attributes inherited from nansen.DataMethod
        MethodName = 'suite2p (Autosegmentation)'
        OptionsManager nansen.manage.OptionsManager = ...
            nansen.OptionsManager('nansen.wrapper.suite2p.Processor')
    end
    
    properties (Constant) % From ImageStack Processor...
        ImviewerPluginName = ''
    end

    
    methods % Constructor 
        
        function obj = Processor(varargin)
        %nansen.wrapper.suite2p.Processor Construct suite2p processor
        %
        %   h = nansen.wrapper.suite2p.Processor(imageStack) specifies the
        %   given ImageStack as a SourceStack for the suite2p processor.
        %
        %   See also nansen.stack.ImageStackProcessor/ImageStackProcessor
            
            nansen.assert('Suite2pOnSavepath')

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
    
    methods (Access = protected) % Implementation of superclass methods
        
        % Step 1
        function onInitialization(obj)
            onInitialization@nansen.processing.RoiSegmentation(obj)
        end
        
        % Step 2 : Run the autosegmentation on each chunk of ImageStack.
        % Function in separate file
        result = segmentPartition(obj, Y)

        % Step 3
        function onCompletion(obj)

            % Run superclass method first:
            onCompletion@nansen.processing.RoiSegmentation(obj)
        end
        
    end
    
    methods (Access = protected) % Implementation of RoiSegmentation methods
        
        function opts = getToolboxSpecificOptions(obj, varargin)
        %getToolboxSpecificOptions Get suite2p options from parameters or file
        %
        %   OPTS = getToolboxSpecificOptions(OBJ) return a
        %   struct of parameters for the suite2p pipeline.
            
            import nansen.wrapper.suite2p.Options
            opts = Options.convert(obj.Options);

            % Initializes options (Load from data folder if options already
            % exist, otherwise initialize and save to data folder)
            opts = obj.initializeOptions(opts);
        end

        function mergeSpatialComponents(obj, iPlane, iChannel)
        %mergeSpatialComponents Merge spatial components.
            
            import flufinder.detect.findUniqueRoisFromComponents
            import nansen.wrapper.suite2p.utility.* % conversion functions

            numParts = size(obj.Results, 1);
            imageSize = obj.SourceStack.FrameSize;
            
            % Merge stat struct arrays form all sub parts
            statCellArray = cellfun(@(c) c.stat, obj.Results(:, iPlane, iChannel), 'UniformOutput', false);
            stat = cat(2, statCellArray{:});
            S = convertS2pStatToRegionProps(stat, imageSize); %Imported fcn
            
            % Merge all the components
            numObservationsRequired = min(3, ceil(numParts/2));
            S = flufinder.detect.mergeWeightedComponents(imageSize, S, ...
                'NumObservationsRequired', numObservationsRequired);
            
            stat = convertRegionPropsToS2pStat(S, imageSize); %Imported fcn

            numRois = numel(stat);
            obj.printSubTask(sprintf('Channel %d, Plane %d: %d rois remains after refinement.', iChannel, iPlane, numRois))

            % Todo: merge ops...
            mergedResults = struct('stat', stat, 'ops',  obj.Results{1, iPlane, iChannel}.ops);
            obj.MergedResults{iPlane, iChannel} = mergedResults;
        end

        function roiArrayCell = getRoiArray(obj)
        %getRoiArray Get results as a roi array
            
            [numZ, numC] = size(obj.MergedResults);
            roiArrayCell = cell(numZ, numC);
            imageSize = obj.SourceStack.FrameSize;

            for i = 1:numZ
                for j = 1:numC
                    S = obj.MergedResults{i,j};
                    roiArrayCell{i,j}  = nansen.wrapper.suite2p.getRoiArray(S.stat, imageSize);
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
    
    methods (Access = private) % Methods specific to the suite2p Processor
        
        function addSpatialWeightsToRoiImages(obj, iZ, iC)
        %addSpatialWeightsToRoiImages Add spatial weights to roi images
        %
        %   Add the spatial weights from the suite2p output as thumbnail
        %   images for each roi.

            if isempty(obj.RoiArray{iZ, iC}); return; end
        
            % Get initial data.
            S = obj.MergedResults{iZ, iC};

            roiArray = obj.RoiArray{iZ, iC};
            roiImages = obj.RoiImages{iZ, iC};
            numRois = numel(roiArray);
            
            spatialWeights = obj.convertStatToSpatialWeigths(S.stat);

            % Get spatial weigths as uint8 roi thumbnail images.
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
    
        function spatialWeights = convertStatToSpatialWeigths(obj, stat)
            
            imageSize = obj.SourceStack.FrameSize;
            spatialWeights = zeros([imageSize, numel(stat)]);
            
            for i = 1:numel(stat)
                thisWeight = spatialWeights(:,:,i);
                thisWeight(stat(i).ipix) = stat(i).lam;
                spatialWeights(:, :, i) = thisWeight;
            end
        end
    end
    
    methods (Static) % Method in external file.
        
        function options = getDefaultOptions()
            import nansen.wrapper.abstract.ToolboxWrapper
            className = mfilename('class');
            options = ToolboxWrapper.getDefaultOptions(className);
        end
        
        pathList = getDependentPaths()

        function assertAddonInstalled()
            if ~exist('build_ops3', 'file')
                error('Suite2P was not found on MATLAB''s search path')
            end
        end
    end

end