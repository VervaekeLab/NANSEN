classdef MotionCorrection < nansen.session.SessionMethod

    % Todo: 
    %   [ ] Implement a preprocessing function property, for preprocessing
    %       images before correction. Could be an alternative to running e.g
    %       stretch correction in the getframeSet method of the rawstack.
    %   [ ] Multichannel support
    %
    %   [ ] Move checkIfPartIsFinished method to stack.ChunkProcessor
    %   [ ] Move preview method to stack.ChunkProcessor (and rename to testrun/samplerun etc)
    %   [ ] Move saveTiffStack & openTiffStack to somewhere else (not sure where.)
    
    properties
       
        preprocessFcn = []
        
    end
    
    
    methods (Abstract)
        
        S = getToolboxSpecificOptions(obj, varargin)
        
        tf = checkIfPartIsFinished(obj, shiftsArray, frameIndices) % Protected?
        
        S = initializeShifts(obj, numFrames) % Protected?
        
        S = saveCorrectionStats(obj, S, shiftsArray, frameIndices)
        
        saveShifts(obj, shiftsArray)
        
        ref = initializeTemplate(obj, Y, opts);
                       
        [M, shifts, newRef] = correctMotion(obj, Y, opts, ref);
        
    end
    
    methods (Static, Abstract)
         shifts = addShifts(shifts, offset)
    end
    
    methods

        function runMethod(obj)
            obj.runMotionCorrection()
        end

    end
    
    
    methods % Implementation of abstract, public methods
        
        function tf = preview(obj)
            
            %CLASSNAME = class(obj);
            CLASSNAME = obj.getImviewerPluginName();
            pluginFcn = str2func(strjoin({'imviewer', 'plugin', CLASSNAME}, '.'));
           
            rawStack = openRawTwoPhotonStack(obj, true);
            
            hImviewer = imviewer(rawStack);
            
            h = pluginFcn(hImviewer, obj.Parameters);
            
            obj.Parameters = h.settings;
            
            hImviewer.quit()
            
            tf = true;
            
        end
        
    end
    
    methods (Access = protected)
               
        function opts = initializeOptions(obj, opts, optionsVarname)
        % Get filepath for saving options file to session folder
            iSession = obj.SessionObjects;
            filePath = iSession.getDataFilePath(optionsVarname, ...
                'Subfolder', 'image_registration');
            
            % And check whether it already exists on file...
            if isfile(filePath)
                optsOld = iSession.loadData(optionsVarname);
                
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
                iSession.saveData(optionsVarname, opts, ...
                    'Subfolder', 'image_registration')
            end
            
        end
                 
    end
    
    methods (Access = private)
        
        
        function [numParts, frameIndices] = getChunkSpecs(obj, numFrames)
                       
            numFramesPerPart = 500; % Todo: get from parameters.
            frameIndices = imviewer.ImageStack.getFrameIndices(numFrames, numFramesPerPart); % Todo: stack method?
            numParts = numel(frameIndices);
            
        end

        function partsToAlign = getPartsToAlign(obj, numFrames, shifts)
        %getPartsToAlign Get list of which parts to align.
        %
        %   Lets user specify a subset of parts to align. Also, if parts
        %   are aligned from before, they will be skipped, unless the Redo
        %   option is selected.
        
            opts = obj.getDefaultOptions(); % Todo: Get from user input / class property...
            [numParts, frameIndices] = obj.getChunkSpecs(numFrames);

            % Get the parts to align. Todo: create method for this?
            if ~isfield(opts, 'partsToAlign') || isempty(opts.partsToAlign)
                partsToAlign = 1:numParts;
            else
                partsToAlign = generalOpts.partsToAlign;
            end
            
            partsToSkip = [];
            for iPart = partsToAlign
                
                IND = frameIndices{iPart};
                
                % Checks if shifts already exist for this part
                isPartFinished = obj.checkIfPartIsFinished(shifts, IND);
                                
                if isPartFinished && ~opts.RedoAligning
                    partsToSkip = [partsToSkip, iPart]; %#ok<AGROW>
                end
            end

            partsToAlign = setdiff(partsToAlign, partsToSkip);
            
        end
        
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
            rawStack = imviewer.stack.open(filePath);
            
            S = obj.getDefaultOptions();
            
            numFrames = rawStack.numFrames;
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
        
        function correctedStack = openOutputFile(obj, stackSize, dataType)

            % Get file reference for corrected stack
            DATANAME = 'TwoPhotonSeries_Corrected';
            
            filePath = obj.SessionObjects.getDataFilePath( DATANAME );
            
            if ~isfile(filePath)
                correctedStack = imviewer.stack.open(filePath, stackSize, dataType);
            else
                correctedStack = imviewer.stack.open(filePath);
            end
            
            % Turn off caching, its not needed here.
            correctedStack.imageData.UseCache = false;

        end
        
        function saveTiffStack(obj, DATANAME, imageArray)
                        
            filePath = obj.SessionObjects.getDataFilePath( DATANAME, '-w',...
                'Subfolder', 'image_registration', 'FileType', 'tif' );
                
            mat2stack( imageArray, filePath )

        end
        
        function tiffStack = openTiffStack(obj, DATANAME, imageArray)
                        
            filePath = obj.SessionObjects.getDataFilePath( DATANAME, '-w',...
                'Subfolder', 'image_registration', 'FileType', 'tif' );
            
            if ~isfile(filePath)
                mat2stack( imageArray, filePath )
            end
            
            if nargout
                tiffStack = imviewer.stack.open(filePath);
            end
            
        end
        
        function S = getImageStats(obj, numFrames)
               
        % Question: Should S be implemented as table or struct?
        % Should it even be implemented as a class with a save method?
        
        % Todo: rename to initialize image stats?

            % Check if image stats already exist for this session
            iSession = obj.SessionObjects;
            filePath = iSession.getDataFilePath('imageStats', ...
                'Subfolder', 'raw_image_info');
            
            if isfile(filePath)
                S = iSession.loadData('imageStats');
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

                iSession.saveData('imageStats', S, ...
                    'Subfolder', 'raw_image_info');
                
            end

        end
        
        function S = getCorrectionStats(obj, numFrames)
            
        %   Save rigid shifts (x and y)
        %   Save rms movement of frames    

            % Check if imreg stats already exist for this session
            iSession = obj.SessionObjects;
            filePath = iSession.getDataFilePath('imregStats', ...
                'Subfolder', 'image_registration');
            
            % Load or initialize
            if isfile(filePath)
                S = iSession.loadData('imregStats');
            else
                nanArray = nan(numFrames, 1);
                
                S.offsetX = nanArray;
                S.offsetY = nanArray;
                S.rmsMovement = nanArray;

                iSession.saveData('imregStats', S, ...
                    'Subfolder', 'image_registration');
            end
            
        end
        
        function S = saveImageStats(obj, Y, S, IND)
        %saveImageStats Get/save statistical values of image data  
        %
        %   saveImageStats(obj, Y, S, IND)
            
        %   Question: Move this to a more general image processing class?
        
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
            iSession = obj.SessionObjects;
            iSession.saveData('imageStats', S)
            
        end
        
        function runMotionCorrection(obj)
                        
            % Todo: Get nansen-specific image registration options
            % Todo: Get these from input
            generalOpts = obj.getDefaultOptions();
            
            % Initialize file reference for raw 2p-images
            rawStack = obj.openRawTwoPhotonStack();
            
            % Store basic info about the raw image stack in local variables
            stackSize = size(rawStack.imageData);
            numFrames = stackSize(3);
            
            % Get options (preconfigs) for the normcorre registration
            %normcorreOpts = obj.getNormCorreOptions(stackSize);
            toolboxOpts = obj.getToolboxSpecificOptions(stackSize); %todo: different toolboxes might require different inputs.
            
            
            % Todo: get datatype from imreg settings.
            dataTypeIn = rawStack.dataType;
            dataTypeOut = generalOpts.OutputDataType;
            recastOutput = ~strcmp(dataTypeIn, dataTypeOut);
            
            % Open output file
            correctedStack = obj.openOutputFile(stackSize, dataTypeOut);
            
            % Initialize (or load) results
            shiftsArray = obj.initializeShifts(numFrames);
            imageStats = obj.getImageStats(numFrames);
            correctionStats = obj.getCorrectionStats(numFrames);

            % Get frame indices for each part/chunk to align
            [numParts, frameIndices] = obj.getChunkSpecs(numFrames);
            
            % Todo: Place in method?
            refName = 'MotionCorrectionReferenceImage'; %'MotionCorrectionTemplate'
            refArray = zeros( [stackSize(1:2), numParts], dataTypeIn);
            refStack = obj.openTiffStack(refName, refArray);
            
            refName = 'MotionCorrectedAverageProjections';
            avgProjStack = obj.openTiffStack(refName, refArray);
            refName = 'MotionCorrectedMaximumProjections';
            maxProjStack = obj.openTiffStack(refName, refArray);
            
            
