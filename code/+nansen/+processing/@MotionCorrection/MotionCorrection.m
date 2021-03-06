classdef MotionCorrection < nansen.stack.ImageStackProcessor
%nansen.processing.MotionCorrection Run motion correction on ImageStacks
%
%   This class is an abstract class that provides a framework for running
%   motion correction on ImageStack objects. It inherits the following 
%   classes:
%
%   - nansen.DataMethod : Provides data I/O model and options functionality
%   - nansen.stack.ImageStackProcessor : Process ImageStack in subparts
%
%   Known subclasses:
%   - nansen.wrappers.normcorre.Processor : Implements the normcorre toolbox
%   - nansen.wrappers.flowreg.Processor : Implements the flowregistration toolbox
%
%  obj = obj@nansen.processing.MotionCorrection(dataLocation) creates the
%  object based on a given dataLocation. The dataLocation can be:
%       1) A filepath
%       2) An ImageStack (containing VirtualData)
%       3) A struct-based DataLocation (not implemented yet).
%
%  obj = obj@nansen.processing.MotionCorrection(dataLocation, options)
%  creates the object and specifies the options to use for processing.
%
% Notes:
%
%   This class creates the following data variables:
%
%     * <strong>FovAverageProjection</strong> : Average projection from the full corrected stack
%
%     * <strong>FovMaximumProjection</strong> : Maximum projection from the full corrected stack
%
%     * <strong>MotionCorrectionStats</strong> : A struct array with various stats from motion correction.
%           - offsetX : Rigid frame offset in x (numFrames x 1)
%           - offsetY : Rigid frame offset in y (numFrames x 1)
%           - rmsMovement : root mean square movement for frames (numFrames x 1)
%
%     * <strong>MotionCorrectionReferenceImage</strong> : A stack of reference images 
%     (templates) for motion correction. One reference per chunk
%       
%     * <strong>MotionCorrectionTemplates8bit</strong> : Same as above cast to 8bit
%
%     * <strong>MotionCorrectedAverageProjections</strong> : Image stack with average
%     projections. Each average projection is from one chunk of the stack
%
%     * <strong>MotionCorrectedAverageProjections8bit</strong> : Same as above, cast to 8bit
%     
%     * <strong>MotionCorrectedMaximumProjections</strong> : Image stack with maximum
%     projections. Each maximum projection is from one chunk of the stack
%
%     * <strong>MotionCorrectedMaximumProjections8bit</strong> : Same as above, cast to 8bit


