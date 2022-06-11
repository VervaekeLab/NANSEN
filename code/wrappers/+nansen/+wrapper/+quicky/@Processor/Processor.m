classdef Processor < nansen.processing.RoiSegmentation & ...
                        nansen.wrapper.abstract.ToolboxWrapper
%nansen.wrapper.quicky.Processor Wrapper for running Quicky on nansen
%
%   h = nansen.wrapper.quicky.Processor(imageStackReference)
%
%   This class provides functionality for running Quicky within
%   the nansen package.
%
%
%   This class creates the following data variables:
%
%     * <strong>QuickyOptions</strong> : Struct with options used.
%
%     * <strong>QuickyResultsTemp</strong> : Cell array of struct. One struct for each chunk of imagestack. 
%           Struct contains output from Quicky
%
%     * <strong>roiArrayQuickyAuto</strong> : 
%
    properties (Constant, Hidden)
        DATA_SUBFOLDER = fullfile('roi_data', 'autosegmentation_quicky')
        VARIABLE_PREFIX = 'Quicky'
    end

    properties (Constant) % Attributes inherited from nansen.DataMethod
        MethodName = 'Autosegmentation (Quicky)'
        OptionsManager nansen.manage.OptionsManager = ...
            nansen.OptionsManager('nansen.wrapper.quicky.Processor')
    end
    
    properties (Constant) % From imagestack...
        ImviewerPluginName = ''
    end
    
    
    methods % Constructor
        
        function obj = Processor(varargin)
        %nansen.wrapper.quicky.Processor Construct quicky processor
        %
        %   h = nansen.wrapper.quicky.Processor(imageStackReference)
            
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
    
    methods (Access = protected) % Implementation of RoiSegmentation methods
        
        function opts = getToolboxSpecificOptions(obj, varargin)
        %getToolboxSpecificOptions Get options from parameters or file
        %
        %   OPTS = getToolboxSpecificOptions(OBJ, STACKSIZE) return a
        %   struct of parameters for the EXTRACT pipeline.
        %
        %
        %   Todo: Need to adapt to aligning on multiple channels/planes.
            % validate/assert that arg is good
            %stackSize = varargin{1};
            
            import nansen.wrapper.quicky.Options
            opts = Options.convert(obj.Options);
            
            optionsVarname = 'QuickyOptions';

            % Initialize options (Load from session if options already
            % exist, otherwise save to session)
            opts = obj.initializeOptions(opts, optionsVarname);
            
        end
        
        function mergeResults(obj)
        %mergeResults Merge results from each processing part
                    
            import flufinder.detect.findUniqueRoisFromComponents
            
            mergeResults@nansen.processing.RoiSegmentation(obj)
            
            imageSize = obj.SourceStack.FrameSize;

            [numZ, numC] = size(obj.MergedResults);
            roiArrayCell = cell(numZ, numC);

            for i = 1:numZ
                for j = 1:numC
                    
                    % Combine spatial segments
                    S = cat(1, obj.MergedResults{i,j}.spatialComponents );
                
                    roiArrayCell{i,j} = findUniqueRoisFromComponents(imageSize, S);
                    %roiArrayT = findUniqueRoisFromComponents(imageSize, S);         % imported function
                end
            end
            
            obj.RoiArray = roiArrayCell;
            %obj.RoiArray = roiArrayT;
        end
        
        function finalizeResults(obj)
        %finalizeResults Finalize the results using flufinder's pipeline

            import nansen.twophoton.roi.compute.computeRoiImages
        
            opts = obj.ToolboxOptions;
            roiArrayT = obj.RoiArray;
            imArray = obj.getImageArray();
            
            %avgIm = mean( cat(3, obj.Results(1).meanFovImage ), 3);

            % % Improve estimates of rois which were detected based on activity
            % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
            
            fMean = nansen.twophoton.roisignals.extractF(imArray, roiArrayT);
            [fMean, roiArrayT] = flufinder.utility.removeIsNanDff(fMean, roiArrayT);

            % get images:
        %     roiImages = computeRoiImages(imArray, roiArrayT, fMean, ...
        %        'ImageType', {'Activity Weighted Mean', 'Local Correlation'});
%             roiImages = computeRoiImages(imArray, roiArrayT, fMean, ...
%                 'ImageType', 'Local Correlation');

            %roiArrayT = flufinder.module.improveRoiMasks(roiArrayT, roiImages, opts.RoiType);
            
            
            % % Detect rois from a shape-based kernel convolution
            % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
            if opts.UseShapeDetection
                fprintf('Searching for %s-shaped cells...\n', ...
                    opts.MorphologicalShape)%MorphologicalShape)
                averageImage = mean(imArray, 3);

                roiArrayS = flufinder.detect.shapeDetection(averageImage, roiArrayT, opts);
                roiArray = flufinder.utility.combineRoiArrays(roiArrayS, roiArrayT, opts);
            else
                roiArray = roiArrayT;
            end
            
            obj.RoiArray = roiArray;
            
        end

        function roiArray = getRoiArray(obj)
        %getRoiArray Get results as a roi array
            roiArray = obj.RoiArray;
        end
        
    end
    
    methods (Access = protected) % Implementation of ImageStackProcessor methods

        function onInitialization(obj)
            
            onInitialization@nansen.processing.RoiSegmentation(obj)
            
            %global fprintf; fprintf = str2func('fprintf');
            
            filePath = obj.getDataFilePath('QuickyResultsTemp', '-w',...
                'Subfolder', obj.DATA_SUBFOLDER, 'IsInternal', true);
            
            if isfile(filePath)
                obj.Results = obj.loadData('QuickyResultsTemp');
            end
            
        end

        function Y = preprocessImageData(obj, Y)
            % Subclasses may override
            % Todo: 
            % Y_ = flufinder.preprocessImages(Y, options);
            %
            %   Need to save mean of original to summary/results 

        end

        function results = segmentPartition(obj, Y)
        %segmentPartition Run segmentation on subpart of image stack  
            options = obj.ToolboxOptions; %todo...
            
            % Preprocess and binarize stack
            fprintf(sprintf('Binarizing images and detecting components...\n'))
            
            Y_ = flufinder.module.preprocessImages(Y, options);
            BW = flufinder.module.binarizeImages(Y_, options);
            
            [S, CC] = flufinder.detect.getBwComponentStats(BW, options);

            results.spatialComponents = S;
            results.meanFovImage = mean(Y, 3);
            results.meanFovImagePreprocessed = mean(Y_, 3);
            results.componentMatrix = labelmatrix(CC);          
        end
        
        function onCompletion(obj)
            onCompletion@nansen.processing.RoiSegmentation(obj)
        end
        
    end
    
    methods (Static) % Method in external file.
        options = getDefaultOptions()
        
        pathList = getDependentPaths()
    end

end