%             toolboxOpts.bin_width = 200;
%             toolboxOpts.init_batch = 200;
%             toolboxOpts.upd_template = false;
            toolboxOpts.min_level = 6;
            % Get the parts to align.
            partsToAlign = obj.getPartsToAlign(numFrames, shiftsArray);

            % Loop through parts and run aligning.
            for iPart = partsToAlign
                
                iIndices = frameIndices{iPart};
                
                % Load data Todo: Make method. Two photon session method?
                Y = rawStack.getFrameSet(iIndices);

                minVal = prctile(imageStats.prctileL2, 5);
                Y = Y - minVal;
                
                Y = single(Y); % Cast to single for the alignment
                
                % Todo: Should this be here or baked into the
                % getRawStack/getframes method of rawstack?
                [Y, bidirBatchSize, colShifts] = correctLineOffsets(Y, 100);

                if ~isempty(obj.preprocessFcn)
                    % Todo: What inputs should be given to this function?
                    % I.e what are requirements for writing such a function
                    Y = obj.preprocessFcn(Y, iIndices, obj.sessionObjects);
                end
                
                imageStats = obj.saveImageStats(Y, imageStats, iIndices);

                % Get template for motion correction of current part
                if iPart == 1
                    ref = obj.initializeTemplate(Y, toolboxOpts); %<- todo: save initial template to session
                    P = obj.initializeParameters(Y, ref, toolboxOpts);

                elseif iPart ~= 1 && generalOpts.updateTemplate
                    ref = single( refStack.getFrameSet(iPart-1) );
                end
                
                if ~exist('P', 'var')
                    P = obj.initializeParameters(Y, ref, toolboxOpts);
                end
                
                % Run the motion correction on the current part.
                [M, shifts, newRef, P] = obj.correctMotion(Y, toolboxOpts, ref, P);
                
                % Add minval... % Todo: Check if this step is necessary...
                M = M + minVal;
                
                % Correct drift. % Todo: Make sure this does not leave
                % black edges!
                if iPart ~= 1 && generalOpts.correctDrift
                    %todo: fix this method... ie datatype internally
                    [M, drift] = obj.correctDrift(M, refStack);
                    ref = shiftStackSubres(ref, drift(1), drift(2), 4);

                    % Add drift to shifts.
                    shifts = obj.addShifts(shifts, drift);
                end
                
                % Write reference image to file.
                newRef = cast(newRef, dataTypeIn);
                refStack.writeFrameSet(iPart, newRef)
                
                
                % Save normcorre shifts to session
                % Todo: What if there are multiple channels?
                % Todo: Create method
                
                % Todo: Include this
