classdef Processor < nansen.processing.MotionCorrection & ...
                        nansen.module.abstract.ToolboxWrapper
%nansen.adapter.flowreg.Processor Wrapper for running flowregistration on nansen
%
%   h = nansen.adapter.flowreg.Processor(imageStackReference)
%
%   This class provides functionality for running flowreg within
%   the nansen package.
%
%   Added functionality:
%       - Pause/stop registration and resume at later time
%       - Interactive configuration of parameters
%       - Save reference images



%   TODO:
%       [ ] Print command line output
%       [ ] Implement multiple channel correction
%       [ ] Improve initialization of template or leave it to normcorre...


%       [ ] Is there time to be saved on calculating shift metrics on
%           downsampled shift data. Will metrics be quanitatively similar or
%           not. 


    properties (Constant) % Attributes inherited from nansen.DataMethod
        MethodName = 'Motion Correction (FlowRegistration)'
        IsManual = false        % Does method require manual supervision
        IsQueueable = true      % Can method be added to a queue
    end
    
    properties (Constant, Access = protected)
        %DependentPaths = nansen.module.flowreg.getDependentPaths()
    end
    
    properties (Access = private)
        CorrectionParams
        CurrentShifts
    end
    
    
    methods % Constructor 
        
        function obj = Processor(varargin)
        %nansen.module.flowreg.Processor Construct flowreg processor
        %
        %   h = nansen.module.flowreg.Processor(imageStackReference)
            
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
        
        function S = getToolboxSpecificOptions(obj, varargin)
        %getToolboxSpecificOptions Get options from parameters or file
        %
        %   S = getToolboxSpecificOptions(obj, stackSize) return a
        %   struct of parameters for the flowreg pipeline. The options
        %   are created based on the user's selection of parameters that
        %   are given to this instance of the SessionMethod/flowreg
        %   class. If flowreg options already exist on file for this
        %   session, those options are selected.

        %   Todo: Need to adapt to aligning on multiple channels/planes.

            % Get the flowregistration options struct based on the parameter
            % selection and the size of the image stack to be corrected.
            import nansen.module.flowreg.Options
            opts = Options.convert(obj.Options);
            
            optionsVarname = 'flowregOptions';
            
            % Initialize options (Load from session if options already
            % exist, otherwise save to session)
            S = obj.initializeOptions(opts, optionsVarname);
            
            
            
        end
        
        function tf = checkIfPartIsFinished(obj, partNumber)
        %checkIfPartIsFinished Check if shift values exist for given frames
        
            shifts = obj.ShiftsArray;
            frameIND = obj.FrameIndPerPart{partNumber};
            
            tf = all( arrayfun(@(i) ~isempty(shifts{i}), frameIND) );

        end
        
        function initializeShifts(obj, numFrames)
        %initializeShifts Load or initialize shifts...
        
            filePath = obj.getDataFilePath('flowregShifts', ...
                'Subfolder', 'image_registration');
            
            if isfile(filePath)
                S = obj.loadData('flowregShifts');
            
            else
                % Initialize blank struct array
                S = cell(numFrames, 1);
                
                obj.saveData('flowregShifts', S)
            end
            
            obj.ShiftsArray = S;

        end
        
        function updateShifts(obj)
            
        end
        
        function saveShifts(obj)
        %saveShifts Save shifts in shiftarray to file  
            shiftsArray = obj.ShiftsArray;
            obj.saveData('flowregShifts', shiftsArray)
        end
        
        function updateCorrectionStats(obj, IND)
            
            import nansen.module.flowreg.utility.*
            
            if nargin < 2
                IND = obj.CurrentFrameIndices;
            end
            
            S = obj.CorrectionStats;
            
            W = cat(4, obj.CurrentShifts{:});
            displacement = sqrt( W(:,:,1,:).^2 + W(:,:,2,:).^2 ); 
            

            meanDisplacement = squeeze(mean(mean(displacement, 1), 2));
            maxDisplacement = squeeze(max(max(displacement, [], 1), [], 2));
            
            meanDivergence = get_mean_divergence(W);
            meanTranslation = get_mean_translation(W);
            
            % Compute quantities
            xOffset = squeeze(mean(mean(W(:,:,2,:), 1), 2)); %Todo: Is 2nd x-offsets?
            yOffset = squeeze(mean(mean(W(:,:,1,:), 1), 2)); %Todo: Is 1st y-offsets?
            rmsmov = sqrt(mean( W(:).^2) );

            % Add results to struct
            S.offsetX(IND) = xOffset;
            S.offsetY(IND) = yOffset;
            S.rmsMovement(IND) = rmsmov;
            
            % Todo: Add these:
