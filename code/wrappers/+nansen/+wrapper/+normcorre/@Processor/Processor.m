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
%       [ ] Implement multiple channel correction
%       [ ] Improve initialization of template or leave it to normcorre... 


    properties (Constant) % Attributes inherited from nansen.DataMethod
        MethodName = 'Motion Correction (NoRMCorre)'
        IsManual = false        % Does method require manual supervision?
        IsQueueable = true      % Can method be added to a queue?
        OptionsManager nansen.manage.OptionsManager = ...
            nansen.OptionsManager('nansen.wrapper.normcorre.Processor')
    end
    
    properties (Constant, Hidden)
        DATA_SUBFOLDER = 'image_registration'; % Name of subfolder(s) where to save results by default
    end
    
    properties (Constant) % From motion correction
        ImviewerPluginName = 'NoRMCorre'
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
            
            % Todo. Move to superclass
            obj.Options.Export.FileName = obj.SourceStack.Name;
            
            % Call the appropriate run method
            if ~nargout
                obj.runMethod()
                clear obj
            end
            
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
        
            shifts = obj.ShiftsArray;
            IND = obj.FrameIndPerPart{partNumber};
            
            tf = all( arrayfun(@(i) ~isempty(shifts(i).shifts), IND) );

        end
        
        function initializeShifts(obj, numFrames)
        %initializeShifts Load or initialize shifts...
        
            % Get filepath (initialize if it does not exist)
            filePath = obj.getDataFilePath('NormcorreShifts', '-w', ...
                'Subfolder', obj.DATA_SUBFOLDER, 'IsInternal', true);
            
            if isfile(filePath)
                S = obj.loadData('NormcorreShifts');
            
            else
                % Initialize blank struct array
                C = cell(numFrames, 1);
                S = struct('shifts', C, 'shifts_up', C, 'diff', C);
                
                obj.saveData('NormcorreShifts', S)
            end
            
            obj.ShiftsArray = S;

        end
        
        function saveShifts(obj)
            shiftsArray = obj.ShiftsArray;
            obj.saveData('NormcorreShifts', shiftsArray)
        end
        
        function updateCorrectionStats(obj, IND)
            
            if nargin < 2
                IND = obj.CurrentFrameIndices;
            end
            
            S = obj.CorrectionStats;
            
            % Get the nonrigid shifts as a cell array
            nrShifts = {obj.ShiftsArray(IND).shifts};
            
            % Compute quantities
            rmsmov = cellfun(@(shifts) sqrt(mean(shifts(:).^2)), nrShifts);
            xOffset = cellfun(@(shifts) mean(reshape(shifts(:,:,:,2), 1, [])) , nrShifts);
            yOffset = cellfun(@(shifts) mean(reshape(shifts(:,:,:,1), 1, [])) , nrShifts);
            
            % Add results to struct
            S.offsetX(IND) = xOffset;
            S.offsetY(IND) = yOffset;
            S.rmsMovement(IND) = rmsmov;
            
            % Save updated image registration stats to data location
            obj.saveData('MotionCorrectionStats', S)
            obj.CorrectionStats = S;
            
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
            
        function M = registerImageData(obj, Y)
            
            % Get toolbox options and template for motion correction.
            options = obj.ToolboxOptions;
            template = single( obj.CurrentRefImage );
            
            [M, shifts, templateOut] = normcorre_batch(Y, options, template);
            
            % Add shifts to shiftarray
            obj.ShiftsArray(obj.CurrentFrameIndices) = shifts;
            
            obj.CurrentRefImage = templateOut;
            
            % Write reference image to file.
            templateOut = cast(templateOut, obj.SourceStack.DataType);
            obj.ReferenceStack.writeFrameSet(templateOut, obj.CurrentPart)
            
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