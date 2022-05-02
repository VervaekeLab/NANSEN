classdef ImageStackProcessor < nansen.DataMethod  %& matlab.mixin.Heterogenous  
%NANSEN.STACK.IMAGESTACKPROCESSOR Super class for image stack method.
%
%   This is a super class for methods that will run on an imagestack
%   object. This class provides functionality for splitting the stack in
%   multiple parts and running the processing on each part in sequence. The
%   class is designed so that methods can be started over and skip over 
%   data that have already been process. It is also possible to rerun the 
%   method on a specified set of parts.
%
%   This class is useful for stacks which are very large and may not fit 
%   in the computer memory. 
%
%   Constructing an object of this class will not start the processing, use
%   the runMethod for this.


%   NOTES:
%       Currently, the image stacks are divided into parts along the last
%       dimension (typically Time or Z-slices). This is done for
%       performance considerations, as loading data from disk is
%       time-consuming. This is not ideal for methods which require the
%       whole data set along this dimension, and where splitting the data
%       along the x- and or y- dimension is better. Such splitting should
%       be implemented at some point. 
    
%  A feature that can be developed: Use for processing different 
%  methods on each part, similar to mapreduce... Requires:
%       - Inherit from matlab.mixin.Heterogenous
%       - A loop within runMethod to loop over an array of class objects
%       - A method to make sure the sourceStack of all objs are the same


% - - - - - - - - - - TODO - - - - - - - - - - - - - - - - - - -
%     [ ] ProcessPart should be public. How to tell which part to process
%           if method is called externally? Input iPart or iInd? Or "synch"
%           with another method?
%           - ProcessSinglePart ??
%
%     [ ] Implement edit options method? To make sure number of frames per
%         part are not set after initialization
%
%     [ ] Don't allow updating options after IsInitialized = true; Here or
%         superclasses?
%
%     [ ] IF method is resumed, use old options and prohibit editing of 
%         options.
%
%     [ ] Make option for reseting results before running. I.e when you
%         want to rerun the method and overwrite previous results
%   
%     [ ] Property with name of which stack to use. Would be good practice
%         for methods that would always work on the same stack, but not for
%         methods that works on any stack.... 
%
%     [ ] About above: Perhaps it is better if this is managed by 
%         subclasses and implementations of openSourceStack
%   
%     [ ] Preview mode where images are opened in imviewer
%
%     [ ] Save intermediate results in processParts. I.e expand so that if
%     there are additional results (not just processed imagedata), it is
%     also saved (see e.g. RoiSegmentation)
%
%     [ ] Add logging/progress messaging 
%     [v] Created print task method.
%     [v] Method for logging when method finished.
%     [ ] Output to log
%     [ ] Remove previous message when updating message in loop


% - - - - - - - - - PROPERTIES - - - - - - - - - - - - - - - - - 

    properties (SetAccess = protected) % Source and target stacks for processing
        SourceStack nansen.stack.ImageStack % The image stack to use as source
        TargetStack nansen.stack.ImageStack % The image stack to use as target (optional)
    end
    
    properties % User preferences
        IsSubProcess = false        % Flag to indicate if this is a subprocess of another process (determines display output)
        PreprocessDataOnLoad = false; % Flag for whether to activate image stack data preprocessing...
        PartsToProcess = 'all'      % Parts to processs. Manually assign to process a subset of parts
        RedoProcessedParts = false  % Flag to use if processing should be done again on already processed parts
    end
    
    properties (Access = public) % Resolve: Should these instead be methods?
        DataPreProcessFcn   = []    % Function to apply on image data after loading (works on each part)
        DataPreProcessOpts  = []    % Options to use when preprocessing image data
        DataPostProcessFcn  = []    % Function to apply on image data before saving (works on each part)
        DataPostProcessOpts = []    % Options to use when postprocessing image data
    end
    
    properties (SetAccess = private, GetAccess = protected) % Current state of processor
        CurrentPart                 % Current part that is being processed (updated during processing)
        CurrentFrameIndices         % Current indices of frames that are being processed (updated during processing)
        NumParts                    % Number of parts that image stack is split into for processing
    end
    
    properties (Dependent) % Options
        FrameInterval
        NumFramesPerPart           
    end
    
    properties (Access = protected)
        NumSteps = 1                % Number of steps for algorithm. I.e Step 1/2 = downsample stack, Step 2/2 autosegment stack
        CurrentStep = 1;            % Current step of algorithm.
        StepDescription = {}        % Description of steps (cell array of text descriptions)
        FrameIndPerPart = []        % List (cell array) of frame indices for each subpart of image stack
        IsInitialized = false;      % Boolean flag; is processor already initialized?
        IsFinished = false;         % Boolean flag; has processor completed?
    end
    
