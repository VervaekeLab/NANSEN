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
%   - nansen.modules.normcorre.Processor : Implements the normcorre toolbox
%   - nansen.modules.flowreg.Processor : Implements the flowregistration toolbox
%
%  obj = obj@nansen.processing.MotionCorrection(dataLocation) creates the
%  object based on a given dataLocation. The dataLocation can be:
%       1) A filepath
%       2) An ImageStack (containing VirtualData / file connection)
%       3) A struct-based DataLocation (not implemented yet).
%
%  obj = obj@nansen.processing.MotionCorrection(dataLocation, options)
%  creates the object and specifies the options to use for processing.


%   QUESTIONS:
%       b) How to resolve initializing this method with a different set of
%          options than before?


    % Todo: 
    %   [ ] Save general options for motion correction... 
    %
    %   [ ] Multichannel support
    %
    %   [ ] Move preview method to stack.ChunkProcessor (and rename to testrun/samplerun etc)
    %   [ ] Move saveTiffStack & openTiffStack to somewhere else (not sure where.)
    %
    %   [ ] Add correctLineOffset, shiftStackSubRes functions
    %
    %   [ ] Save shifts in standardized output as well as method outputs...
    %
    %   [ ] Move preview functionality to ImageStackProcessor...
    %
    %   POSTPROCESSING
    %   [ ] Save temporal downsampled stacks (postprocessing?).
    %               - Save successively, if downsampling
    %   [ ] Save 25th prctile (or better approximation to baseline) stack 
    %
    %   [ ] Need to load image stats. Also, nice to update imagestats if
    %   they are not available...

    properties (Abstract, Constant)
        ImviewerPluginName
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
                
        S = initializeShifts(obj, numFrames) % Protected?
        
        S = updateCorrectionStats(obj, S, shiftsArray, frameIndices)
        
        saveShifts(obj, shiftsArray)
        
        % Todo: Rename to create template...
        ref = initializeTemplate(obj, Y, opts);
        
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
    
    methods (Access = protected) % Overide ImageStackProcessor methods
        
        function onInitialization(obj)
            
            % Store basic info about the raw image stack in local variables
            stackSize = size(obj.SourceStack.Data);

            % Get options (preconfigs) for the normcorre registration
            % Todo: Different toolboxes might require different inputs.
            obj.ToolboxOptions = obj.getToolboxSpecificOptions(stackSize);
           
            % Todo: Validate options. I.e, if processor is run again, some
            % of the options should be the same... 
            
            
            % todo: channels (and planes)...
            if numel(stackSize) > 3
                error('Multi channel and/or multiplane stacks are not supported yet')
            elseif numel(stackSize) == 3
                numFrames = stackSize(3);
            else
                error('Can not motion correct stack with less than 3 dimensions...')
            end
            
            
            dataTypeIn = obj.SourceStack.DataType;
            dataTypeOut = obj.Options.Export.OutputDataType;
            recastOutput = ~strcmp(dataTypeIn, dataTypeOut);
            
            if recastOutput % Todo: Calculate imagestats.
                stack.methods.computeImageStats(obj.SourceStack, ...
                    'DataIoModel', obj.DataIoModel)
            end

            
            % Open output file
            obj.openOutputFile(stackSize, dataTypeOut);
            
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
        end
        
    end
    
    methods (Access = protected) % Pre- and processing methods for imagedata

        function Y = preprocessImageData(obj, Y, ~, ~)
        %preprocessImageData Preprocess image data before registration
        %
        %   Take care of some preprocessing steps that should be common for
        %   many motion correction methods.
        
            % Update image stats
            % Todo: Only do this if output should be recast?
            % Todo: Do this using the stack.methods.computeImageStats class
            obj.updateImageStats(Y);
            
            

            % Subtract minimum value. Might not be necessary...
            minVal = prctile(obj.ImageStats.prctileL2, 5);
            Y = Y - minVal;

            Y = single(Y); % Cast to single for the alignment

            % Todo: Should this be here or baked into the
            % getRawStack / getframes method of rawstack?
            
            % Todo, implement options selection
            [Y, bidirBatchSize, colShifts] = nansen.module.normcorre.utility.correctLineOffsets(Y, 100);
            
            
            %frameInd = obj.CurrentFrameIndices;
                        
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
    
    methods % Implementation of abstract, public methods
        
        function tf = preview(obj) % -> imageStackProcessor
            
            %CLASSNAME = class(obj);
            CLASSNAME = obj.ImviewerPluginName;
           
            rawStack = openRawTwoPhotonStack(obj, true);
            rawStack.DynamicCacheEnabled = 'on';
            
            hImviewer = imviewer(rawStack);
            
            h = hImviewer.openPlugin(CLASSNAME, obj.Parameters);
            % Will continue when the plugin is closed.
            
            obj.Parameters = h.settings;
            tf = ~h.wasAborted;

            delete(h)
            hImviewer.quit()
            
        end
        
    end
    
    methods (Access = protected)
               
        function opts = initializeOptions(obj, opts, optionsVarname)
        % Get filepath for saving options file to session folder

            filePath = obj.getDataFilePath(optionsVarname, '-w', ...
                'Subfolder', 'image_registration');
            
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

        
        % Todo: Remove... This is done here: imagestackprocessor.parseImageStackInput
        function rawStack = openRawTwoPhotonStack(obj, skipPrecomputeStats)
                  
        %   INPUT:
        %       quickOpen : Flag for opening without calculating image
        %       stats
        
            if nargin < 2
                skipPrecomputeStats = false; 
            end
            
            % Todo: Make as method of TwoPhotonSession class.
            
            % Get filepath for raw 2p-images
            DATANAME = 'TwoPhotonSeries_Original';
            filePath = obj.SessionObjects.getDataFilePath(DATANAME);
            
            % Initialize file reference for raw 2p-images
            rawStack = nansen.stack.ImageStack(filePath);
            return
            
            S = obj.getDefaultOptions();
            
            numFrames = rawStack.NumTimepoints;
            imageStats = obj.getImageStats(numFrames);
            
            % Todo: Can this be improved or made into a separate method?
            % Duplicate code: 
            %   Looping over parts
            %   Loading frames and saving image stats
          
            recastOutput = ~strcmp(rawStack.dataType, S.OutputDataType);
            isStatsComputed = all( ~isnan(imageStats.meanValue) );
            
            if recastOutput && ~isStatsComputed && ~skipPrecomputeStats
                
                fprintf('Collecting image statistics...')
                
                % Loop through chunks and save image stats for rawstack
                [numParts, frameIndices] = obj.getChunkSpecs(numFrames);
                tic
                
                %colShiftsFinal = zeros(numFrames,1);
                for iPart = 1:numParts
                    
                    IND = frameIndices{iPart};
                    if ~any( isnan(imageStats.meanValue(IND)) )
                        continue
                    end
                    
                    Y = rawStack.getFrameSet(IND);
                    Y = single(Y); % Cast to single
                
                    imageStats = obj.saveImageStats(Y, imageStats, IND);
                    
                    % todo: where and how to do this
