classdef FlowRegistration < uim.handle % & applify.mixin.UserSettings
    
    % Todo: migrate plugin to new instance if results open in new window
    
    % create a wrapper class..??
    % imviewer plugin and the flowreg sessionmethod should inherit from it.
    %
    % use same model for normcorre and potentially other toolboxes...
    
    
    % Todo: Start from file/session/imviewer
    %   [] Add fileref property
    %   [] Add session ref property (or combine with previous)
    %   [] Implement options based on OptionsManager & normcorre options.
    %   [ ] Improve implementation of options! Right now its not very
    %       clear how data is flowing...
    
    properties (Constant, Hidden = true)
        USE_DEFAULT_SETTINGS = false        % Ignore settings file
        DEFAULT_SETTINGS = struct.empty;
    end
    
    properties
        imviewerRef
        shifts
        opts
        
        wasAborted

        
        settings
        settingsName

    end
    
    properties (Access = private)
        
        
        %hShiftArrows
        %mItemPlotResults
        
        frameChangeListener
        
    end
    
    
    methods
        
        function obj = FlowRegistration(hViewer, optsStruct)
            
            PLUGINNAME = 'flowreg';
            
            if any( contains({hViewer.plugins.pluginName}, PLUGINNAME) )
                IND = contains({hViewer.plugins.pluginName}, PLUGINNAME);
                obj = hViewer.plugins(IND).pluginHandle;
                %return;
            else
                hViewer.plugins(end+1).pluginName = PLUGINNAME;
                hViewer.plugins(end).pluginHandle = obj;  
                obj.imviewerRef = hViewer;
                %obj.loadSettings()
                
                if nargin < 2 || isempty(optsStruct)
                    obj.settings = nansen.OptionsManager('nansen.module.flowreg.Processor').getOptions;
                else
                    obj.settings = optsStruct;
                end
                %obj.addMenuItem()
            end
            

            obj.initializeGaussianFilter()
            obj.editSettings()
            
            if ~nargout; clear obj; end

        end
        
        
        function delete(obj)

        end
        
        
% %         function addMenuItem(obj)
% %             
% %             m = findobj(obj.imviewerRef.Figure, 'Text', 'Align Images');
% %             
% %             obj.mItemPlotResults = uimenu(m, 'Text', 'Plot NoRMCorre Shifts', 'Enable', 'off');
% %             obj.mItemPlotResults.Callback = @obj.plotResults;
% %             
% %         end
        
        
        function runTestAlign(obj)
            %Todo:

            % Get images
            firstFrame = obj.settings.Preview.firstFrame;
            lastFrame = (firstFrame-1) + obj.settings.Preview.numFrames;
            
            obj.imviewerRef.displayMessage('Loading Data...')
            Y = obj.imviewerRef.imageStack.imageData(:, :, firstFrame:lastFrame);
            
            
            imClass = class(Y);

            Y = Y(8:end, :, :);
            
            %Y = stack.makeuint8(Y);

            
            % Get normcorre settings
            %[d1,d2,d3] = size(Y);
            
            stackSize = size(Y);
            
            import nansen.adapter.flowreg.*
            options = Options.convert(obj.settings);
            
            
            if ~isa(Y, 'single') || ~isa(Y, 'double') 
                Y = single(Y);
            end
            
            
            obj.imviewerRef.displayMessage('Running FlowRegistration...')

            
            ref = obj.initializeTemplate(Y, options); %<- todo: save initial template to session
            P = obj.initializeParameters(Y, ref, options);
            M = obj.correctMotion(Y, options, ref, P);

            % Todo: use session method????
            %[M, ncShifts, ref] = normcorre_batch(Y, options);
            
            %obj.shifts = ncShifts;
            %obj.opts = options;
            
            %obj.mItemPlotResults.Enable = 'on';
            
            M = cast(M, imClass);
            M = squeeze(M);
            obj.imviewerRef.clearMessage;
            
            
            if obj.settings.Preview.openResultInNewWindow
                imviewer(M)
                
            else
                filePath = obj.imviewerRef.imageStack.filePath;
                delete(obj.imviewerRef.imageStack)
                
                obj.imviewerRef.imageStack = imviewer.ImageStack(M);
                obj.imviewerRef.imageStack.filePath = filePath;
                obj.imviewerRef.updateImage();
                obj.imviewerRef.updateImageDisplay();
                
                obj.mItemPlotResults.Enable = 'on';
                
            end
            