% %                 shiftsArray(iIndices) = shifts;
% %                 obj.saveShifts(shiftsArray)
                
                % Save stats based on motion correction shifts
                correctionStats = obj.saveCorrectionStats(...
                    correctionStats, shifts, iIndices);
                
                % Save images to corrected stack (todo: place in method?)
                if recastOutput
                    % Todo: throw out outliers instead of using prctile?
                    minVal = prctile(imageStats.prctileL2, 5);
                    maxVal = max(imageStats.prctileU2);
                    
                    switch dataTypeOut
                        case 'uint8'
                            M_ = stack.makeuint8(M, [minVal, maxVal]);
                        otherwise
                            error('Not implemented yet')
                    end
                else
                    M_ = cast(M, dataTypeIn);
                end
                
                correctedStack.writeFrameSet(iIndices, M_)
                
                
                % Save reference and projections
                if generalOpts.saveAverageProjection
                    avgProj = mean(M, 3);
                    avgProj = cast(avgProj, dataTypeIn);
                    avgProjStack.writeFrameSet(iPart, avgProj)
                end
                
                if generalOpts.saveMaximumProjection
                    % Filter using okada before getting the max.
                    M = stack.process.filter3.okada(M);
                    maxProj = max(M, [], 3);
                    maxProj = cast(maxProj, dataTypeIn);
                    maxProjStack.writeFrameSet(iPart, maxProj)
                end
                
                % Todo: Check other pipelines to see if there are any smart
                % stats/image projections that can be saved at this stage.
                
            end
            
            % Compute full stack projections. Mean, max, std etc.
            
            maxX = max(correctionStats.offsetX);
            maxY = max(correctionStats.offsetY);
            crop = round( max([maxX, maxY])*1.5 );
           
            % Save reference images to 8bit
            imArray = refStack.getFrameSet(1:numParts);
            imArray = stack.makeuint8(imArray);
            obj.saveTiffStack('MotionCorrectionTemplates8bit', imArray)

            % Save average and maximum projections as 8-bit stacks.
            if generalOpts.saveAverageProjection
                imArray = avgProjStack.getFrameSet(1:numParts);
                imArray = stack.makeuint8(imArray, [], [], crop); % todo: Generalize this function / add tolerance as input
            	obj.saveTiffStack('MotionCorrectedAverageProjections8bit', imArray)
            end
            
            if generalOpts.saveMaximumProjection
                imArray = maxProjStack.getFrameSet(1:numParts);
                imArray = stack.makeuint8(imArray, [], [], crop); % todo: Generalize this function / add tolerance as input
                obj.saveTiffStack('MotionCorrectedMaximumProjections8bit', imArray)
            end
            
        end
        
        function [M, shifts] = correctDrift(obj, M, refStack)
            
            % Todo: improve function....
            % Todo: shiftStackSubRes is not part of pipeline.....
            
            % Only need to do this first time...
            sessionRef = refStack.getFrameSet(1);

            options_rigid = NoRMCorreSetParms('d1', size(M,1), 'd2', size(M,2), ...
                'bin_width', 50, 'max_shift', 20, 'us_fac', 50, ...
                'correct_bidir', false, 'print_msg', 0);
            
            [~, nc_shifts, ~,~] = normcorre(mean(M, 3), options_rigid, sessionRef);
            dx = arrayfun(@(row) row.shifts(2), nc_shifts);
            dy = arrayfun(@(row) row.shifts(1), nc_shifts);
            %frameShifts(firstFrame:lastFrame, 1) = frameShifts(firstFrame:lastFrame, 1) + dx;
            %frameShifts(firstFrame:lastFrame, 2) = frameShifts(firstFrame:lastFrame, 2) + dy;
            M = shiftStackSubres(M, dx, dy, 4);
            
            shifts = [dx, dy];
        
        end
        
    end
    
    
    methods (Static)
        
        function S = getDefaultOptions()
            
            % Big todo. Implement this in same way as getNormCorreOptions
            %   Also, expand the normcorre options (nansen version) 
            %   to include these.
            
            S = struct();
            
            S.NumFlybackLines = 0;  % Remove lines in top of image (if the flyback is sampled)
            S.BidirectionalCorrection = 'None';
            S.BidirectionalCorrection_ = {'None', 'Constant', 'Time Dependent'};
            S.correctDrift = false;

            S.numFramesPerPart = 1000;
            
            S.OutputDataType = 'uint8';
            S.OutputDataType_ = {'uint8', 'uint16', 'uint32'};
            S.OutputFileFormat = 'raw';
            S.saveAverageProjection = true;
            S.saveMaximumProjection = true;

            
            S.RedoAligning = false;  % Redo aligning if it already was performed...
            S.partsToAlign = [];

            S.updateTemplate = true;
            S.frameNumForInitialTemplate = 1:200;
            

            S.RecastOutput = true; % Internal...
            
        end

    end

end