% - - - - - - - - - - METHODS - - - - - - - - - - - - - - - - - 

    methods (Static)
        function S = getDefaultOptions()
            S.Run.frameInterval = [];
            %S.Run.frameInterval_ = 'transient';
            S.Run.numFramesPerPart = 1000;            
            %S.Run.partsToProcess = 'all';
            %S.Run.redoPartIfFinished = false;
            S.Run.runOnSeparateWorker = false;
        end
    end
    
    methods (Abstract, Access = protected) % todo: make public??
        Y = processPart(obj, Y, iIndices);
    end
    
    methods % Constructor
        
        function obj = ImageStackProcessor(varargin)
                  
            if numel(varargin) == 0
                dataLocation = struct.empty;
                
            elseif numel(varargin) >= 1
                
                nvPairs = utility.getnvpairs(varargin{:});
                dataIoModel = utility.getnvparametervalue(nvPairs, 'DataIoModel');
                
                % Get datalocation from first input argument.
                if ~isempty(dataIoModel)
                    dataLocation = dataIoModel;
                elseif isa(varargin{1}, 'nansen.stack.ImageStack')
                    dataLocation = varargin{1}.FileName;
                else
                    dataLocation = varargin{1};
                end
                
            end
            
            % Call the constructor of the DataMethod parent class
            nvPairs = {};
            obj@nansen.DataMethod(dataLocation, nvPairs{:})
            
            if numel(varargin) == 0
                return
            end
            
            % Open source stack based on the first input argument.
            if ischar(varargin{1}) && isfile(varargin{1})
                obj.openSourceStack(varargin{1})
                
            elseif isa(varargin{1}, 'nansen.stack.ImageStack')
                obj.openSourceStack(varargin{1})
                
            elseif isa(varargin{1}, 'struct')
                % Todo. Subclass must implement....
            end
            
        end
        
    end

    methods 
        function numFramesPerPart = get.NumFramesPerPart(obj)
            numFramesPerPart = obj.Options.Run.numFramesPerPart;
        end
    end
    
    methods
        
        function wasSuccess = preview(obj)
        %PREVIEW Open preview of data and options for method.
        %
        %   tf = preview(obj) returns 1 (true) if preview is successfully
        %   completed, i.e user completed the options editor.
        %
        %   This method opens an imviewer plugin for the current
        %   algorithm/tool if such a plugin is available. Otherwise it
        %   opens a generic options editor to edit the options of the
        %   algorithm
                
            pluginName = obj.ImviewerPluginName;
            pluginFcn = imviewer.App.getPluginFcnFromName(pluginName);

            if ~isempty(pluginFcn)

                obj.SourceStack.DynamicCacheEnabled = 'on';
                hImviewer = imviewer(obj.SourceStack);
                hImviewer.ImageDragAndDropEnabled = false; 
                % Todo: Should this be more specific. (I add this because 
                % the extract plugin has plot objects that can be dragged, 
                % and in that case the image should not be dragged...)
                
                h = hImviewer.openPlugin(pluginFcn, obj.OptionsManager, ...
                    'RunMethodOnFinish', false, 'DataIoModel', obj);
                % Will pause here until the plugin is closed.

                wasSuccess = obj.finishPreview(h);

                hImviewer.quit()
                obj.SourceStack.DynamicCacheEnabled = 'off';
                
            else
