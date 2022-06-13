classdef RoiSegmentation < nansen.stack.ImageStackProcessor
%RoiSegmentation Superclass for running roi autosegmentation on ImageStacks
%
%   This class is a template method for running autosegmentation on
%   ImageStacks. Subclasses must be based on the template for
%   ImageStackProcessor and additionally implement the following methods:
%
%         getToolboxSpecificOptions
%         segmentPartition
%         getRoiArray
    
    properties (Constant) % Attributes inherited from nansen.DataMethod
        IsManual = false        % Does method require manual supervision
        IsQueueable = true      % Can method be added to a queue
    end
    
    properties (Dependent, Access = protected)
        RoiArrayVarName
    end
    
    properties (Access = protected) % Data to keep during processing.
        ToolboxOptions  % Options that are in the format of original toolbox
        OriginalStack   % To store original ImageStack if SourceStack is downsampled
                
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
        mergeSpatialComponents(obj, planeNumber, channelNumber)
        roiArray = getRoiArray(obj)
    end
    
    methods % Constructor
        
        function obj = RoiSegmentation(varargin)
            obj@nansen.stack.ImageStackProcessor(varargin{:})
        end
        
        function varName = get.RoiArrayVarName(obj)
            varName = sprintf('roiArray%sAuto', obj.VARIABLE_PREFIX);
        end
    
    end
    
    % Methods for initialization/completion of algorithm
    methods (Access = protected) % Override ImageStackProcessor methods 
        
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
            
        end
                
        function [Y, summary] = processPart(obj, Y, ~)
        %processPart Process subpart of ImageStack
        
             Y = obj.preprocessImageData(Y);
             summary = obj.segmentPartition(Y);
        end
        
        function mergeResults(obj)
        %mergeResults Merge results from subparts of ImageStack    

            [numParts, numZ, numC] = size(obj.Results);
            
            if numParts == 1
                obj.MergedResults = reshape(obj.Results, numZ, numC);
            elseif numParts > 1
                obj.MergedResults = cell(numZ, numC);
                
                for iZ = 1:numZ
                    for iC = 1:numC
                        obj.mergeSpatialComponents(iZ, iC)
                    end
                end
            end

            variableName = sprintf('%sResultsFinal', obj.VARIABLE_PREFIX);
                
            obj.saveData(variableName, obj.MergedResults, ...
                'Subfolder', obj.DATA_SUBFOLDER, 'IsInternal', true)
        end
        
        function onCompletion(obj)
        %onCompletion Run when processor is done with all parts
           
            if ~isfile(obj.getDataFilePath(obj.RoiArrayVarName)) || obj.RedoIfCompleted
                                
                obj.finalizeResults()
                
                obj.RoiArray = obj.getRoiArray();
                
                % Get roiImages and roiStats, i.e roi application data
                obj.displayStartStep('compute_roidata')
                obj.getRoiAppData()
                obj.displayFinishStep('compute_roidata')
                
                % Assemble final results and save as a roigroup struct.
                obj.saveToRoiGroup()

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
        
        function dsFactor = getTemporalDownsamplingFactor(obj)
            dsFactor = obj.Options.Run.TemporalDownsamplingFactor;
        end
        
        function finalizeResults(obj)
            % Subclasses may override
        end

        function getRoiAppData(obj)
        %getRoiAppData Get roi application data (roiImages & roiStats)
        
            import nansen.twophoton.roi.getRoiAppData
            %obj.printTask('Computing roi images and stats')

            [numZ, numC] = size(obj.RoiArray);
            
            [obj.RoiImages, obj.RoiStats] = deal( cell(numZ, numC) );
            
            obj.StackIterator.reset()
            for i = 1:obj.StackIterator.NumIterations
                obj.StackIterator.next()
                
                iC = obj.StackIterator.CurrentIterationC;
                iZ = obj.StackIterator.CurrentIterationZ;
                
                thisRoiArray = obj.RoiArray{iZ, iC};
                imArray = obj.getImageArray();
                if ~isempty(thisRoiArray)
                    [roiImages, roiStats] = getRoiAppData(imArray, thisRoiArray);       % Imported function

                    obj.RoiImages{iZ, iC} = roiImages;
                    obj.RoiStats{iZ, iC} = roiStats;
                end
                
            end
            
            %obj.printTask('Finished roi images and stats')
            
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
        
% %             downsampledStack = obj.SourceStack.downsampleT(dsFactor, [], ...
% %                 'Verbose', true, 'UseTemporaryFile', false, ...
% %                 'SaveToFile', true);
            
            downsampler = nansen.stack.processor.TemporalDownsampler(...
                obj.SourceStack, dsFactor, [], 'Verbose', true, ...
                'UseTemporaryFile', false, 'SaveToFile', true);
            downsampler.IsSubProcess = true;
            downsampler.runMethod()
            
            downsampledStack = downsampler.getDownsampledStack();
            
            
            
            % Store original stack and assign the downsampled stack as
            % source stack. Original stack might be needed later.
            obj.OriginalStack = obj.SourceStack;
            obj.SourceStack = downsampledStack;
        end
        
        function saveToRoiGroup(obj)
            
            [numZ, numC] = size(obj.RoiArray);
            
            roiGroupCellArrayOfStruct = cell(numZ, numC);

            obj.StackIterator.reset()
            for i = 1:obj.StackIterator.NumIterations
                [iZ, iC] = obj.StackIterator.next();

                roiGroupStruct = struct();
                roiGroupStruct.ChannelNum = obj.StackIterator.CurrentChannel;
                roiGroupStruct.PlaneNum = obj.StackIterator.CurrentPlane;

                roiGroupStruct.roiArray = obj.RoiArray{iZ,iC};
                roiGroupStruct.roiImages = obj.RoiImages{iZ,iC};
                roiGroupStruct.roiStats = obj.RoiStats{iZ,iC};
                roiGroupStruct.roiClassification = zeros(numel(obj.RoiArray{iZ,iC}), 1);

                roiGroupCellArrayOfStruct{iZ, iC} = roiGroupStruct;
            end

            roiGroupStruct = cell2mat(roiGroupCellArrayOfStruct);

            % Save as roigroup.
            obj.saveData(obj.RoiArrayVarName, roiGroupStruct, ...
                'Subfolder', 'roi_data', 'FileAdapter', 'RoiGroup')
            
        end
    end
    
    methods (Static)
        
        function S = getDefaultOptions()
            S = struct();
            S.Run.TemporalDownsamplingFactor = 10; % 1 = no downsampling...
            S.Run.SpatialDownsamplingFactor = 1;
            
            % S.SpatialPartitioning
            % S.TemporalPartitioning
            
        end

    end

end