% %             if ~isempty(obj.settings.Export.PreviewSaveFolder)
% %                 
% %                 saveDir = obj.settings.Export.PreviewSaveFolder;
% %                 if ~exist(saveDir, 'dir'); mkdir(saveDir); end
% %                 
% %                 [~, fileName, ~] = fileparts(obj.imviewerRef.imageStack.filePath);
% %                 
% %                 fileNameShifts = sprintf(fileName, '_nc_shifts.mat');
% %                 fileNameOpts = sprintf(fileName, '_nc_opts.mat');
% %                 
% %                 save(fullfile(saveDir, fileNameShifts), 'ncShifts')
% %                 save(fullfile(saveDir, fileNameOpts), 'ncOptions')
% % 
% %             end
            
        end
        
        function initializeGaussianFilter(obj)
            obj.imviewerRef.imageDisplayMode.filter = 'gauss3d';
            obj.imviewerRef.imageDisplayMode.filterParam = struct('sigma', obj.settings.General.sigmaX);
            obj.imviewerRef.updateImage();        
            obj.imviewerRef.updateImageDisplay();
            
        end
        
        function resetGaussianFilter(obj)
            obj.imviewerRef.imageDisplayMode.filter = 'none';
            obj.imviewerRef.imageDisplayMode.filterParam = [];
            obj.imviewerRef.updateImage();        
            obj.imviewerRef.updateImageDisplay();
            
        end

        function plotFlowField(obj, ~, ~)
            
            % Convert shifts indices to x,y coordinates
            
            iFrame = obj.imviewerRef.currentFrameNo;
            if iFrame > numel(obj.shifts); return; end
            
            tmpShifts = obj.shifts(iFrame).shifts_up;
            
            
            %TODO.
        end
        
        function updateResults(obj)
            
            
        end
        
        function editSettings(obj)
%             sCell = struct2cell(obj.settings);

% % %             names = fieldnames(obj.settings);
% % %             callbacks = arrayfun(@(i) @obj.onSettingsChanged, 1:numel(names), 'uni', 0);

            callbacks = @obj.onSettingsChanged;
            titleStr = 'Flow Registration Parameters';
            
            optManager = nansen.OptionsManager('nansen.module.flowreg.Processor', obj.settings);
            % Super stupid, but need to get name of options from
            % optionsmanager in order to set the correct options selection
            % in the structeditor
            obj.settingsName = optManager.OptionsName;
            
            sEditor = structeditor(obj.settings, 'Title', titleStr, ...
                'OptionsManager', optManager, 'Callback', callbacks, ...
                'CurrentOptionsSet',  obj.settingsName, ...
                'ValueChangedFcn', @obj.onValueChanged);
            sEditor.waitfor()

            if ~sEditor.wasCanceled
                obj.settings = sEditor.dataEdit;
            end
            
            obj.wasAborted = sEditor.wasCanceled;
            delete(sEditor)
            
            obj.resetGaussianFilter()

            
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
        
        function M = correctMotion(obj, Y, options, templateIn, params)
            
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
        function onSettingsChanged(obj, name, value)
                        
            switch name
                
                case 'symmetricKernel'
                    obj.settings.General.symmetricKernel = value;
                    
% %                 case {'sigmaX', 'sigmaY'}
% % 
% %                     if obj.settings.General.symmetricKernel
% %                         obj.settings.General.sigmaX = value;
% %                         obj.settings.General.sigmaY = value;
% %                     else
% %                         obj.settings.General.(name) = value;
% %                     end
% %                     
% %                     obj.settings.Model.sigma = [obj.settings.General.sigmaY, obj.settings.General.sigmaX, obj.settings.General.sigmaZ];
% %                     obj.imviewerRef.imageDisplayMode.filterParam = struct('sigma', obj.settings.Model.sigma);
% %                     obj.imviewerRef.updateImage();        
% %                     obj.imviewerRef.updateImageDisplay();
                
                case 'sigmaZ'
                    obj.settings.sigma = [obj.settings.General.sigmaX, obj.settings.General.sigmaY, obj.settings.General.sigmaZ];
                    obj.imviewerRef.imageDisplayMode.filterParam = struct('sigma', obj.settings.Model.sigma);
                    obj.imviewerRef.updateImage();        
                    obj.imviewerRef.updateImageDisplay();
                    
                         
                case {'firstFrame', 'numFrames', 'openResultInNewWindow'}
                    %obj.settings.Preview.(name) = value;
                    
                case 'run'
                    obj.runTestAlign()
            end
        end
        
        function onValueChanged(obj, src, evt)
            
            switch evt.Name
                                
                case {'sigmaX', 'sigmaY'}

                    if obj.settings.General.symmetricKernel
                        obj.settings.General.sigmaX = evt.NewValue;
                        obj.settings.General.sigmaY = evt.NewValue;
                        
                        switch evt.Name
                            case 'sigmaX'
                                evt.UIControls.sigmaY.Value = evt.NewValue;
                            case 'sigmaY'
                                evt.UIControls.sigmaX.Value = evt.NewValue;
                        end

                    else
                        obj.settings.General.(evt.Name) = evt.NewValue;
                    end
                    
                    obj.settings.Model.sigma = [obj.settings.General.sigmaY, obj.settings.General.sigmaX, obj.settings.General.sigmaZ];
                    obj.imviewerRef.imageDisplayMode.filterParam = struct('sigma', obj.settings.Model.sigma);
                    obj.imviewerRef.updateImage();        
                    obj.imviewerRef.updateImageDisplay();
            
            end
            
            
        end
        
        
        
        
    end
    
    methods (Static)
        %settings = getNormCorreDefaultSettings()
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