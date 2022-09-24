classdef Processor < nansen.processing.MotionCorrection & ...
                        nansen.wrapper.abstract.ToolboxWrapper
%nansen.wrapper.normcorre.Processor Wrapper for running normcorre on nansen
%
%   h = nansen.wrapper.normcorre.Processor(imageStackReference)
%
%   This class provides functionality for running normcorre within
%   the nansen package.
%
%   Additional functionality:
%       - Stop registration and resume at later time
%       - Interactive configuration of parameters
%       - Save reference images

%
%   This class creates the following data variables:
%
%     * <strong>NormcorreOptions</strong> : Struct with options used for registration
%
%     * <strong>NormcorreShifts</strong> : Struct array with frame shifts 


%   TODO:
%       [ ] Print command line output
%       [ ] Improve initialization of template or leave it to normcorre...
%       [ ] Option for using precalculated template. 
%       [ ] Move shifts to results property of ImageStackProcessor


    properties (Constant) % Attributes inherited from nansen.DataMethod
        MethodName = 'Motion Correction (NoRMCorre)'
        OptionsManager nansen.manage.OptionsManager = ...
            nansen.OptionsManager('nansen.wrapper.normcorre.Processor')
    end
    
    properties (Constant, Hidden)
        DATA_SUBFOLDER = 'motion_corrected'; % Name of subfolder(s) where to save results by default
        VARIABLE_PREFIX = 'Normcorre';
    end
    
    properties (Constant) % From motion correction
        ImviewerPluginName = 'NoRMCorre'
    end
    
    properties %(Dependent)
        ChannelToCorrect = 2 % todo: rename to ReferenceChannel and
        %update imageStackIterator when this value is set.
    end
    