%                     [Y, bidirBatchSize, colShifts] = correctLineOffsets(Y, 100);
%                     colShiftsFinal(IND) = colShifts;

                end
                toc
            end
            
        end
        
        % Todo: rename to open target stack
        function openOutputFile(obj, stackSize, dataType)

            % Get file reference for corrected stack
            DATANAME = 'TwoPhotonSeries_Corrected';
            
            filePath = obj.getDataFilePath( DATANAME );
            
            % Call method of ImageStackProcessor
            obj.openTargetStack(filePath, stackSize, dataType)
            
            % Make sure caching is turned off...
            obj.TargetStack.Data.UseDynamicCache = false;

        end
        
        % Todo: this should be done using save data method of iomodel
        function saveTiffStack(obj, DATANAME, imageArray)
            
            filePath = obj.getDataFilePath( DATANAME, '-w',...
                'Subfolder', 'image_registration', 'FileType', 'tif' );
                
            nansen.stack.utility.mat2tiffstack( imageArray, filePath )

        end
        
        % Todo: this should be done using load data method of iomodel
        function tiffStack = openTiffStack(obj, DATANAME, imageArray)
                        
            filePath = obj.getDataFilePath( DATANAME, '-w',...
                'Subfolder', 'image_registration', 'FileType', 'tif' );
            
            if ~isfile(filePath)
                nansen.stack.utility.mat2tiffstack( imageArray, filePath )
            end
            
            if nargout
                imageData = nansen.stack.open(filePath);
                tiffStack = nansen.stack.ImageStack(imageData);
            end
            
        end
        
        

        function initializeCorrectionStats(obj, numFrames)
            
        %   Save rigid shifts (x and y)
        %   Save rms movement of frames    

            % Check if imreg stats already exist for this session
            filePath = obj.getDataFilePath('imregStats', ...
                'Subfolder', 'image_registration');
            
            % Load or initialize
            if isfile(filePath)
                S = obj.loadData('imregStats');
            else
                nanArray = nan(numFrames, 1);
                
                S.offsetX = nanArray;
                S.offsetY = nanArray;
                S.rmsMovement = nanArray;

                obj.saveData('imregStats', S, ...
                    'Subfolder', 'image_registration');
            end
            
            obj.CorrectionStats = S;
            
        end% Rename initialize
        
        

        % Todo: This should be an external function!
        function S = getImageStats(obj, numFrames)
               
        % Question: Should S be implemented as table or struct?
        % Should it even be implemented as a class with a save method?
        
        % Todo: rename to initialize image stats?

            % Check if image stats already exist for this session
            filePath = obj.getDataFilePath('imageStats', ...
                'Subfolder', 'raw_image_info');
            
            if isfile(filePath)
                S = obj.loadData('imageStats');
            else
                
                nanArray = nan(numFrames, 1);
                    
                S = struct();
                
                S.meanValue = nanArray;
                S.medianValue = nanArray;
                S.minimumValue = nanArray;
                S.maximumValue = nanArray;

                pLevels = [0.05, 0.005];
                pLevels = [pLevels, 100-pLevels];

                S.percentileValues = pLevels;

                S.prctileL1 = nanArray;
                S.prctileL2 = nanArray;
                S.prctileU1 = nanArray;
                S.prctileU2 = nanArray;
                
                S.pctSaturatedValues = nanArray;

                obj.saveData('imageStats', S, ...
                    'Subfolder', 'raw_image_info');
                
            end

        end % Rename initialize
        
        % Todo: This should be an external function!
        function updateImageStats(obj, Y)
        %updateImageStats Get/save statistical values of image data
        %
        %   saveImageStats(obj, Y, S, IND)
            
        %   Question: Move this to a more general image processing class?
        
            S = obj.ImageStats;
            IND = obj.CurrentFrameIndices;
        
            % Test whether data already exists and return if so.
            if ~any( isnan(S.meanValue(IND)) )
                return
            end

            % Get plevels for getting prctile values from images.
            pLevels = S.percentileValues;
            
            % Reshape to 2D array where all pixels from each image is 1D
            Y_ = reshape(Y, [], size(Y, 3));
            
            % Collect different stats.
            bLims = prctile(Y_, pLevels)';
            if iscolumn(bLims); bLims = bLims'; end % If size(Y, 3)==1. 
            
            S.meanValue(IND) = nanmean( Y_ );
            S.medianValue(IND) = nanmedian( Y_ );
            S.minimumValue(IND) = min( Y_ );
            S.maximumValue(IND) = max( Y_ );
            
            S.prctileL1(IND) = bLims(:, 1);
            S.prctileL2(IND) = bLims(:, 2);
            S.prctileU1(IND) = bLims(:, 3);
            S.prctileU2(IND) = bLims(:, 4);
            
            saturationValue = 2^16; %Todo: Get from image type/class
            S.pctSaturatedValues(IND) = mean(Y_ == saturationValue);
            
            % Save updated image stats to session
            obj.saveData('imageStats', S)
            
            % Update property values
            obj.ImageStats = S;

        end % Rename updateImageStats
        

        
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
        
    end   
    
    methods (Static) % Method in external file (Get default options)
        
        S = getDefaultOptions()

    end

end