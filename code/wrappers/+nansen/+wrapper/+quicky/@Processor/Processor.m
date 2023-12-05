classdef Processor < nansen.processing.RoiSegmentation & ...
                        nansen.wrapper.abstract.ToolboxWrapper
%nansen.wrapper.quicky.Processor Wrapper for running Quicky within nansen
%
%   h = nansen.wrapper.quicky.Processor(imageStackReference) runs quicky
%       on the ImageStack referred to by the imageStackReference. Valid
%       references are an ImageStack object or a filepath to a file that 
%       can be opened as an ImageStack object.
%
%   h = nansen.wrapper.quicky.Processor(__, options) additionally
%       specifies the options to use for the processor.
%
%   To get the default options:
%       defOptions = nansen.wrapper.quicky.Processor.getDefaultOptions()
%
%   For additional optional parameters that can be used for configuring the 
%   processor;
%   See also nansen.stack.ImageStackProcessor


%   This class creates the following data variables:
%
%     * <strong>QuickyOptions</strong> : Struct with options used.
%
%     * <strong>QuickyResultsTemp</strong> : Cell array of struct. One struct for each chunk of imagestack. 
%           Struct contains output from Quicky
%
%     * <strong>roiArrayQuickyAuto</strong> :

% Todo: delegate saving of results to superclasses, and have relevant
% superclass check if results already exists.


    properties (Constant, Hidden)
        DATA_SUBFOLDER = fullfile('roi_data', 'autosegmentation_quicky')
        ROI_VARIABLE_NAME = 'roiArrayQuickyAuto' %roiArrayFlufinderAuto
        VARIABLE_PREFIX = 'Quicky' %'FluFinder'
    end

    properties (Constant) % Attributes inherited from nansen.processing.DataMethod
        MethodName = 'Quicky (Autosegmentation)'
        OptionsManager nansen.manage.OptionsManager = ...
            nansen.OptionsManager('nansen.wrapper.quicky.Processor')
    end
    
    properties (Constant) % Implement property from ImageStackProcessor
        ImviewerPluginName = 'FluFinder'
    end
    
    
    methods % Constructor
        
        function obj = Processor(varargin)
        %nansen.wrapper.quicky.Processor Construct quicky processor
        %
        %   h = nansen.wrapper.quicky.Processor(imageStackReference)
        %
        %   See also nansen.stack.ImageStackProcessor/ImageStackProcessor

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
        
    methods (Access = protected) % Implementation of ImageStackProcessor methods
        
        % Step 1
        function onInitialization(obj)
            
            onInitialization@nansen.processing.RoiSegmentation(obj)
            
            %global fprintf; fprintf = str2func('fprintf');
            
            filePath = obj.getDataFilePath('QuickyResultsTemp', '-w',...
                'Subfolder', obj.DATA_SUBFOLDER, 'IsInternal', true);
            
            if isfile(filePath)
                obj.Results = obj.loadData('QuickyResultsTemp');
            end
        end

        % Step 2
        function Y = preprocessImageData(obj, Y)
            % Subclasses may override
            % Todo: 
            % Y_ = flufinder.preprocessImages(Y, options);
            %
            %   Need to save mean of original to summary/results 
        end

        % Step 3
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
            
            if isempty(obj.MergedResults)
                obj.mergeResults()
            end
        end
        
    end
    
    methods (Access = protected) % Implementation of RoiSegmentation methods
        
        function opts = getToolboxSpecificOptions(obj, varargin)
        %getToolboxSpecificOptions Get options from parameters or file
        %
        %   OPTS = getToolboxSpecificOptions(OBJ) return a
        %   struct of parameters for the quicky algorithm.

            import nansen.wrapper.quicky.Options
            opts = Options.convert(obj.Options);
            
            optionsVarname = 'QuickyOptions';

            % Initialize options (Load from data folder if options already
            % exist, otherwise initialize and save to data folder)
            opts = obj.initializeOptions(opts, optionsVarname);
        end
        
        function saveResults(obj)
            tempResults = obj.Results;
            obj.saveData('QuickyResultsTemp', tempResults) 
        end
        
        function mergeSpatialComponents(obj, iPlane, iChannel)
            
            import flufinder.detect.findUniqueRoisFromComponents

            tmpMergedResults = cat(1, obj.Results{:, iPlane, iChannel});
            obj.MergedResults{iPlane, iChannel} = tmpMergedResults;
        end

% %         function mergeResults(obj, iPlane, iChannel)
% %         %mergeResults Merge results from each processing part
% %                     
% %             import flufinder.detect.findUniqueRoisFromComponents
% %             
% %             obj.displayStartCurrentStep()
% % 
% %             % Combine spatial segments
% %             obj.Results = cat(1, obj.Results{:});
% %             S = cat(1, obj.Results.spatialComponents );
% %                 
% %             imageSize = obj.SourceStack.FrameSize;
% %             roiArrayT = findUniqueRoisFromComponents(imageSize, S);         % imported function
% % 
% %             obj.RoiArray = roiArrayT;
% %             
% %             obj.displayFinishCurrentStep()
% %         end
        
        function finalizeResults(obj)
        %finalizeResults Finalize the results using flufinder's pipeline
            import nansen.twophoton.roi.compute.computeRoiImages
            import flufinder.detect.findUniqueRoisFromComponents

            if isempty(obj.MergedResults)
                obj.mergeResults()
            end

            [numZ, numC] = size(obj.MergedResults);
            
            obj.RoiArray = cell(numZ, numC);

            opts = obj.ToolboxOptions;
             
            obj.StackIterator.reset()
            for i = 1:obj.StackIterator.NumIterations
                [iZ, iC] = obj.StackIterator.next();
                
                tmpMergedResults = obj.MergedResults{iZ, iC};
                
                S = cat(1, tmpMergedResults.spatialComponents );
                if isempty(S)
                    obj.RoiArray{iZ, iC} = RoI.empty;
                    continue
                end

                imageSize = obj.SourceStack.FrameSize;
                roiArrayT = findUniqueRoisFromComponents(imageSize, S);         % imported function

                imArray = obj.getImageArray();

                fMean = nansen.twophoton.roisignals.extractF(imArray, roiArrayT);
                [fMean, roiArrayT] = flufinder.utility.removeIsNanDff(fMean, roiArrayT);


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
                
                obj.RoiArray{iZ, iC} = roiArray;
            end
        end

        function roiArray = getRoiArray(obj)
        %getRoiArray Get results as a roi array
            roiArray = obj.RoiArray;
        end
        
    end
    

    methods (Static) % Method in external file.
        options = getDefaultOptions()
        
        pathList = getDependentPaths()
    end

end