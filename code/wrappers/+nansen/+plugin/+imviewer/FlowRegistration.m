classdef FlowRegistration < imviewer.ImviewerPlugin & applify.mixin.ModalMethodPreviewController & nansen.processing.MotionCorrectionPreview
%FlowRegistration Preview Flow Registration motion correction in imviewer.
%
%   FlowRegistration is an imviewer plugin for adjusting Flow Registration
%   parameters, previewing filtered image data, and launching motion
%   correction for the current image stack.
%
%   SYNTAX:
%       flowregPlugin = nansen.plugin.imviewer.FlowRegistration(imviewerHandle)
%       flowregPlugin = nansen.plugin.imviewer.FlowRegistration(imviewerHandle, options)
%       flowregPlugin = nansen.plugin.imviewer.FlowRegistration(imviewerHandle, options, Name, Value, ...)

% Todo: Use methods of flowreg processor to run prealigning?

    properties (Constant)
        Name = 'Flow Registration'      % Name of plugin
    end

    properties (Hidden)
        TargetFolderName = 'motion_correction_flowreg';
    end

    properties
        TestResults struct      % Store results from a pretest correction
    end

    properties (Access = private)
        frameChangeListener
    end

    methods % Structors

        function obj = FlowRegistration(imviewerHandle, varargin)
        %FlowRegistration Create a Flow Registration plugin for an imviewer app.
        %
        %   flowregPlugin = FlowRegistration(imviewerHandle) creates the
        %   plugin using default Flow Registration options.
        %
        %   flowregPlugin = FlowRegistration(imviewerHandle, options, Name, Value, ...)
        %   creates the plugin using a struct or nansen.manage.OptionsManager
        %   for options. Remaining arguments are plugin flags or property-value
        %   pairs, such as '-p' for partial construction.

            arguments
                imviewerHandle applify.AppWithPlugin
            end
            arguments (Repeating)
                varargin
            end

            [options, pluginArgs] = ...
                applify.mixin.HasOptionsManager.splitOptionsArgument(varargin);

            obj@applify.mixin.ModalMethodPreviewController(options)
            obj@imviewer.ImviewerPlugin(imviewerHandle, pluginArgs{:})

            if ~obj.PartialConstruction
                obj.openControlPanel()
            end

            if ~nargout; clear obj; end
        end

        function delete(obj)
            % pass
        end
    end

    methods

        function sEditor = openOptionsEditor(obj)
        %openOptionsEditor Open editor for method options.

            % Update folder- and filename in options.
            [folderPath, fileName] = fileparts( obj.ImviewerObj.ImageStack.FileName );
            folderPath = fullfile(folderPath, obj.TargetFolderName);

            % Prepare default filename
            fileName = obj.buildFilenameWithExtension(fileName);

            obj.Options_.Export.SaveDirectory = folderPath;
            obj.Options_.Export.FileName = fileName;

            sEditor = openOptionsEditor@applify.mixin.ModalMethodPreviewController(obj);
            obj.arrangeAppWindows(sEditor)

            % Need a better solution for this:
            idx = strcmp(sEditor.Name, 'Export');
            sEditor.dataOrig{idx}.SaveDirectory = folderPath;
            sEditor.dataEdit{idx}.SaveDirectory = folderPath;

            sEditor.dataOrig{idx}.FileName = fileName;
            sEditor.dataEdit{idx}.FileName = fileName;
        end

        function openControlPanel(obj)
            obj.initializeGaussianFilter()
            obj.editOptions()
        end

        function run(obj)
            obj.runAlign()
        end

        function runTestAlign(obj)

            % Check if saveResult or showResults is selected
            obj.assertPreviewOptionsValid()

            % Prepare save directory
            if obj.Options.Preview.saveResults
                [saveFolder, datePrefix] = obj.prepareSaveFolder();
                if isempty(saveFolder); return; end
            end

            % Get image data
            Y = obj.loadSelectedFrameSet();

            imClass = class(Y);
            %stackSize = size(Y);

            import nansen.wrapper.flowreg.*
            options = Options.convert(obj.Options);

            if ~isa(Y, 'single') || ~isa(Y, 'double')
                Y = single(Y);
            end

            [Y, bidirBatchSize, colShifts] = nansen.wrapper.normcorre.utility.correctLineOffsets(Y, 100);

            obj.ImviewerObj.displayMessage('Running FlowRegistration...')

            ref = obj.initializeTemplate(Y, options); %<- todo: save initial template to session
            P = obj.initializeParameters(Y, ref, options);
            [M, shifts] = obj.correctMotion(Y, options, ref, P);

            % Todo: Gather some results...
            % obj.TestResults

            M = cast(M, imClass);
            M = squeeze(M);
            obj.ImviewerObj.clearMessage;

            % Show results from test aligning:
            if obj.Options.Preview.showResults
                h = imviewer(M);
                h.stackname = sprintf('%s - %s', obj.ImviewerObj.stackname, 'Flowreg Test Correction');
            end

         	% Save results from test aligning:
            if obj.Options.Preview.saveResults
                getSavepath = @(name) fullfile(saveFolder, ...
                    sprintf('%s_%s', datePrefix, name ) );

                save(getSavepath('flowreg_shifts.mat'), 'shifts')
                save(getSavepath('flowreg_opts.mat'), 'options')

                obj.saveProjections(Y, M, getSavepath)
            end
        end

        function runAlign(obj)
         %runAlign Run correction on full image stack using a "single folder
         %dataset"
            dataSet = obj.prepareTargetDataset();

            obj.ImviewerObj.displayMessage('Running motion correction with Flowregistration...')
            drawnow
            cleanupObj = onCleanup(@() obj.ImviewerObj.clearMessage());

            nansen.wrapper.flowreg.Processor(obj.ImviewerObj.ImageStack, ...
                obj.Options, 'DataIoModel', dataSet)
        end
    end

    methods (Access = protected) % Plugin derived methods

        function createSubMenu(obj)
        %createSubMenu Create sub menu items for the plugin
            % Nothing here yet
        end

        function onOptionsEditorClosed(obj)
        %onOptionsEditorClosed "Callback" for when options editor exits
            obj.resetGaussianFilter()
        end

        function assignDefaultOptions(obj)
            functionName = 'nansen.wrapper.flowreg.Processor';
            obj.OptionsManager = nansen.manage.OptionsManager(functionName);

            obj.Options = obj.OptionsManager.getOptions;
        end
    end

    methods (Access = private)

        function initializeGaussianFilter(obj)
            obj.ImviewerObj.imageDisplayMode.filter = 'gauss3d';
            obj.ImviewerObj.imageDisplayMode.filterParam = struct('sigma', obj.Options.General.sigmaX);
            obj.ImviewerObj.updateImage();
            obj.ImviewerObj.updateImageDisplay();
        end

        function resetGaussianFilter(obj)
            obj.ImviewerObj.imageDisplayMode.filter = 'none';
            obj.ImviewerObj.imageDisplayMode.filterParam = [];
            obj.ImviewerObj.updateImage();
            obj.ImviewerObj.updateImageDisplay();
        end

        function plotFlowField(obj, ~, ~)

            % Convert shifts indices to x,y coordinates

            iFrame = obj.ImviewerObj.currentFrameNo;
            if iFrame > numel(obj.shifts); return; end

            tmpShifts = obj.TestResults.shifts(iFrame).shifts_up;

            %TODO.
        end

        function updateResults(obj)
            % Todo
        end
    end

    methods % Flowreg wrappers (copied from session method)

        function template = initializeTemplate(obj, imArray, options)

            % Todo: get frames based on options.frameNumForInitialTemplate

            if ~options.verbose
                disp('Preregistering reference frames...');
            end

            % Raw images, reshaped to H x W x nCh x nSamples
            Y = obj.reshapeImageArray(imArray);

            % Channel weightings
            weight_2d = obj.getFlowregChannelWeights(Y, options);

            % Preprocess images
            C1 = obj.getFilteredImageArray(Y, options, 'sigmaOffset', [1 1 0.5]);

            % Get a motion corrected image array
            CRef = mean(C1, 4);
            YRef = mean(Y, 4);
            [CReg, ~] = obj.compensateSequence(C1, CRef, Y, YRef, options, weight_2d);

            % Create template from mean projection of corrected image array
            template = mean(CReg, 4);

            template = squeeze(template);

            if ~options.verbose
                disp('Finished pre-registration of the reference frames...');
            end
        end

        function params = initializeParameters(obj, imArray, initTemplate, options)

            % Raw images, reshaped to H x W x nCh x nSamples
            Y = obj.reshapeImageArray(imArray);

            % Channel weightings
            weight = obj.getFlowregChannelWeights(Y, options);

            % Create normalized array from subset of imArray
            YSubset = Y(:, :, :, 1:min(22, size(imArray, 4)));
            CSubset = obj.getFilteredImageArray(YSubset, options);

            % Get a filtered reference image...
            Ygauss = imgaussfilt3_multichannel(Y, options);
            c_ref = obj.getFilteredImageArray(initTemplate, options, ...
                'normalizationRef', Ygauss);

            % Get initial shifts based on a subset of the images
            nvPairs = {'weight', weight};
            shifts = obj.getDisplacements(CSubset, c_ref, options, nvPairs{:});

            params.initialShifts = mean(shifts, 4);
            params.cRef = c_ref;
        end

        function [M, shifts] = correctMotion(obj, Y, options, templateIn, params)

            % What is the difference between cref and cref raw???

            % Raw images, reshaped to H x W x nCh x nSamples
            Y = obj.reshapeImageArray(Y);

            % Channel weightings
            weight = obj.getFlowregChannelWeights(Y, options);

            c1 = obj.getFilteredImageArray(mat2gray(Y), options);

            w_init = params.initialShifts;
            c_ref = params.cRef;
            nvPairs = {'weight', weight, 'uv', w_init(:, :, 1), w_init(:, :, 2)};
            shifts = obj.getDisplacements(c1, c_ref, options, nvPairs{:});

            M = compensate_sequence_uv( Y, templateIn, shifts );
        end
    end

    methods (Access = protected)

        % Todo: Combine these into one method

        function onOptionsChanged(obj, name, value)

            % Call superclass method to deal with options that are
            % general motion correction options.
            onOptionsChanged@nansen.processing.MotionCorrectionPreview(obj, name, value)

            switch name

                case 'symmetricKernel'
                    obj.Options.General.symmetricKernel = value;

                case {'sigmaX', 'sigmaY'}
                    if obj.Options.General.symmetricKernel
                        obj.Options.General.sigmaX = value;
                        obj.Options.General.sigmaY = value;
                    else
                        obj.Options.General.(name) = value;
                    end

                    obj.Options.Model.sigma = [obj.Options.General.sigmaY, obj.Options.General.sigmaX, obj.Options.General.sigmaZ];
                    obj.ImviewerObj.imageDisplayMode.filterParam = struct('sigma', obj.Options.Model.sigma);
                    obj.ImviewerObj.updateImage();
                    obj.ImviewerObj.updateImageDisplay();

                case 'sigmaZ'
                    obj.Options.Model.sigma = [obj.Options.General.sigmaY, obj.Options.General.sigmaX, obj.Options.General.sigmaZ];
                    obj.ImviewerObj.imageDisplayMode.filterParam = struct('sigma', obj.Options.Model.sigma);
                    obj.ImviewerObj.updateImage();
                    obj.ImviewerObj.updateImageDisplay();

                case 'FileName'
                    obj.Options.Export.FileName = value;
                    %obj.Options_.Export.FileName = value;
            end
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

        function weight = getFlowregChannelWeights(Y, options)

            n_channels = size(Y, 3);

            % setting the channel weight
            weight = [];
            for i = 1:n_channels
                weight(:, :, i) = options.get_weight_at(i, n_channels);
            end
        end

        function C1 = getFilteredImageArray(Y, options, varargin)
        %getFilteredImageArray Get 3D gaussian filtered grayscale images
        %
        %   Applies a 3D gaussian filter on the image array and converts
        %   the output to a grayscale image array.

            defaultNvPairs = struct(...
                'sigmaOffset', [0,0,0], ...
                'normalizationRef', [] );

            nvPairs = utility.parsenvpairs(defaultNvPairs, 1, varargin);

            % Filter input image array using 3d gaussian filter
            Y = imgaussfilt3_multichannel(Y, options, nvPairs.sigmaOffset);

            % Convert output to grayscale image array with values in [0,1]
            if strcmp(options.channel_normalization, 'separate')
                if ~isempty(nvPairs.normalizationRef)
                    C1 = mat2gray_multichannel(Y, nvPairs.normalizationRef);
                else
                    C1 = mat2gray_multichannel(Y);
                end
            else
                if ~isempty(nvPairs.normalizationRef)
                    min_ref = double(min( nvPairs.normalizationRef(:) ));
                    max_ref = double(max( nvPairs.normalizationRef(:) ));

                    C1 = (Y - min_ref) / (max_ref - min_ref);
                    % C1 = mat2gray(Y, [min_ref, max_ref]); Same result?
                else
                    C1 = mat2gray(Y);
                end
            end
        end

        function [YReg, shifts] = compensateSequence(C, CRef, Y, YRef, options, weight)
        %compensateSequence Wrapper for compensate_sequence

        % Todo: Do I need these from inputs??
% %             CRef = mean(C, 4);
% %             YRef = mean(Y, 4);

            [YReg, shifts] = compensate_sequence( ...
                    C, CRef, Y, YRef, ...
                    'weight', weight, ...
                    'alpha', options.alpha + 2, ...
                    'levels', options.levels, ...
                    'min_level', options.min_level, ...
                    'eta', options.eta, ...
                    'update_lag', options.update_lag, ...
                    'iterations', options.iterations, ...
                    'a_smooth', options.a_smooth, ...
                    'a_data', options.a_data);
        end

        function shifts = getDisplacements(C, CRef, options, varargin)
        %getDisplacements Wrapper for get_displacements

                shifts = get_displacements( ...
                    C, CRef, ...
                    'sigma', 0.001, ...
                    'alpha', options.alpha, ...
                    'levels', options.levels, ...
                    'min_level', options.min_level, ...
                    'eta', options.eta, ...
                    'update_lag', options.update_lag, ...
                    'iterations', options.iterations, ...
                    'a_smooth', options.a_smooth, ...
                    'a_data', options.a_data, ...
                    varargin{:});
        end
    end
end
