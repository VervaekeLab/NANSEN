classdef RoiSegmentation < nansen.stack.ImageStackProcessor
%RoiSegmentation Superclass for running roi autosegmentation on ImageStacks
%
%   This class is a template method for running autosegmentation on
%   ImageStacks. Subclasses must implement the required properties and
%   methods for the ImageStackProcessor superclass and additionally
%   implement the following methods:
%
%         getToolboxSpecificOptions : Should returns options that are
%                                     specific to the toolbox in question.
%
%         segmentPartition          : Should take care of segmentation
%                                     of an image chunk/partition.
%
%         mergeSpatialComponents    : Should merge the spatial components
%                                     across temporal chunks/partitions
%
%         getRoiArray               : Should collect results as a RoI array

%   Todo:
%       [ ] rename getRoiArray to collect/gather roi array (Q)
%       [ ] should initializeOptions be an ImageStackProcessor method?
%       [ ] add instructions on merging of results.
%       [ ] merge spatial components should be identical to segment
%           partition, i.e it should not be necessary to specify channel
%           or plane.
%       [ ] Move originalStack and associated methods to the
%           ImageStackProcessor (Q)

% NOTE FOR SELF ON IMPLEMENTATION:
%
%   This class should take care of all looping across channels/planes
%
%       Provide methods that subclasses can implement:
%       i.e
%           - merge results
%           - merge spatial components (different from merge results)
%           - refine spatial components
%
%       - The existDownsampledStack will replace the source stack with a
%         downsampled version if a downsampled version exists already.
%         This is convenient, but not very transparent

    properties (Constant) % Attributes inherited from nansen.processing.DataMethod
        IsManual = false        % Does method require manual supervision?
        IsQueueable = true      % Can method be added to a queue?
    end
    
    properties (Dependent, Access = protected)
        RoiArrayVarName  % Variable name used for roi array of specific autosegmentation method
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

    % Abstract methods for subclasses to implement
    methods (Abstract, Access = protected)
        S = getToolboxSpecificOptions(obj)
        results = segmentPartition(obj, y)
        mergeSpatialComponents(obj, planeNumber, channelNumber)
        roiArray = getRoiArray(obj)
    end

    % Constructor
    methods
        
        function obj = RoiSegmentation(varargin)
        %RoiSegmentation Create instance of RoiSegmentation processor
        %
        %   This constructor passes all input arguments up to the
        %   ImageStackProcessor superclass.
        %
        %   See also nansen.stack.ImageStackProcessor

            obj@nansen.stack.ImageStackProcessor(varargin{:})
        end
        
        function varName = get.RoiArrayVarName(obj)
            varName = sprintf('roiArray%sAuto', obj.VARIABLE_PREFIX);
        end
    end
    
    % Methods for initialization/completion of algorithm
    methods (Access = protected) % Extend ImageStackProcessor methods
        
        function runPreInitialization(obj)
        %onPreInitialization Method that runs before the initialization step
        %
        %   This adds the substeps that will need to run to the list of
        %   substeps for the method.
            
            % Reset source stack if method is re-initialized. For a
            % method that has run before, the source stack might be a
            % downsampled version, so a reset is necessary.
            if obj.IsInitialized
                obj.resetSourceStack()
                obj.RequireDownsampleStack = false; % Reset flag
            end

            % Call the superclass method
            runPreInitialization@nansen.stack.ImageStackProcessor(obj)
            
            % Add roisegmentation specific steps
            descr = 'Combine and refine detected components';
            obj.addStep('merge_results', descr)
                       
            descr = 'Compute roi images & roi stats';
            obj.addStep('compute_roidata', descr)
            
            % Check if stack should be downsampled.
            dsFactor = obj.getTemporalDownsamplingFactor();
            if dsFactor > 1 && ~obj.existDownsampledStack(dsFactor)
                obj.RequireDownsampleStack = true;
                obj.addStep('downsample', 'Downsample stack in time', 'beginning')
            else
                % No downsampling required
            end
        end
        
        function onInitialization(obj)
        %onInitialization Runs when data method is initialized
            
            obj.ToolboxOptions = obj.getToolboxSpecificOptions();

            % Get downsampled stack if required
            if obj.RequireDownsampleStack
                dsFactor = obj.getTemporalDownsamplingFactor();

                obj.displayStartStep('downsample')
                obj.downsampleStack(dsFactor)
                obj.displayFinishStep('downsample')
                
                % Redo the splitting
                obj.configureImageStackSplitting()
            end
        end
                
        function [Y, summary] = processPart(obj, Y, ~)
        %processPart Process subpart of ImageStack
        %
        %   Input:
        %       Y : A 3D array of images (height x width x numFrames)
        
             Y = obj.preprocessImageData(Y);
             summary = obj.segmentPartition(Y);
        end
        
        function mergeResults(obj)
        %mergeResults Merge results from subparts of ImageStack

            [numParts, numZ, numC] = size(obj.Results);
            
            obj.RoiArray = cell(numZ, numC);

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
            
            roiArrayFilepath = obj.getDataFilePath(obj.RoiArrayVarName);
            
            if ~isfile( roiArrayFilepath ) || obj.RedoIfCompleted
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
        
        function configureImageStackSplitting(obj)
        %configureImageStackSplitting Get split configuration from options
        %
        %   Redefine method for ImageStackProcessor. For Roi Segmentation
        %   it is important that chunks are as long as possible, so we
        %   equalize the chunk size to make sure there is not one small
        %   part at the end.
        
            % Get number of frames per part
            N = obj.NumFramesPerPart;

            % If there will be more than one chunk, adjust so that all
            % chunks will be approximately the same size.
            numParts = ceil( obj.SourceStack.NumTimepoints / N );
            remainder = mod( obj.SourceStack.NumTimepoints , N  );
            
            if remainder/N < 1/3
                numParts = numParts - 1;
            end

            N = ceil( obj.SourceStack.NumTimepoints / numParts );
            obj.NumFramesPerPart = N;
        end

        % Todo: Should this be an ImageStackProcessor method?
        function opts = initializeOptions(obj, opts, optionsVarname)
        % Get filepath for saving options file to session folder
            
            if nargin < 3 || isempty(optionsVarname)
                optionsVarname = obj.getVariableName('Options');
            end
            
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
        %
        %   This method creates roi images and roi stats for each channel
        %   and plane of the image stack. The getImageArray used here will
        %   dynamically load a set of images based on the available memory.
        %   Therefore, for very long stacks, the images and stats might not
        %   be created based on the full stack.
        
            import nansen.twophoton.roi.getRoiAppData

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
                    [roiImages, roiStats] = getRoiAppData(imArray, thisRoiArray); % Imported function

                    obj.RoiImages{iZ, iC} = roiImages;
                    obj.RoiStats{iZ, iC} = roiStats;
                end
            end
        end
    end
    
    methods (Access = private)
        
        function tf = existDownsampledStack(obj, dsFactor)
        %existDownsampledStack Check if downsampled stack already exists
        %
        %   Inputs:
        %       dsFactor : Integer describing the downsampling factor.
        %
        %   Note. This method will replace the source stack with a
        %         downsampled version if a downsampled version exists
        %         already. This is convenient, but not very transparent.

            tf = false; % Assume it does not exist
            
            [existFile, filePath] = obj.SourceStack.hasDownsampledStack('temporal_mean', dsFactor);
            
            if existFile
                isStackComplete = nansen.stack.ImageStack.isStackComplete(filePath);
                
                if isStackComplete
                    fprintf('Downsampled stack already exists. Skipping downsampling...\n')
                    downsampledStack = nansen.stack.ImageStack(filePath);
                    obj.replaceSourceStackWithDownsampledStack(downsampledStack)
                    tf = true;
                else
                    % Assumption holds
                end
            else
                % Assumption holds
            end
        end

        function resetSourceStack(obj)
        %resetSourceStack Reset source stack if original stack is present
            if ~isempty(obj.OriginalStack)
                obj.SourceStack = obj.OriginalStack;
            end
        end
        
        function downsampleStack(obj, dsFactor)
        %downsampleStack Downsample stack in the time dimension
        %
        %   Inputs:
        %       dsFactor : Integer describing the downsampling factor.
        
            downsampler = nansen.stack.processor.TemporalDownsampler(...
                obj.SourceStack, dsFactor, [], 'Verbose', true, ...
                'UseTemporaryFile', false, 'SaveToFile', true);
            
            downsampler.IsSubProcess = true; % Improves logging
            downsampler.runMethod()
            
            downsampledStack = downsampler.getDownsampledStack();
            
            obj.replaceSourceStackWithDownsampledStack(downsampledStack)
        end

        function replaceSourceStackWithDownsampledStack(obj, downsampledStack)
        %replaceSourceStackWithDownsampledStack Replace source stack

            % Store original stack and assign the downsampled stack as
            % source stack. Original stack might be needed later so it is kept.
            obj.OriginalStack = obj.SourceStack;
            obj.SourceStack = downsampledStack;
        end
        
        function saveToRoiGroup(obj)
        %saveToRoiGroup Save results to a roi group struct

            [numZ, numC] = size(obj.RoiArray);
            
            roiGroupCellArrayOfStruct = cell(numZ, numC);

            obj.StackIterator.reset()
            for i = 1:obj.StackIterator.NumIterations
                [iZ, iC] = obj.StackIterator.next();

                roiGroupStruct = struct();
                roiGroupStruct.ChannelNumber = obj.StackIterator.CurrentChannel;
                roiGroupStruct.PlaneNumber = obj.StackIterator.CurrentPlane;

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
