classdef Denoiser < nansen.stack.ImageStackProcessor
%Denoiser Processor for denoising an ImageStack using DeepInterpolation
%
%   This method is developed based on the example in the
%   Tiny Ophys Inference Example livescript from the
%   DeepInterpolation-MATLAB (1) GitHub repository. The DeepInterpolation
%   method is developed by the Allen Institute and the code is available
%   here: https://github.com/AllenInstitute/deepinterpolation
%
%   (1) https://github.com/MATLAB-Community-Toolboxes-at-INCF/DeepInterpolation-MATLAB
    
    properties (Constant) % Attributes inherited from nansen.processing.DataMethod
        MethodName = 'Deep Interpolation (Denoise Stack)'
        IsManual = false        % Does method require manual supervision?
        IsQueueable = true      % Can method be added to a queue?
        OptionsManager nansen.manage.OptionsManager = ...
            nansen.OptionsManager(mfilename('class'))
    end

    properties (Constant, Hidden)
        DATA_SUBFOLDER = ''	% defined in nansen.processing.DataMethod
        VARIABLE_PREFIX	= '' % defined in nansen.processing.DataMethod
    end
    
    properties (Access = private)
        DeepInterpolationNet
        OriginalFrameSize
        OriginalDataType
        NormalizationMeanImage
        NormalizationStdImage
    end

    properties (Access = protected)
        TargetFrameIndPerPart
    end

    methods (Static)
        
        function S = getDefaultOptions()
        % Get default options for the deep interpolation denoiser.
            S.DeepInterpolation.PrePostOmission = 0; % 0-4;
            S.DeepInterpolation.PreFrame = 30; % Fixed number of frames before the predicted frame
            S.DeepInterpolation.PostFrame = 30; % Fixed number of frames after the predicted frame
            
            S.DeepInterpolation.PrePostOmission_ = struct('type', 'slider', ...
                'args', {{'Min', 0, 'Max', 4, 'nTicks', 4, 'TooltipPrecision', 0}});
            S.DeepInterpolation.PreFrame_ = struct('type', 'slider', ...
                'args', {{'Min', 1, 'Max', 30, 'nTicks', 29, 'TooltipPrecision', 0}});
            S.DeepInterpolation.PostFrame_ = struct('type', 'slider', ...
                'args', {{'Min', 1, 'Max', 30, 'nTicks', 29, 'TooltipPrecision', 0}});
            
            className = mfilename('class');
            superOptions = nansen.mixin.HasOptions.getSuperClassOptions(className);
            S = nansen.mixin.HasOptions.combineOptions(S, superOptions{:});
        end
    end
    
    methods % Constructor
        
        function obj = Denoiser(sourceStack, varargin)

            obj@nansen.stack.ImageStackProcessor(sourceStack, varargin{:})
            
            if ~nargout
                obj.runMethod()
                clear obj
            end
        end
    end

    methods (Access = protected) % Override ImageStackProcessor methods
        
        function onInitialization(obj)
        %onInitialization Custom code to run on initialization.
            obj.configureOutputStack()
            obj.initializeNetwork()
        end

        function configureImageStackSplitting(obj)
        %configureImageStackSplitting Custom image stack splitting.
        %
        %   The denoiser interpolates a target frame based on surrounding
        %   frames. Based on the window size of surrounding frames to use,
        %   each chunk/subpart of the imagestack needs to be "padded" with
        %   some extra frames.

            configureImageStackSplitting@nansen.stack.ImageStackProcessor(obj)

            preFrame = obj.Options.DeepInterpolation.PreFrame; % Fixed number of frames before the predicted frame
            postFrame = obj.Options.DeepInterpolation.PostFrame;
            
            prePostOmission = obj.Options.DeepInterpolation.PrePostOmission;
 
            numFramesPre = preFrame + prePostOmission;
            numFramesPost = postFrame + prePostOmission;

            numFrames = obj.SourceStack.NumTimepoints;

            % Pad each chunk with extra frames.
            for i = 1:numel(obj.FrameIndPerPart)
                partInd = obj.FrameIndPerPart{i};
                % Save original indices in the TargetFrameIndPerPart prop
                obj.TargetFrameIndPerPart{i} = partInd;
                
                firstFrameIndex = partInd(1);
                lastFrameIndex = partInd(end);

                % Make sure new indices does not exceed image stack
                % boundaries
                newFirstFrameIndex = max([1, firstFrameIndex-numFramesPre]);
                newLastFrameIndex = min([numFrames, lastFrameIndex+numFramesPost]);

                % Update the frame indices per part property with new
                % indices
                obj.FrameIndPerPart{i} = newFirstFrameIndex:newLastFrameIndex;
            end
        end

        function iIndices = getTargetIndices(obj, ~)
        %getTargetIndices Get downsampled target indices
            iPart = obj.CurrentPart;
            iIndices = obj.TargetFrameIndPerPart{iPart};
        end
    end

    methods (Access = protected) % Method for processing each part

        function [Y, results] = processPart(obj, Y, ~)
            
            Y = obj.preprocessImageSubstack(Y);

            % Unless this is the first or last part, Y is bigger than what
            % the output will be.

            absSourceFrameIndices = obj.CurrentFrameIndices;
            absTargetFrameIndices = obj.getTargetIndices();

            % These are absolute stack indices. Adjust so that they are
            % relative to the indices for the current part.
            frameOffset = min(absSourceFrameIndices) - 1;
            targetFrameIndices = absTargetFrameIndices - frameOffset;

            chunkSize = size(Y);
            chunkSize(3) = numel(targetFrameIndices);
            
            % Create new array for holding output data.
            YOut = zeros(chunkSize, 'like', Y);
            
            % Note: iFrame is the frame relative to the output data,
            % whereas targetFrameIndices are relative to the input data
            % (i.e the data with extra "padded" frames).

            for iFrame = 1:numel(targetFrameIndices)
                
                targetFrameIdx = targetFrameIndices(iFrame);
                predictionFrameIndices = obj.getPredictionFrameIndices(targetFrameIdx);
            
                if isempty(predictionFrameIndices)
                    YOut(:,:,iFrame) = nan;
                    continue
                end

                disp(absTargetFrameIndices(iFrame))

                % Perform DeepInterpolation
                try
                    predictionImages = Y(:,:,predictionFrameIndices);
                    YOut(:,:,iFrame) = predict(obj.DeepInterpolationNet, predictionImages);
                catch
                    warning('Problem using predict.  Returning nan.');
                    YOut(:,:,iFrame) = nan;
                end
            end

            Y = obj.postprocessImageSubstack(YOut);
            results = struct;
        end
    end

    methods (Access = private)
    
        function configureOutputStack(obj)
        %createOutputStack Configure and create the output stack.
        %
        %   Note: If stack exists from before, new stack is not created.
        
            % Create output filepath
            [~, sourceName] = fileparts( obj.SourceStack.FileName );
            targetName = strcat(sourceName, '_denoised');
            
            % NB: outputs the same data type...
            targetFilepath = strrep(  obj.SourceStack.FileName, sourceName, targetName );

            % Get new size
            stackSize = size( obj.SourceStack.Data );

            % Get data type from source stack
            dataTypeOut = obj.SourceStack.DataType;

            obj.openTargetStack(targetFilepath, stackSize, dataTypeOut, ...
                'DataDimensionArrangement', obj.SourceStack.Data.StackDimensionArrangement);
        
        end

        function initializeNetwork(obj)
        %initializeNetwork Initialize the DeepInterpolation pre-trained network
        %
        %   Note: This method uses the pre-trained network provided by the
        %   original paper/results for two-photon data.

            % Download if not present.
            modelFileName = obj.getModelFilePath;
            if ~isfile(modelFileName)
                obj.downloadModel()
            end
            
            s = ver('MATLAB'); %#ok<VERMATLAB>
            releaseName = regexp(s.Release, '(?<=\().*(?=\))', 'match', 'once');
            supportPackageDirectory = fullfile(userpath, 'SupportPackages', releaseName);
            if ~contains(path, supportPackageDirectory)
                addpath(genpath(supportPackageDirectory))
            end

            importednet = importKerasLayers(modelFileName,'ImportWeights',true);

            placeholders = findPlaceholderLayers(importednet);
            %disp(placeholders)

            regressionnet = replaceLayer(importednet, placeholders.Name , maeRegressionLayer);
            obj.DeepInterpolationNet = assembleNetwork(regressionnet);
        end
        
        function Y = preprocessImageSubstack(obj, Y)
        %preprocessImageSubstack Preprocess each chunk of images

            obj.OriginalFrameSize = size(Y);
            obj.OriginalDataType = class(Y);

            % Expand frame size to 512 x 512 pixels to match expected input
            % size of the pretrained model.
            Y = stack.reshape.imexpand(Y, [512,512]);

            Y = single(Y);

            [Y, C, S] = normalize(Y, 3, "center", "mean", "scale", "std"); % where C = mean, S = std

            obj.NormalizationMeanImage = C;
            obj.NormalizationStdImage = S;
        end

        function Y = postprocessImageSubstack(obj, Y)
        %postProcessImageSubstack Postprocess each chunk of images

            C = obj.NormalizationMeanImage;
            S = obj.NormalizationStdImage;

            % Rescale images
            Y = (Y .* S)+C;

            % Crop images to original size.
            Y = stack.reshape.imcropcenter(Y, obj.OriginalFrameSize);

            Y = cast(Y, obj.OriginalDataType);

            Y(isnan(Y)) = 0;
        end
    
        function predictionFrameIndices = getPredictionFrameIndices(obj, targetFrameIdx)
        %getPredictionFrameIndices Get indices for prediction of a target
        %
        %   Based on the number of pre-frames and post-frames as well as
        %   the frames to omit, this function returns indices for a set of
        %   frames to use for the DeepInterpolation prediction of a target
        %   frame.
        %
        %   Input:
        %       targetFrameIdx - Integer representing the frame index of
        %       the target frame.

            numPreFrames = obj.Options.DeepInterpolation.PreFrame;
            numPostFrames = obj.Options.DeepInterpolation.PostFrame;
            numPrePostOmission = obj.Options.DeepInterpolation.PrePostOmission;

            firstPredictionIdx = targetFrameIdx - numPreFrames - numPrePostOmission;
            lastPredictionIdx = targetFrameIdx + numPostFrames + numPrePostOmission;

            predictionFrameIndices = firstPredictionIdx : lastPredictionIdx;
            
            % Drop the omitted frames before prediction
            prePostOmissionIndices = targetFrameIdx-numPrePostOmission : targetFrameIdx+numPrePostOmission; % index of frames to be dropped
            predictionFrameIndices = setdiff(predictionFrameIndices, prePostOmissionIndices);
        
            % If any prediction indices are out of range, we don't make a
            % prediction
            if any(predictionFrameIndices < 1)
                predictionFrameIndices = [];
            end

            if any(predictionFrameIndices > numel(obj.CurrentFrameIndices))
                predictionFrameIndices = [];
            end
        end
    end

    methods (Static, Access = public)
        function modelFilePath = getModelFilePath()
            modelSaveDirectory = fullfile(userpath, 'DeepInterpolation-MATLAB', 'model');
            modelFilename = '2019_09_11_23_32_unet_single_1024_mean_absolute_error_Ai93-0450.h5';
            modelFilePath = fullfile(modelSaveDirectory, modelFilename);
        end

        function downloadModel()
            modelFilePath = nansen.stack.processor.Denoiser.getModelFilePath();
            modelSaveDirectory = fileparts(modelFilePath);

            modelUrl = "https://www.dropbox.com/sh/vwxf1uq2j60uj9o/AAC0sZWahCJFBRARoYsw8Nnra/2019_09_11_23_32_unet_single_1024_mean_absolute_error_Ai93-0450.h5?dl=1";
            if ~isfolder(modelSaveDirectory); mkdir(modelSaveDirectory); end
            
            %fex.filedownload.downloadFile(modelSavepath, modelUrl)
            disp('Downloading deep interpolation model, please wait a moment.')
            websave(modelFilePath, modelUrl);
            disp('Finished download')

            % Download regression layer
            mFileUrl = 'https://raw.githubusercontent.com/MATLAB-Community-Toolboxes-at-INCF/DeepInterpolation-MATLAB/main/network_layers/maeRegressionLayer.m';
            classdefStr = webread(mFileUrl);
            savePath = fullfile(modelSaveDirectory, 'maeRegressionLayer.m');
            %filewrite(savePath, classdefStr);
            fid = fopen(savePath, 'w');
            fwrite(fid, classdefStr);
            fclose(fid);
            addpath(modelSaveDirectory)
        end
    end
end
