classdef RoiSegmentation < nansen.stack.ImageStackProcessor
%RoiSegmentation Superclass for running roi autosegmentation on ImageStacks

    % Todo: 
    %   [ ] Multichannel support
    
    
    properties (Abstract, Constant, Hidden) % Todo: move to DataMethod
        DATA_SUBFOLDER  % Name of subfolder(s) where to save results by default
        ROI_VARIABLE_NAME
    end
    
    properties (Access = protected) % Data to keep during processing.
        ToolboxOptions  % Options that are in the format of original toolbox
        OriginalStack   % To store original ImageStack if SourceStack is downsampled
        Results         % Cell array to store temporary results (from each subpart)
        
        RoiArray
        RoiImages
        RoiStats
    end
    
    properties (Access = private)
        RequireDownsampleStack = false; % Flag for whether to downsample sourcestack
    end
    
    methods (Abstract, Access = protected)
        S = getToolboxSpecificOptions(obj)
        results = segmentPartition(obj, y)
        roiArray = getRoiArray(obj)
    end
    
    methods % Constructor
        
        function obj = RoiSegmentation(varargin)
            obj@nansen.stack.ImageStackProcessor(varargin{:})
        end
    
    end
    
    % Methods for initialization/completion of algorithm
    methods (Access = protected) % Override ImageStackProcessor methods 
        
        function tf = checkIfPartIsFinished(obj, partNumber)
        %checkIfPartIsFinished Check if intermediate results exist for part
                    
            msg = 'Number of parts is not matched';
            assert(obj.NumParts == numel(obj.Results), msg)
            
            tf = ~isempty(obj.Results{partNumber});
        end

        function runPreInitialization(obj)
        %onPreInitialization Method that runs before the initialization step    
            
            % Determine how many steps are required for the method
            
            obj.NumSteps = 1;
            obj.StepDescription = {obj.MethodName};
            
            % 1) Check if stack should be downsampled.
            dsFactor = obj.getTemporalDownsamplingFactor();
            
            if dsFactor > 1
                % Todo: more specific....:
% %                 [tf, filePath] = obj.SourceStack.hasDownsampledStack('temporal_mean', dsFactor);
% %                 if ~tf
% %                     tf = nansen.stack.ImageStack.isStackComplete(filePath);
% %                     if ~tf
                        obj.RequireDownsampleStack = true;
                        obj.NumSteps = obj.NumSteps + 1;
                        descr = 'Downsample stack in time';
                        obj.StepDescription = [descr, obj.StepDescription];
% %                     end
% %                 end
            end
            
        end
        
        function onInitialization(obj)
        %onInitialization Runs when data method is initialized
            
            obj.ToolboxOptions = obj.getToolboxSpecificOptions();

             % Reset source stack if method is re-initialized
            if obj.IsInitialized
                if ~isempty(obj.OriginalStack)
                    obj.SourceStack = obj.OriginalStack;
                end
            end

            % Get downsampled stack if required
            dsFactor = obj.getTemporalDownsamplingFactor();
            if dsFactor > 1
                
                obj.displayStartCurrentStep()
                downsampledStack = obj.SourceStack.downsampleT(dsFactor, [], ...
                    'Verbose', true, 'UseTransientVirtualStack', false);
            
                obj.OriginalStack = obj.SourceStack;
                obj.SourceStack = downsampledStack;
                obj.displayFinishCurrentStep()
                
                % Redo the splitting
                obj.configureImageStackSplitting()

            end
            
            % Initialize results.
            obj.Results = cell(obj.NumParts, 1);

        end
                
        function Y = processPart(obj, Y, ~)
            
             Y = obj.preprocessImageData(Y);
            
             output = obj.segmentPartition(Y);
             
             obj.Results{obj.CurrentPart} = output;
             obj.saveResults()
             
        end
        
        function onCompletion(obj)
        %onCompletion Run when processor is done with all parts
           
            if ~isfile(obj.getDataFilePath(obj.ROI_VARIABLE_NAME))
                obj.mergeResults()
                                
                roiArray = obj.getRoiArray();
                
                % Todo: Get roiImages and roiStats
                obj.collectRoiData()

                obj.saveData(obj.ROI_VARIABLE_NAME, roiArray, ...
                    'Subfolder', 'roi_data', 'FileAdapter', 'RoiGroup')
                
                % Todo: Save as roigroup:

            end
        end
        
    end

    methods (Access = protected) % Methods specific for roi segmentation
        
        % Todo: Should this be an ImageStackProcessor method?
        function opts = initializeOptions(obj, opts, optionsVarname)
        % Get filepath for saving options file to session folder
            filePath = obj.getDataFilePath(optionsVarname, '-w', ...
                'Subfolder', obj.DATA_SUBFOLDER, 'IsInternal', true);
            
            % And check whether it already exists on file...
            if isfile(filePath)
                optsOld = obj.loadData(optionsVarname);
                
                % Todo: make this conditional, e.g if redoing aligning, we
                % want to overwrite options...
                
                % If correction is resumed with different options
                if ~isequal(opts, optsOld)
                    warnMsg = ['options already exist for ', ...
                      'this session, but they are different from the ', ...
                      'current options. Existing options will be used.'];
                    warning('%s %s', warnMsg,  class(obj) )
                    opts = optsOld;
                end
                
            else % Save to file if it does not already exist
                % Save options to session folder
                obj.saveData(optionsVarname, opts, ...
                    'Subfolder', obj.DATA_SUBFOLDER)
            end
            
        end
        
        function saveResults(obj)
            % Subclasses may override
        end
        
        function mergeResults(obj)
            % Subclasses may override
        end
        
        function dsFactor = getTemporalDownsamplingFactor(obj)
            dsFactor = obj.Options.TemporalDownsamplingFactor;
        end
        
        function collectRoiData(obj)
            
            roiArray = obj.getRoiArray();
            
            N = obj.SourceStack.chooseChunkLength();
            imArray = obj.SourceStack.getFrameSet(1:N);
                    
            signalOpts = struct('createNeuropilMask', true);
            signalArray = nansen.twophoton.roisignals.extractF(imArray, roiArray, signalOpts);
            dff = nansen.twophoton.roisignals.computeDff(signalArray);
        
            imageTypes = {'Activity Weighted Mean', 'Diff Surround', 'Top 99th Percentile', 'Local Correlation'};
            roiImages = computeRoiImages(imArray, roiArray, dff', 'ImageType', imageTypes);
            
            obj.roiImages = roiImages;
            
            
            
            
            
            
        end
    end
    
    methods (Static)
        
        function S = getDefaultOptions()
            S = struct.empty;
            
% % %             S.TemporalDownsampling = true; % needed?
% % %             S.TemporalDownsamplingFactor = 10; % 1 = no downsampling...
% % %             S.SpatialDownsamplingFactor = 1;
% % %             
% % %             % S.SpatialPartitioning
% % %             % S.TemporalPartitioning
            
        end

    end

end