% % %             S.meanDisplacement(IND) = meanDisplacement;
% % %             S.maxDisplacement(IND) = maxDisplacement;
% % %             S.meanDivergence(IND) = meanDivergence;
% % %             S.meanTranslation(IND) = meanTranslation;
            
            
            % Save updated image registration stats to data location
            obj.saveData('imregStats', S)
            obj.CorrectionStats = S;
            
        end
        
        function template = initializeTemplate(obj, imArray)
                      
            % Todo: get frames based on options.frameNumForInitialTemplate
            
            import nansen.module.flowreg.utility.*
            
            options = obj.ToolboxOptions;
            
            if ~options.verbose
                disp('Preregistering reference frames...');
            end

            % Raw images, reshaped to H x W x nCh x nSamples
            Y = obj.reshapeImageArray(imArray); 
            
            % Channel weightings
            weight_2d = getFlowregChannelWeights(Y, options);
            
            % Preprocess images
            C1 = getFilteredImageArray(Y, options, 'sigmaOffset', [1 1 0.5]);
            
            % Get a motion corrected image array
            CRef = mean(C1, 4);
            YRef = mean(Y, 4);
            [CReg, ~] = compensateSequence(C1, CRef, Y, YRef, options, weight_2d);
            
            % Create template from mean projection of corrected image array
            template = mean(CReg, 4);
            
            template = squeeze(template);
            
            if ~options.verbose 
                disp('Finished pre-registration of the reference frames...');
            end
            
        end
        
        function template = updateTemplate(~, C1, w)
            % Todo: Fix size bug (?) and adapt to single channel images.
            if size(C1, 3) > 100
                template(:, :, 1) = mean(...
                    compensate_sequence_uv( double(C1(:, :, 1, end-100:end)), ...
                    mean(double(C1(:, :, 1, :)), 4), w(:, :, :, end-100:end)), 4);
                template(:, :, 2) = mean(...
                    compensate_sequence_uv( double(C1(:, :, 2, end-100:end)), ...
                    mean(double(C1(:, :, 2, :)), 4), w(:, :, :, end-100:end)), 4);
            end   
            
        end
        
        function initializeParameters(obj, imArray)
            
            import nansen.module.flowreg.utility.*

            options = obj.ToolboxOptions;
            initTemplate = obj.CurrentRefImage; 
            
            % Raw images, reshaped to H x W x nCh x nSamples
            Y = obj.reshapeImageArray(imArray); 

            % Channel weightings
            weight = getFlowregChannelWeights(Y, options);
            
            % Create normalized array from subset of imArray
            YSubset = Y(:, :, :, 1:min(22, size(imArray, 4)));
            CSubset = getFilteredImageArray(YSubset, options);
            
            % Get a filtered reference image...
            Ygauss = imgaussfilt3_multichannel(Y, options);
            c_ref = getFilteredImageArray(initTemplate, options, ...
                'normalizationRef', Ygauss);

            % Get initial shifts based on a subset of the images
            nvPairs = {'weight', weight};
            shifts = getDisplacements(CSubset, c_ref, options, nvPairs{:});

            params.initialShifts = mean(shifts, 4);
            params.cRef = c_ref;
           
            obj.CorrectionParams = params;
            
        end
        
        
    end
    
    methods (Access = protected) % Run the motion correction / image registration
        
        function M = registerImageData(obj, Y)
            
            import nansen.module.flowreg.utility.*

            options = obj.ToolboxOptions;
            template = obj.CurrentRefImage;
            
            if isempty(obj.CorrectionParams)
                obj.initializeParameters(Y);
            end
            params = obj.CorrectionParams;
            

            % What is the difference between cref and cref raw???
            
            % Raw images, reshaped to H x W x nCh x nSamples
            Y = obj.reshapeImageArray(Y);       

            % Channel weightings
            weight = getFlowregChannelWeights(Y, options);
            
            c1 = getFilteredImageArray(mat2gray(Y), options);
            
            w_init = params.initialShifts;
            c_ref = params.cRef;
            nvPairs = {'weight', weight, 'uv', w_init(:, :, 1), w_init(:, :, 2)};
            shifts = getDisplacements(c1, c_ref, options, nvPairs{:});
            
            M = compensate_sequence_uv( Y, template, shifts );
            
            generalOptions.updateTemplate = false; % <-- Todo
            if generalOptions.updateTemplate
            %if obj.Options.Template.updateTemplate
                templateOut = obj.updateTemplate(c1, shifts);
            else
                templateOut = template;
            end
            
            
            obj.CurrentRefImage = templateOut;
            
            % Write reference image to file.
            templateOut = cast(templateOut, obj.SourceStack.DataType);
            obj.ReferenceStack.writeFrameSet(templateOut, obj.CurrentPart)
            
            
            % todo: adapt this for cases where parts are not aligned in
            % sequence (if realigning only a subset of parts)
            if size(M, 4) > 100
                params.initialShifts = mean(shifts(:, :, :, end-20:end), 4);
            else
                params.initialShifts = mean(shifts, 4); %w_init;
            end
            
            obj.CorrectionParams = params;
            
            M = squeeze(M);
            
            

            % Convert shifts to cell array and add to shiftarray.
            shifts = arrayfun(@(i) shifts(:, :, :, i), 1:size(shifts,4), 'uni', 0);
            obj.CurrentShifts = shifts;
            
            % Downsample shifts before saving.
            for i = 1:numel(shifts)
                shifts{i} = single(imresize(shifts{i}, [32,32]) );
            end
            
            obj.ShiftsArray(obj.CurrentFrameIndices) = shifts;
            
            % These variables are required:
            % c_ref, c_ref_raw, w_init, weight
            
        end

    end
    
    methods (Static)
                
        function imArray = reshapeImageArray(imArray)
            % Reshape imarray: imHeight x imWidth x numCh x numSamples
            if ndims(imArray) == 3
                sz = size(imArray);
                imArray = reshape(imArray, sz(1), sz(2), 1, sz(3));
            elseif ndims(imArray) > 4
                error('Dimension of image array is not supported')
            end
        end
        
        function shifts = addShifts(shifts, offset)
            % Add rigid shifts to struct of normcorre nonrigid shifts.
            for k = 1:numel(shifts)
                shifts{k}(:, :, 1, :) = shifts{k}(:, :, 1, :) + offset(1);
                shifts{k}(:, :, 2, :) = shifts{k}(:, :, 2, :) + offset(2);
            end  
        end
        
    end
    
    methods (Static) % Method in external file.
        options = getDefaultOptions()
        
        pathList = getDependentPaths()
    end

end