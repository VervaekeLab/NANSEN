classdef Processor < nansen.processing.RoiSegmentation & ...
                        nansen.wrapper.abstract.ToolboxWrapper
%nansen.wrapper.quicky.Processor Wrapper for running Quicky on nansen
%
%   h = nansen.wrapper.quicky.Processor(imageStackReference)
%
%   This class provides functionality for running Quicky within
%   the nansen package.

    properties (Constant, Hidden)
        DATA_SUBFOLDER = fullfile('roi_data', 'autosegmentation_quicky')
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
            
            
        end
    end
    
    methods
        
        function saveResults(obj)
           
            tempResults = obj.Results;
            obj.saveData('quickyResultsTemp', tempResults) 
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
            
            import nansen.wrapper.quicky.Options
            opts = Options.convert(obj.Options);%, stackSize);
            
                
            optionsVarname = 'quickyOptions';

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
        
        function runPreInitialization(obj)
            runPreInitialization@nansen.processing.RoiSegmentation(obj)
            
            obj.NumSteps = obj.NumSteps + 1;
            descr = 'Combining and refining detected components...';
            obj.StepDescription = [obj.StepDescription, descr];
            
        end
    end
    
    methods (Access = protected) % Run the motion correction / image registration

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
            
            filePath = obj.getDataFilePath('quickyResultsTemp', '-w',...
                'Subfolder', obj.DATA_SUBFOLDER);
            
            if isfile(filePath)
                obj.Results = obj.loadData('quickyResultsTemp');
            end
            
        end

        function onCompletion(obj)
            
            % Combine spatial segments
            if numel(obj.Results) >= 1
                obj.mergeSpatialComponents()
            end
            
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

            [roiArray, roiImages, roiStats] = nansen.wrapper.quicky.utility.finalizeRoiSegmentation(imArray, avgIm, roiArrayT);
            % Todo: save all...
            
            obj.displayFinishCurrentStep()
            
            obj.saveData('roiArrayQuickyAuto', roiArray, 'Subfolder', 'roi_data')
        end
        
    end
    
    
    methods (Static) % Method in external file.
        options = getDefaultOptions()
        
        pathList = getDependentPaths()
    end

end