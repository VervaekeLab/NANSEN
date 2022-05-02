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
        ROI_VARIABLE_NAME = 'roiArrayQuickyAuto'
    end

    properties (Constant) % Attributes inherited from nansen.DataMethod
        MethodName = 'Autosegmentation (Quicky)'
        IsManual = false        % Does method require manual supervision
        IsQueueable = true      % Can method be added to a queue
        OptionsManager nansen.manage.OptionsManager = ...
            nansen.OptionsManager('nansen.wrapper.quicky.Processor')
    end
    
    properties (Constant) % From imagestack...
        ImviewerPluginName = ''
    end
    
    properties (Access = private)
        MergedResults
        %RoiArray
        %RoiImages
        %RoiStats
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

            % Todo. Move to superclass
            obj.Options.Export.FileName = obj.SourceStack.Name;
            
            % Call the appropriate run method
            if ~nargout
                obj.runMethod()
                clear obj
            end
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
            
            import nansen.wrapper.quicky.Options
            opts = Options.convert(obj.Options);%, stackSize);
            
                
            optionsVarname = 'QuickyOptions';

            % Initialize options (Load from session if options already
            % exist, otherwise save to session)
            opts = obj.initializeOptions(opts, optionsVarname);
            
        end
        
        function runPreInitialization(obj)
            runPreInitialization@nansen.processing.RoiSegmentation(obj)
            
            obj.NumSteps = obj.NumSteps + 1;
            descr = 'Combine and refine detected components';
            obj.StepDescription = [obj.StepDescription, descr];
            
            obj.NumSteps = obj.NumSteps + 1;
            descr = 'Compute roi images & roi stats';
            obj.StepDescription = [obj.StepDescription, descr];
        end
        
        function saveResults(obj)
            tempResults = obj.Results;
            obj.saveData('QuickyResultsTemp', tempResults) 
        end
        
        function mergeResults(obj)
        %mergeResults Merge results from each processing part
            
            % Combine spatial segments
            if numel(obj.Results) >= 1
                obj.mergeSpatialComponents()
            end
        end

        function roiArray = getRoiArray(obj)
        %getRoiArray Get results as a roi array
            roiArray = obj.RoiArray;
        end
        
    end
    
    methods (Access = protected) % Implementation of ImageStackProcessor methods

        function result = segmentPartition(obj, Y)
            
            options = obj.ToolboxOptions; %todo...
            
            % Binarize stack
            fprintf(sprintf('Binarizing images...\n'))
            BW = roimanager.autosegment.binarizeStack(Y, []);
    
            % Search for candidates based on activity in the binary stack
            param = [];
            S = roimanager.autosegment.getAllComponents(BW, param);
            
            result.spatialComponents = S;
            result.meanFovImage = mean(Y, 3);
                        
        end

        function onInitialization(obj)
            
            onInitialization@nansen.processing.RoiSegmentation(obj)
            
            global fprintf; fprintf = str2func('fprintf');
            
            filePath = obj.getDataFilePath('QuickyResultsTemp', '-w',...
                'Subfolder', obj.DATA_SUBFOLDER, 'IsInternal', true);
            
            if isfile(filePath)
                obj.Results = obj.loadData('QuickyResultsTemp');
            end
            
        end

        function onCompletion(obj)
            onCompletion@nansen.processing.RoiSegmentation(obj)
        end
        
    end
    
    methods (Access = private)
        
        function mergeSpatialComponents(obj)
            
            obj.displayStartCurrentStep()

            obj.Results = cat(1, obj.Results{:});
            S = cat(1, obj.Results.spatialComponents );
                
            stackSize = [obj.SourceStack.ImageHeight, obj.SourceStack.ImageWidth];
            
            roiArrayT = roimanager.autosegment.findUniqueRoisFromComponents(stackSize(1:2), S);

            N = obj.SourceStack.chooseChunkLength();
            imArray = obj.SourceStack.getFrameSet(1:N);
            
            avgIm = mean( cat(3, obj.Results.meanFovImage ), 3);

            roiArray = nansen.wrapper.quicky.utility.finalizeRoiSegmentation(imArray, avgIm, roiArrayT);
            % Todo: save all...
            
            obj.RoiArray = roiArray;
            %obj.RoiImages = roiImages;
            %obj.RoiStats = roiStats;
            
            obj.displayFinishCurrentStep()
            
        end
        
    end

    methods (Static) % Method in external file.
        options = getDefaultOptions()
        
        pathList = getDependentPaths()
    end

end