% % %     properties (Constant, Access = protected)
% % %         DependentPaths = nansen.wrapper.normcorre.getDependentPaths()
% % %     end
    
    
    methods % Constructor 
        
        function obj = Processor(varargin)
        %nansen.wrapper.normcorre.Processor Construct normcorre processor
        %
        %   h = nansen.wrapper.normcorre.Processor(imageStackReference)
            
            obj@nansen.processing.MotionCorrection(varargin{:})
            
            % Return if there are no inputs.
            if numel(varargin) == 0
                return
            end
            
            % Todo: Make sure channel processing mode is serial or single
            % (no batch method available for normcorre.)
            
            % Call the appropriate run method
            if ~nargout
                obj.runMethod()
                clear obj
            end
            
        end
        
    end
    
    methods % Set/get
        function set.ChannelToCorrect(obj, value)
            obj.ChannelToCorrect = value;
            % Todo:
            %obj.Options.Run.PrimaryChannel = value;
            %obj.StackIterator.PrimaryChannel = value;
        end
    end
    
    methods (Access = protected) % Implementation of abstract, public methods
        
        function normcorreOpts = getToolboxSpecificOptions(obj, varargin)
        %getToolboxSpecificOptions Get normcorre options from parameters or file
        %
        %   normcorreOpts = getToolboxSpecificOptions(obj, stackSize) return a
        %   struct of parameters for the normcorre pipeline. The options
        %   are created based on the user's selection of parameters that
        %   are given to this instance of the SessionMethod/normcorre
        %   class. If normcorre options already exist on file for this
        %   session, those options are selected.
        %
        %   Note: stackSize must be given as input.
        %
        %   Todo: Need to adapt to aligning on multiple channels/planes.
            % validate/assert that arg is good
            stackSize = varargin{1};
            
            import nansen.wrapper.normcorre.Options
            opts = Options.convert(obj.Options, stackSize);
            
            optionsVarname = 'NormcorreOptions';

            % Turn of correct_bidir, since this is controlled by the
            % MotionCorrection method
            opts.correct_bidir = false;

            % Initialize options (Load from session if options already
            % exist, otherwise save to session)
            normcorreOpts = obj.initializeOptions(opts, optionsVarname);
            
        end
        
        
        function tf = checkIfPartIsFinished(obj, partNumber)
        %checkIfPartIsFinished Check if shift values exist for given part
            
            if obj.CurrentChannel == obj.ChannelToCorrect
                shifts = obj.ShiftsArray{obj.CurrentPlane};
                IND = obj.FrameIndPerPart{partNumber};
                tf = all( arrayfun(@(i) ~isempty(shifts(i).shifts), IND) );
            else
                im = obj.DerivedStacks.AvgProjectionStackCorr.getFrameSet(partNumber);
                tf = any(im(:) ~= 0);
            end
            
        end
        
        function initializeShifts(obj, numFrames)
        %initializeShifts Load or initialize shifts...
        
        % Note: shifts is a cell array of numChannels x numPlanes where
        % each cell contains the struct array of shifts from normcorre
        
            % Get filepath (initialize if it does not exist)
            filePath = obj.getDataFilePath('NormcorreShifts', '-w', ...
                'Subfolder', obj.DATA_SUBFOLDER, 'IsInternal', true);
            
            if isfile(filePath)
                S = obj.loadData('NormcorreShifts');
                if ~isa(S, 'cell'); S = {S}; end
            else
                % Initialize blank struct array
                C = cell(numFrames, 1);
                S = struct('shifts', C, 'shifts_up', C, 'diff', C);
                S = obj.repeatStructPerDimension(S);
                
                obj.saveData('NormcorreShifts', S)
            end
            
            obj.ShiftsArray = S;

        end
        
        function addDriftToShifts(obj, drift)
        %addDriftToShifts Add drift value to the shifts for current part
            i = 1;
            j = obj.CurrentPlane;
            iIndices = obj.CurrentFrameIndices;

            obj.ShiftsArray{i,j}(iIndices) = obj.addShifts(...
                    obj.ShiftsArray{i,j}(iIndices), drift);
        end
        
        function saveShifts(obj)
            shiftsArray = obj.ShiftsArray;
            obj.saveData('NormcorreShifts', shiftsArray)
        end
        
        function updateCorrectionStats(obj, IND)
            
            if nargin < 2
                IND = obj.CurrentFrameIndices;
            end
            
            i = 1;
            j = obj.CurrentPlane;
            
            S = obj.CorrectionStats{i, j};
            
            % Get the nonrigid shifts as a cell array
            nrShifts = {obj.ShiftsArray{i,j}(IND).shifts};
            
            % Compute quantities
            rmsmov = cellfun(@(shifts) sqrt(mean(shifts(:).^2)), nrShifts);
            xOffset = cellfun(@(shifts) mean(reshape(shifts(:,:,:,2), 1, [])) , nrShifts);
            yOffset = cellfun(@(shifts) mean(reshape(shifts(:,:,:,1), 1, [])) , nrShifts);
            
            % Add results to struct
            S.offsetX(IND) = xOffset;
            S.offsetY(IND) = yOffset;
            S.rmsMovement(IND) = rmsmov;
            
            obj.CorrectionStats{i, j} = S;
            
            % Save updated image registration stats to data location
            obj.saveData('MotionCorrectionStats', obj.CorrectionStats)
            
        end
        
        function template = initializeTemplate(obj, imArray, options)
            
            %Todo: Improve this!
            
            % Todo: Select number of frames (and iterations) to use based
            % on options...
            M = nansen.wrapper.normcorre.utility.rigid(imArray);
            
            % Todo: Find correct dimension to average...?
            template = mean(M, 3);
            
            obj.CurrentRefImage = template;
            
        end

    end
    
    methods (Access = protected) % Run the motion correction / image registration
        
        function onInitialization(obj)
            onInitialization@nansen.processing.MotionCorrection(obj)
            warnID = 'MATLAB:mir_warning_maybe_uninitialized_temporary';
            warning('off', warnID)
            
            % Save original selection for drift correction. This value will
            % be adjusted during motion correction to make sure that drifts
            % are only corrected for the reference channel (will be 
            % automatically applied to other channels). Note: important to
            % do this after the superclass' onInitialization method so that
            % this extra field is not added to the saved options.
            obj.Options.General.correctDriftUserChoice = obj.Options.General.correctDrift;
            
            % todo: get from options
            obj.StackIterator.PrimaryChannel = obj.ChannelToCorrect;
            
            % Start parallell pool
            % gcp();%parpool()
        end
        
        function [M, results] = registerImageData(obj, Y)
            
            % Get toolbox options and template for motion correction.
            options = obj.ToolboxOptions;
            options.correct_bidir = false; % should be done elsewhere...

            results = true;
            
            i = 1;
            j = obj.CurrentPlane;
            
            template = single( obj.CurrentRefImage );

            Y = squeeze(Y);

            if obj.CurrentChannel == obj.ChannelToCorrect
                
                obj.Options.General.correctDrift = obj.Options.General.correctDriftUserChoice;

                [M, shifts, templateOut] = normcorre_batch(Y, options, template);
                obj.CurrentRefImage = templateOut;
                                
                % Write reference image to file.
                templateOut = cast(templateOut, obj.SourceStack.DataType);
                obj.DerivedStacks.ReferenceStack.writeFrameSet(templateOut, obj.CurrentPart)

                % Add shifts to shiftarray
                obj.ShiftsArray{i,j}(obj.CurrentFrameIndices) = shifts;
            else
                % Make sure drift is not corrected based on this channel:
                obj.Options.General.correctDrift = false;
                
                % Get shifts from shiftarray
                nc_shifts_part = obj.ShiftsArray{i,j}(obj.CurrentFrameIndices);
                M = apply_shifts(Y, nc_shifts_part, options);
            end
        end
        
        function onCompletion(obj)
            onCompletion@nansen.processing.MotionCorrection(obj)
            warnID = 'MATLAB:mir_warning_maybe_uninitialized_temporary';
            warning('on', warnID)
        end
        
    end
    
    methods (Static)
                
        function ncShifts = addShifts(ncShifts, offset)
            % Add rigid shifts to struct of normcorre nonrigid shifts.
            for k = 1:numel(ncShifts)
                ncShifts(k).shifts(:,:,:,1) = ncShifts(k).shifts(:,:,:,1) + offset(1);
                ncShifts(k).shifts(:,:,:,2) = ncShifts(k).shifts(:,:,:,2) + offset(2);
                ncShifts(k).shifts_up(:,:,:,1) = ncShifts(k).shifts_up(:,:,:,1) + offset(1);
                ncShifts(k).shifts_up(:,:,:,2) = ncShifts(k).shifts_up(:,:,:,2) + offset(2);
            end
        end
        
    end
    
    methods (Static) % Method in external file.
        options = getDefaultOptions()
        
        pathList = getDependentPaths()
        
        function name = getImviewerPluginName()
            name = 'NoRMCorre';
        end
    
    end

end