classdef RoiSegmentation < nansen.stack.ImageStackProcessor
%RoiSegmentation Superclass for running roi autosegmentation on ImageStacks

    % Todo: 
    %   [ ] Multichannel support
    
    
% %     properties (Abstract, Constant, Hidden) % Todo: move to DataMethod
% %         DATA_SUBFOLDER  % Name of subfolder(s) where to save results by default
% %         ROI_VARIABLE_NAME
% %     end
    
    properties (Access = protected) % Data to keep during processing.
        ToolboxOptions  % Options that are in the format of original toolbox
        OriginalStack   % To store original ImageStack if SourceStack is downsampled
        Results         % Cell array to store temporary results (from each subpart)
                
        RoiArray        % Store roi array
        RoiImages       % Store roi images
        RoiStats        % Store roi stats
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
            
            if obj.RedoIfCompleted
                tf = false;
            else
                tf = ~isempty(obj.Results{partNumber});
            end

        end

        function runPreInitialization(obj)
        %onPreInitialization Method that runs before the initialization step    
            
            % Determine how many steps are required for the method
            runPreInitialization@nansen.stack.ImageStackProcessor(obj)
            
            descr = 'Combine and refine detected components';
            obj.addStep('merge_results', descr)
                       
            descr = 'Compute roi images & roi stats';
            obj.addStep('compute_roidata', descr)
            
            
            % 1) Check if stack should be downsampled.
            dsFactor = obj.getTemporalDownsamplingFactor();
            
            if dsFactor > 1
                % Todo: more specific....:
% %                 [tf, filePath] = obj.SourceStack.hasDownsampledStack('temporal_mean', dsFactor);
% %                 if ~tf
% %                     tf = nansen.stack.ImageStack.isStackComplete(filePath);
% %                     if ~tf
                        obj.RequireDownsampleStack = true;
                        obj.addStep('downsample', 'Downsample stack in time', 'beginning')
% %                     end
% %                 end
            end
            
        end
        
        function onInitialization(obj)
        %onInitialization Runs when data method is initialized
            
            obj.ToolboxOptions = obj.getToolboxSpecificOptions();

             % Reset source stack if method is re-initialized
            if obj.IsInitialized
                obj.resetSourceStack()
            end

            % Get downsampled stack if required
            dsFactor = obj.getTemporalDownsamplingFactor();
            if dsFactor > 1
                
                obj.displayStartStep('downsample')
                obj.downsampleStack(dsFactor)
                obj.displayFinishStep('downsample')
                
                % Redo the splitting
                obj.configureImageStackSplitting()
            end
            
            % Initialize cell array for results.
            obj.Results = cell(obj.NumParts, 1);
        end
                
        function [Y, summary] = processPart(obj, Y, ~)
            
             Y = obj.preprocessImageData(Y);
            
             output = obj.segmentPartition(Y);
             
             obj.Results{obj.CurrentPart} = output;
             obj.saveResults()
             
        end
        
        function onCompletion(obj)
        %onCompletion Run when processor is done with all parts
           
            if ~isfile(obj.getDataFilePath(obj.ROI_VARIABLE_NAME)) || obj.RedoIfCompleted
                
                obj.mergeResults()
                
                obj.finalizeResults()
                
                obj.RoiArray = obj.getRoiArray();
                
                % Get roiImages and roiStats, i.e roi application data
                obj.displayStartStep('compute_roidata')
                obj.getRoiAppData()
                obj.displayFinishStep('compute_roidata')
                
                % Assemble final results in a roigroup struct.
                roiGroupStruct = struct();
                roiGroupStruct.roiArray = obj.RoiArray;
                roiGroupStruct.roiImages = obj.RoiImages;
                roiGroupStruct.roiStats = obj.RoiStats;
                roiGroupStruct.roiClassification = zeros(numel(obj.RoiArray), 1);
                
                % Save as roigroup.
                obj.saveData(obj.ROI_VARIABLE_NAME, roiGroupStruct, ...
                    'Subfolder', 'roi_data', 'FileAdapter', 'RoiGroup')

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
            if isfile(filePath) && ~obj.RedoIfCompleted
                optsOld = obj.loadData(optionsVarname);
                
                % Todo: make this conditional, e.g if redoing processing, we
                % want to overwrite options...
                
                % If correction is resumed with different options
                if ~isequal(opts, optsOld)
                    warnMsg = ['This method has already been initialized ', ...
                        'before, but with different options. Please use ', ...
                        'the same options as before, or rerun the method ', ...
                        'with new options. Aborting...'];
                    error('%s %s', warnMsg,  class(obj) )
                    %opts = optsOld;
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
        
        function finalizeResults(obj)
            % Subclasses may override
        end
                
        function dsFactor = getTemporalDownsamplingFactor(obj)
            dsFactor = obj.Options.TemporalDownsamplingFactor;
        end
        
        function getRoiAppData(obj)
        %getRoiAppData Get roi application data (roiImages & roiStats)
        
            import nansen.twophoton.roi.getRoiAppData
        
            roiArray = obj.RoiArray;
            imArray = obj.getImageArray();
            
            obj.printTask('Computing roi images and stats')
            [roiImages, roiStats] = getRoiAppData(imArray, roiArray);       % Imported function
            obj.RoiImages = roiImages;
            obj.RoiStats = roiStats;
            obj.printTask('Finished roi images and stats')
            
        end
    end
    
    methods (Access = private)
        
        function resetSourceStack(obj)
        %resetSourceStack Reset source stack if original stack is present    
            if ~isempty(obj.OriginalStack)
                obj.SourceStack = obj.OriginalStack;
            end
        end
        
        function downsampleStack(obj, dsFactor)
        %downsampleStack Downsample stack in the time dimension
        
            downsampledStack = obj.SourceStack.downsampleT(dsFactor, [], ...
                'Verbose', true, 'UseTransientVirtualStack', false, ...
                'SaveToFile', true);
            
            % Store original stack and assign the downsampled stack as
            % source stack. Original stack might be needed later.
            obj.OriginalStack = obj.SourceStack;
            obj.SourceStack = downsampledStack;
        end
        
    end
    
    methods (Static)
        
        function S = getDefaultOptions()
            S = struct();
            S.TemporalDownsamplingFactor = 10; % 1 = no downsampling...
            S.SpatialDownsamplingFactor = 1;
            
            % S.SpatialPartitioning
            % S.TemporalPartitioning
            
        end

    end

end