%   QUESTIONS:
%       b) How to resolve initializing this method with a different set of
%          options than before?


    % Todo: 
    %   [??]??Save general options for motion correction... 
    %
    %   [??] Multichannel support
    %
    %   [??]??Move preview method to stack.ChunkProcessor (and rename to testrun/samplerun etc)
    %   [v]??Move preview functionality to ImageStackProcessor...
    %
    %   [??]??Move saveTiffStack & openTiffStack to somewhere else (not sure where.)
    %
    %   [ ] Add correctLineOffset, shiftStackSubRes functions
    %
    %   [??]??Save shifts in standardized output as well as method outputs...
    %
    %   POSTPROCESSING
    %   [ ] Save temporal downsampled stacks (postprocessing?).
    %               - Save successively, if downsampling
    %   [??]??Save 25th prctile (or better approximation to baseline) stack 
    %
    %   [??]??Need to load image stats. Also, nice to update imagestats if
    %       they are not available...

    
    properties (Abstract, Constant)
        ImviewerPluginName
    end

    properties (Dependent, SetAccess = private)
        RecastOutput        % Flag for whether to recast output.
    end
    
    properties 
        ImageStatsProcessor
    end
    
    properties (Access = protected) % Data to keep during processing.
        ToolboxOptions      % Options for specific toolbox that is used for image registration
        ImageStats          % Array of imagestats...
        ShiftsArray         % Array of detected shifts for each frame
        CorrectionStats     % Array of stats related to corrcetion results.
        
        CurrentRefImage     % Current reference image
        ReferenceStack      % Stack for reference (template) images
        AvgProjectionStack  % Stack for average projection images for each subpart
        MaxProjectionStack  % Stack for maximum projection images for each subpart
    end
    
    
    methods (Abstract, Access = protected) % Abstract methods that subclasses must implement
        
        S = getToolboxSpecificOptions(obj, varargin) % -> toolboxwrapper
                
        initializeShifts(obj, numFrames) % Protected?
        
        updateCorrectionStats(obj, S, shiftsArray, frameIndices)
        
        saveShifts(obj, shiftsArray)
        
        ref = initializeTemplate(obj, Y, opts); % Todo: Rename to create template...
        
        M = registerImageData(obj, Y) % Run motion correction on subpart of ImageStack
        
    end
    
    methods (Static, Abstract) % Abstract methods that subclasses must implement
         shifts = addShifts(shifts, offset)
    end
    
    methods % Structors
        
        function obj = MotionCorrection(varargin)
        %MotionCorrection Constructor for MotionCorrection superclass
            obj@nansen.stack.ImageStackProcessor(varargin{:})
        end
        
        function delete(obj)
            
            if ~isempty(obj.ReferenceStack)
                delete(obj.ReferenceStack)
            end
            
            if ~isempty(obj.AvgProjectionStack)
                delete(obj.AvgProjectionStack)
            end
            
            if ~isempty(obj.MaxProjectionStack)
                delete(obj.MaxProjectionStack)
            end
        end
        
    end
    
    methods 
        function recastOutput = get.RecastOutput(obj)
        %RecastOutput Determine if output needs to be recast.    
            dataTypeIn = obj.SourceStack.DataType;
            dataTypeOut = obj.Options.Export.OutputDataType;
            recastOutput = ~strcmp(dataTypeIn, dataTypeOut);
        end
    end
    
    methods (Access = protected) % Overide ImageStackProcessor methods
                
        function runPreInitialization(obj)
        %onPreInitialization Method that runs before the initialization step    
            
            % Determine how many steps are required for the method
            
            obj.NumSteps = 1;
            obj.StepDescription = {obj.MethodName};
            
            % 1) Check if stack should be recast before saving.
            if obj.RecastOutput
                % Need to compute pixel statistics for source stack..
                obj.NumSteps = obj.NumSteps + 1;
                descr = 'Compute pixel statistics';
                obj.StepDescription = [descr, obj.StepDescription];
            end
            
        end
        
        function onInitialization(obj)
            
            % Store basic info about the raw image stack in local variables
            stackSize = size(obj.SourceStack.Data);
            obj.validateStackSize(stackSize)

            % Get options (preconfigs) for the normcorre registration
            % Todo: Different toolboxes might require different inputs.
            obj.ToolboxOptions = obj.getToolboxSpecificOptions(stackSize);
           
            % Todo: Validate options. I.e, if processor is run again, some
            % of the options should be the same... 
           
            if obj.RecastOutput % Calculate imagestats if needed (for recasting).
                obj.displayStartCurrentStep()
                processor = stack.methods.computeImageStats(obj.SourceStack, ...
                    'DataIoModel', obj.DataIoModel);
                processor.IsSubProcess = true;
                processor.runMethod()
                obj.displayFinishCurrentStep()
            else
                % Can be computed during motion correction
                obj.ImageStatsProcessor = stack.methods.computeImageStats(...
                    obj.SourceStack, 'DataIoModel', obj.DataIoModel);
                obj.ImageStatsProcessor.IsSubProcess = true;
                obj.ImageStatsProcessor.matchConfiguration(obj)
            end

            numFrames = stackSize(end); % Todo...
            dataTypeIn = obj.SourceStack.DataType;
            
            % Open output file
            dataTypeOut = obj.Options.Export.OutputDataType;
            obj.openTargetStack(stackSize, dataTypeOut);
            
            obj.ImageStats = obj.getImageStats(numFrames); % Todo: Remove???
            
            % Initialize (or load) results
            obj.initializeShifts(numFrames);
            obj.initializeCorrectionStats(numFrames);

            % Create image stack for saving reference (template) images
            varName = 'MotionCorrectionReferenceImage'; %'MotionCorrectionTemplate'
            refArray = zeros( [stackSize(1:2), obj.NumParts], dataTypeIn);
            obj.ReferenceStack = obj.openTiffStack(varName, refArray);
            
            % Todo implement like this instead of above:
            %obj.saveData(refName, refArray)
            %obj.ReferenceStack = obj.loadData(refName)
            
            % Create image stack for saving average projection images
            if obj.Options.Export.saveAverageProjection
                varName = 'MotionCorrectedAverageProjections';
                obj.AvgProjectionStack = obj.openTiffStack(varName, refArray);
            end
                
            % Create image stack for saving maximum projection images
            if obj.Options.Export.saveMaximumProjection
                varName = 'MotionCorrectedMaximumProjections';
                obj.MaxProjectionStack = obj.openTiffStack(varName, refArray);
            end

        end
        
        function Y = processPart(obj, Y, ~)
            
             Y = obj.preprocessImageData(Y);
            
             Y = obj.registerImageData(Y);
             
             Y = obj.postprocessImageData(Y);

        end
        
        function onCompletion(obj)

            % Determine amount of cropping to use for adjusting image data
            % to uint8
            maxX = max(obj.CorrectionStats.offsetX);
            maxY = max(obj.CorrectionStats.offsetY);
            crop = round( max([maxX, maxY])*1.5 );
            
            % Save reference images to 8bit
            imArray = obj.ReferenceStack.getFrameSet(1:obj.NumParts);
            imArray = stack.makeuint8(imArray);
            obj.saveTiffStack('MotionCorrectionTemplates8bit', imArray)

            % Save average and maximum projections as 8-bit stacks.
            if obj.Options.Export.saveAverageProjection
                imArray = obj.AvgProjectionStack.getFrameSet(1:obj.NumParts);
                imArray = stack.makeuint8(imArray, [], [], crop); % todo: Generalize this function / add tolerance as input
            	obj.saveTiffStack('MotionCorrectedAverageProjections8bit', imArray)
            end
            
            if obj.Options.Export.saveMaximumProjection
                imArray = obj.MaxProjectionStack.getFrameSet(1:obj.NumParts);
                imArray = stack.makeuint8(imArray, [], [], crop); % todo: Generalize this function / add tolerance as input
                obj.saveTiffStack('MotionCorrectedMaximumProjections8bit', imArray)
            end
            
            % Save average projection image of full stack
            imArray = obj.AvgProjectionStack.getFrameSet(1:obj.NumParts);
            fovAverageProjection = mean(imArray, 3);
            fovAverageProjection = stack.makeuint8(fovAverageProjection, [], [], crop);
            obj.saveData('FovAverageProjection', fovAverageProjection, ...
                'Subfolder', 'fov_images', 'FileType', 'tif', ...
                'FileAdapter', 'ImageStack' );
            
            % Save maximum projection image of full stack
            imArray = obj.MaxProjectionStack.getFrameSet(1:obj.NumParts);
            fovMaximumProjection = mean(imArray, 3);
            fovMaximumProjection = stack.makeuint8(fovMaximumProjection, [], [], crop);
            obj.saveData('FovMaximumProjection', fovMaximumProjection, ...
                'Subfolder', 'fov_images', 'FileType', 'tif', ...
                'FileAdapter', 'ImageStack' );
        end
        
    end
        
    methods (Access = protected) % Pre- and processing methods for imagedata

        function Y = preprocessImageData(obj, Y, ~, ~)
        %preprocessImageData Preprocess image data before registration
        %
        %   Take care of some preprocessing steps that should be common for
        %   many motion correction methods.
        
            % Update image stats.
            if ~isempty( obj.ImageStatsProcessor )
                obj.ImageStatsProcessor.setCurrentPart(obj.CurrentPart);
                obj.ImageStatsProcessor.processPart(Y)
            end

            % Subtract minimum value.
            minVal = prctile(obj.ImageStats.prctileL2, 5);
            Y = Y - minVal;

            Y = single(Y); % Cast to single for the alignment


            % Todo, implement options selection
            if ~strcmp( obj.Options.Preprocessing.BidirectionalCorrection, 'None')
                Y = obj.correctBidirectionalOffsets(Y);
            end
                                    
            % Get template for motion correction of current part
            if obj.CurrentPart == 1
                
                ref = obj.ReferenceStack.getFrameSet(1);
                
                if all(ref(:)==0)
                    ref = obj.initializeTemplate(Y); %<- todo: save initial template to session
                end
                
                % Assign current reference image
                obj.CurrentRefImage = ref;
                
                % Save reference image
                refOut = cast(ref, obj.SourceStack.DataType);
                obj.ReferenceStack.writeFrameSet(refOut, obj.CurrentPart);
                
            elseif isempty(obj.CurrentRefImage)
                ref = obj.ReferenceStack.getFrameSet( obj.CurrentPart - 1);
                obj.CurrentRefImage = single(ref);
            end

        end

        function M = postprocessImageData(obj, Y, ~, ~)
            
            iIndices = obj.CurrentFrameIndices;
            iPart = obj.CurrentPart;
            
            % Add minval... % Todo: Check if this step is necessary...
            minVal = prctile(obj.ImageStats.prctileL2, 5);
            Y = Y + minVal;

            % Correct drift.
            obj.Options.General.correctDrift = true;
            if iPart ~= 1 && obj.Options.General.correctDrift
                
                % Todo: Make sure this does not leave black edges!
                [Y, drift] = obj.correctDrift(Y);
                
                % Todo:
                updateReference = false;
                if updateReference                    
                    obj.CurrentRefImage = imtranslate( obj.CurrentRefImage, [drift(1), drift(2)] );
                    % Write reference image to file.
                    templateOut = cast(obj.CurrentRefImage, obj.SourceStack.DataType);
                    obj.ReferenceStack.writeFrameSet(obj.CurrentRefImage, obj.CurrentPart)
                end
                
                % Add drift to shifts.
                obj.ShiftsArray(iIndices) = obj.addShifts(...
                    obj.ShiftsArray(iIndices), drift);
            end

            % Save stats based on motion correction shifts
            obj.updateCorrectionStats(iIndices)

            % Check if output should be recast...
            dataTypeIn = obj.SourceStack.DataType;
            dataTypeOut = obj.Options.Export.OutputDataType;
            
            recastOutput = ~strcmp(dataTypeIn, dataTypeOut);
            
            % Save images to corrected stack (todo: place in method?)
            if recastOutput
                % Todo: throw out outliers instead of using prctile?
                minVal = prctile(obj.ImageStats.prctileL2, 5);
                maxVal = max(obj.ImageStats.prctileU2);

                switch dataTypeOut
                    case 'uint8'
                        M = stack.makeuint8(Y, [minVal, maxVal]);
                    otherwise
                        error('Not implemented yet')
                end
            else
                M = cast(Y, dataTypeIn);
            end
            
            % Save projections images if selected
            
            if obj.Options.Export.saveAverageProjection
                avgProj = mean(Y, 3);
                avgProj = cast(avgProj, dataTypeIn);
                obj.AvgProjectionStack.writeFrameSet(avgProj, iPart)
            end
            
            if obj.Options.Export.saveMaximumProjection
                % Filter using okada before getting the max.
                Y_ = stack.process.filter3.okada(Y);
                maxProj = max(Y_, [], 3);
                maxProj = cast(maxProj, dataTypeIn);
                obj.MaxProjectionStack.writeFrameSet(maxProj, iPart)
            end
            
            % Important: Do this last, because shifts are used to check if 
            % current part is corrected or not.
            obj.saveShifts()
        end
    end

    methods (Access = protected)
           
        function openTargetStack(obj, stackSize, dataType)

            % Get file reference for corrected stack
            DATANAME = 'TwoPhotonSeries_Corrected';

            switch obj.Options.Export.OutputFormat
                case 'Binary'
                    fileType = '.raw';
                case 'Tiff'
                    error('Writing to tiff is not supported yet')
                    fileType = '.tif';
            end

            filePath = obj.getDataFilePath(DATANAME, 'FileType', fileType);
            
            % Call method of ImageStackProcessor
            openTargetStack@nansen.stack.ImageStackProcessor(obj, filePath, stackSize, dataType)
            
            % Inherit metadata from the source stack
            obj.TargetStack.MetaData.updateFromSource(obj.SourceStack.MetaData)
            
            % Make sure caching is turned off...
            obj.TargetStack.Data.UseDynamicCache = false;


            if isa(obj.TargetStack, 'nansen.stack.virtual.SciScanRaw')
                % Class takes care of this internally
                obj.Options.Preprocessing.NumFlybackLines = 0;
            end

        end
        
        function opts = initializeOptions(obj, opts, optionsVarname)
        % Get filepath for saving options file to session folder

            filePath = obj.getDataFilePath(optionsVarname, '-w', ...
                'Subfolder', 'image_registration', 'IsInternal', true);
            
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
                    'Subfolder', 'image_registration')
            end
            
        end
                 
    end
    
    methods (Access = private)

        function validateStackSize(~, stackSize)
        %validateStackSize Check if stack has correct size for motion corr    
            
            % todo: channels (and planes)...
            if numel(stackSize) > 3
                error('Multi channel and/or multiplane stacks are not supported yet')
            elseif numel(stackSize) == 3
                % This is fine:)
            else
                error('Can not motion correct stack with less than 3 dimensions...')
            end
            
        end
        
        function rawStack = openRawTwoPhotonStack(obj)
            
            % Not sure if this will be ever used..
            
            % Get filepath for raw 2p-images
            DATANAME = 'TwoPhotonSeries_Original';
            filePath = obj.DataIoModel.getDataFilePath(DATANAME);
            
            % Initialize file reference for raw 2p-images
            rawStack = nansen.stack.ImageStack(filePath);
            rawStack.enablePreprocessing()
            
        end
        
        % Todo: this should be done using save data method of iomodel
        function saveTiffStack(obj, DATANAME, imageArray)
            
            filePath = obj.getDataFilePath( DATANAME, '-w',...
                'Subfolder', 'image_registration', 'FileType', 'tif', ...
                'FileAdapter', 'ImageStack', 'IsInternal', true );
                
            nansen.stack.utility.mat2tiffstack( imageArray, filePath )

        end
        
        % Todo: this should be done using load data method of iomodel
        % and an imagestack file adapter.
        function tiffStack = openTiffStack(obj, DATANAME, imageArray)
                        
            filePath = obj.getDataFilePath( DATANAME, '-w',...
                'Subfolder', 'image_registration', 'FileType', 'tif', ...
                'FileAdapter', 'ImageStack', 'IsInternal', true );
            
            if ~isfile(filePath)
                nansen.stack.utility.mat2tiffstack( imageArray, filePath )
            end
            
            if nargout
                imageData = nansen.stack.open(filePath);
                tiffStack = nansen.stack.ImageStack(imageData);
            end
            
        end

        function initializeCorrectionStats(obj, numFrames)
        %initializeCorrectionStats Initialize struct to store stats
        
        %   Save rigid shifts (x and y)
        %   Save rms movement of frames    

            % Check if imreg stats already exist for this session
            filePath = obj.getDataFilePath('MotionCorrectionStats', '-w',...
                'Subfolder', 'image_registration', 'IsInternal', true);
            
            % Load or initialize
            if isfile(filePath)
                S = obj.loadData('MotionCorrectionStats');
            else
                nanArray = nan(numFrames, 1);
                
                S.offsetX = nanArray;
                S.offsetY = nanArray;
                S.rmsMovement = nanArray;

                obj.saveData('MotionCorrectionStats', S, ...
                    'Subfolder', 'image_registration');
            end
            
            obj.CorrectionStats = S;
            
        end

        % Todo: This should be an external function!
        function S = getImageStats(obj, ~)
            
            % Check if image stats already exist for this session
            filePath = obj.getDataFilePath('ImageStats', '-w', ...
                'Subfolder', 'raw_image_info', 'IsInternal', true);
            
            if isfile(filePath)
                S = obj.loadData('ImageStats');
            else
                error('Image stats was not found')
            end

        end

        function [M, shifts] = correctDrift(obj, M)
            
            % Todo: improve function....
            % Todo: shiftStackSubRes is not part of pipeline.....
            
            % Only need to do this first time...
            sessionRef = obj.ReferenceStack.getFrameSet(1);

            options_rigid = NoRMCorreSetParms('d1', size(M,1), 'd2', size(M,2), ...
                'bin_width', 50, 'max_shift', 20, 'us_fac', 50, ...
                'correct_bidir', false, 'print_msg', 0);
            
            [~, nc_shifts, ~,~] = normcorre(mean(M, 3), options_rigid, sessionRef);
            dx = arrayfun(@(row) row.shifts(2), nc_shifts);
            dy = arrayfun(@(row) row.shifts(1), nc_shifts);

            M = imtranslate(M, [dx,dy] );
            shifts = [dx, dy];
        
        end

        function Y = correctBidirectionalOffsets(obj, Y)
            
            import nansen.wrapper.normcorre.utility.apply_bidirectional_offset
            % Multiple channels serial
            % Multiple channels batch
            
            if ndims(Y) == 4
                Ymean = squeeze( mean(Y, 3) );
                colShift = correct_bidirectional_offset(Ymean, size(Y,4), 10);

                for i = 1:size(Y, 3)
                    Y(:,:,i,:) = apply_bidirectional_offset(Y(:, :, i, :), colShift);
                end
                
            elseif ndims(Y) == 3
                [~, Y] = correct_bidirectional_offset(Y, size(Y,3), 10);
            end
            
%             % Todo:
%             switch obj.Options.Preprocessing.BidirectionalCorrection
% 
%                 case {'Constant', 'OneTime'}
%                     %[~, Y] = correct_bidirectional_offset(Y,   )
%                 case {'Time Dependent', 'Continuous', 'Adaptive'}
%                     %[Y, bidirBatchSize, colShifts] = nansen.wrapper.normcorre.utility.correctLineOffsets(Y, 100);
%             end

        end

    end
    
    methods (Static) % Method in external file (Get default options)
        
        S = getDefaultOptions()

    end

end