%                 warning('NANSEN:Roisegmentation:PluginMissing', ...
%                     'Plugin for %s was not found', CLASSNAME)

                % Todo: use superclass method editOptions
                [obj.Parameters, wasAborted] = tools.editStruct(obj.Parameters);
                wasSuccess = ~wasAborted;
            end
            
        end
        
        function runInitialization(obj)
        %runInitialization Run the processor initialization stage.
            obj.initialize()
        end
        
        function runMethod(obj, skipInit)
            
            if obj.Options.Run.runOnSeparateWorker
                obj.runOnWorker()
                return
            end
            
            if nargin < 2; skipInit = false; end
            
            obj.runPreInitialization()
            
            if ~skipInit
                obj.initialize()
            end
            
            obj.processParts()
            
            obj.finish()
            
        end
        
        function runFinalization(obj)
        %runFinalization Run the processor finalization stage.
            obj.finish()
        end
        
        function runOnWorker(obj)
            
            tic
            
            jobDescription = sprintf('%s : %s', obj.MethodName, obj.SourceStack.Name);
            dependentPaths = obj.getDependentPaths();
            
            opts = obj.Options;
            opts.Run.runOnSeparateWorker = false;
            
            % Todo: should reconcile this, using a dataiomodel
            %args = {obj.SourceStack, opts};
            args = {obj.SessionObjects, opts};

            batchFcn = str2func( class(obj) );
            
            job = batch(batchFcn, 0, args, ...
                    'AutoAddClientPath',false, 'AutoAttachFiles', false, ...
                    'AdditionalPaths', dependentPaths);
            
            job.Tag = jobDescription;
            
            toc
            
        end
        
        function matchConfiguration(obj, referenceProcessor)
            obj.Options.Run.numFramesPerPart = referenceProcessor.NumFramesPerPart;
            obj.runInitialization()
        end
        
        function setCurrentPart(obj, partNumber)
            obj.CurrentPart = partNumber;
            obj.CurrentFrameIndices = obj.FrameIndPerPart{partNumber};
        end
        
        function delete(obj)
            % Todo: Delete source stack if it is opened on construction...
            
            if ~isempty(obj.TargetStack)
                delete(obj.TargetStack)
            end
        end
        
    end
    
    methods (Access = protected, Sealed) % initialize/processParts/finish
                
        function initialize(obj)
            
            % Check if SourceStack has been assigned.
            assert(~isempty(obj.SourceStack), 'SourceStack is not assigned')
            
            obj.printInitializationMessage()
            
%             if obj.IsInitialized
%                 fprintf('This method has already been initialized. Skipping...\n')
%                 return;
%             end

            obj.displayProcessingSteps()
            
            % Todo: Check if options exist from before, i.e we are resuming
            % this method on data that was already processed.
            % Also need to determine if the method should be resumed or
            % start over.
            
            obj.configureImageStackSplitting()
            
            % Todo: display message showing number of parts...

            % Run onInitialization ( Subclass may implement this method)
            obj.onInitialization()
            obj.IsInitialized = true;
            
        end
        
        function processParts(obj)
            
            obj.displayStartCurrentStep()

            IND = obj.FrameIndPerPart;
            
            % Todo: Do this here or in initialization??
            partsToProcess = obj.getPartsToProcess(IND);

            if obj.NumParts > 1 && isempty(partsToProcess)
                obj.printTask(sprintf('All parts of imagestack have already been processed for method: %s',  class(obj)))
                return
            end
            
            obj.printTask(sprintf('Running method: %s', class(obj) ) )
            obj.printSubTask(sprintf('ImageStack will be processed in %d parts', numel(partsToProcess)))

            % Loop through 
            for iPart = partsToProcess
                
                obj.printSubTask(sprintf('Processing part %d/%d', iPart, obj.NumParts))

                iIndices = IND{iPart};
                
                obj.CurrentPart = iPart;
                obj.CurrentFrameIndices = iIndices;
                
                % Load data Todo: Make method. Two photon session method?
                Y = obj.SourceStack.getFrameSet(iIndices);

                if ~isempty(obj.DataPreProcessFcn)
                    Y = obj.DataPreProcessFcn(Y, iIndices, obj.DataPreProcessOpts);
                end
                
                Y = obj.processPart(Y);
                
                if ~isempty(Y)
                    if ~isempty(obj.DataPostProcessFcn)
                        Y = obj.DataPostProcessFcn(Y, iIndices, obj.DataPostProcessOpts);
                    end
                    
                    if ~isempty(obj.TargetStack)
                        obj.TargetStack.writeFrameSet(Y, iIndices)
                    end
                end
                
            end
            
            obj.displayFinishCurrentStep()

        end
        
        function finish(obj)
            
            %if obj.IsFinished; return; end

            % Subclass may implement
            obj.onCompletion()
            
            obj.printCompletionMessage()
            %obj.IsFinished = true;
        end
        
    end
    
    methods (Access = protected) % Subroutines (Subclasses may override)
              
        function runPreInitialization(obj) % todo: protected?
        %runPreInitialization Runs before the initialization step    
            % Subclasses can override
            obj.NumSteps = 1;
            obj.StepDescription = {obj.MethodName};
        end
        
        function openSourceStack(obj, imageStackRef)
        %openSourceStack Open/assign image stack which is source
        
            if isa(imageStackRef, 'nansen.stack.ImageStack')
                obj.SourceStack = imageStackRef;
            else
                try % Can we create an ImageStack?
                    obj.SourceStack = nansen.stack.ImageStack(imageStackRef);
                catch
                    error('Input must be transferable to an ImageStack')
                end
            end
        end
        
        function openTargetStack(obj, filePath, stackSize, dataType)
        %openTargetStack Open/assign image stack which is target
        
            if ~isfile(filePath)
                obj.printTask('Creating target stack for method: %s...', class(obj))
                imageStackData = nansen.stack.open(filePath, stackSize, dataType);
            else
                imageStackData = nansen.stack.open(filePath);
            end
            
            obj.TargetStack = nansen.stack.ImageStack(imageStackData);
        end

        function tf = checkIfPartIsFinished(obj, partNumber)
            % Rename to isPartFinished?
            % Subclass may implement
            tf = false; 
        end
        
% % %         Todo: Add Results as property and use this instead
% % %         function tf = checkIfPartIsFinished(obj, partNumber)
% % %             tf = ~isempty(obj.Results{partNumber});
% % %         end
        
        function onInitialization(~)
            % Subclass may implement
        end
        
        function onCompletion(~)
            % Subclass may implement
        end
        
        function configureImageStackSplitting(obj)
        %configureImageStackSplitting Get split configuration from options
            
            % Get number of frames per part
            N = obj.Options.Run.numFramesPerPart;
            
            % Get cell array of frame indices per part (IND) and numParts
            [IND, numParts] = obj.SourceStack.getChunkedFrameIndices(N);

            % Assign to property values
            obj.FrameIndPerPart = IND;
            obj.NumParts = numParts;

            % Todo: Make sure this method is not resuming from previous
            % instance that used a different stack splitting configuration
            
            
        end
        
    end
    
        methods (Access = protected) % Pre- and processing methods for imagedata

        function Y = preprocessImageData(obj, Y)
            % Subclasses may override
        end

        function Y = postprocessImageData(obj, Y)
            % Subclasses may override
        end
    end
    
    methods (Access = private)
        
        function partsToProcess = getPartsToProcess(obj, frameInd)
        %getPartsToProcess Get list of which parts to process.
        %
        %   partsToProcess = h.getPartsToProcess(numParts, frameInd)
        %
        %   Return a list of numbers for parts to process. By default, all
        %   parts will be processed, but this can be controlled using the
        %   PartsToProcess property. Also if parts are processed from 
        %   before, they will be skipped, unless the RedoProcessedParts
        %   property is set to true
        
        % Note: frameInd might be used by subclasses(?)
       
            % Set the parts to process.
            if strcmp(obj.PartsToProcess, 'all')
                partsToProcess = 1:obj.NumParts;
            else
                partsToProcess = obj.PartsToProcess;
            end
            
            % Make sure list of parts is a numeric
            assert(isnumeric(partsToProcess), 'PartsToProcess must be numeric')
            
            % Check if any parts can be skipped
            partsToSkip = [];
            for iPart = partsToProcess
                
                % Checks if shifts already exist for this part
                isPartFinished = obj.checkIfPartIsFinished(iPart);
                                
                if isPartFinished && ~obj.RedoProcessedParts
                    partsToSkip = [partsToSkip, iPart]; %#ok<AGROW>
                end
            end

            partsToProcess = setdiff(partsToProcess, partsToSkip);
            
            if isempty(partsToProcess); return; end
            
            % Make sure list of parts is in valid range.
            msgA = 'PartsToProcess can not be smaller than the first part';
            assert( min(partsToProcess) >= 1, msgA)
            msgB = 'PartsToProcess can not be larger than the last part';
            assert( max(partsToProcess) <= obj.NumParts, msgB)

        end
        
    end
    
    methods (Access = protected) % Methods for printing commandline output
        
        function addProcessingStep(obj, description, position)
            % Placeholder / Todo
            switch position
                case 'beginning'
                    
                case 'end'
                    
            end
        end
        
        function printSubTask(obj, varargin)
            msg = sprintf(varargin{:});
            nowstr = datestr(now, 'HH:MM:ss');
            fprintf('%s (%s): %s\n', nowstr, obj.MethodName, msg)
        end
        
        function displayStartCurrentStep(obj)
        %displayStartCurrentStep Display message when current step starts    
            if obj.IsSubProcess; return; end

            i = obj.CurrentStep;
            obj.printTask('Running step %d/%d: %s...', i, obj.NumSteps, ...
                obj.StepDescription{i})
        end
        
        function displayFinishCurrentStep(obj)
        %displayFinishCurrentStep Display message when current step stops    
            
            if obj.IsSubProcess; return; end

            i = obj.CurrentStep;
            obj.printTask('Finished step %d/%d: %s.\n', i, obj.NumSteps, ...
                obj.StepDescription{i})
            obj.CurrentStep = obj.CurrentStep + 1;
        end
        
    end
    
    methods (Access = private) % Should these methods be part of a data method logger class?
        
        function printInitializationMessage(obj)
        %printInitializationMessage Display message when method starts
        
            if obj.IsSubProcess; return; end

            fprintf('\n---\n')
            obj.printTask(sprintf('Initializing method: %s', class(obj)))
            fprintf('\n')
        end
        
        function displayProcessingSteps(obj)
        %displayProcessingSteps Display the processing steps for process    
            
            if obj.IsSubProcess; return; end
            
            obj.printTask('Processing will happen in %d steps:', obj.NumSteps);
            
            for i = 1:obj.NumSteps
                 obj.printTask('Step %d/%d: %s', i, obj.NumSteps, ...
                     obj.StepDescription{i})
            end
            fprintf('\n')
        end
        
        function printCompletionMessage(obj)
        %printCompletionMessage Display message when method is completed
        
            if obj.IsSubProcess; return; end
            
            obj.printTask(sprintf('Completed method: %s', class(obj)))
            fprintf('---\n')
            fprintf('\n')
        end
        
    end
    
    
    methods (Static)
        function printTask(varargin)
            msg = sprintf(varargin{:});
            nowstr = datestr(now, 'HH:MM:ss');
            fprintf('%s: %s\n', nowstr, msg)
        end
    end
    
end 