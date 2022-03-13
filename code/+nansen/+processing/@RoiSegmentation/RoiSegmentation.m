classdef RoiSegmentation < nansen.stack.ImageStackProcessor

    % Todo: 
    %   [ ] Multichannel support
    
    
    properties (Abstract, Constant, Hidden)
        DATA_SUBFOLDER  % Name of subfolder(s) where to save results by default
    end
    
    properties (Access = protected) % Data to keep during processing.
        ToolboxOptions  % Options that are in the format of original toolbox
        OriginalStack   % To store value of imagestaack if stack is downsampled
        Results         % Cell array to store temporary results (from each subpart)
    end
    
    
    methods (Abstract, Access = protected)
        S = getToolboxSpecificOptions(obj)
        results = segmentPartition(obj, y)    
    end
    
    methods % Constructor
        
        function obj = RoiSegmentation(varargin)
            obj@nansen.stack.ImageStackProcessor(varargin{:})
        end
    
    end
    
    
    methods (Access = protected) % Overide ImageStackProcessor methods % Methods for initialization/completion of algorithm

        function onInitialization(obj)
        %onInitialization Runs when data method is initialized
            
            obj.ToolboxOptions = obj.getToolboxSpecificOptions();
            

            if obj.IsInitialized
                if ~isempty(obj.OriginalStack)
                    obj.SourceStack = obj.OriginalStack;
                end
            end
            
            
            %dsFactor = obj.Options.TemporalDownsamplingFactor;
            dsFactor = obj.getTemporalDownsamplingFactor();
            
            if dsFactor > 1
                
                downsampledStack = obj.SourceStack.downsampleT(dsFactor);
            
                obj.OriginalStack = obj.SourceStack;
                obj.SourceStack = downsampledStack;
               
                % Redo the splitting
                obj.configureImageStackSplitting()

            end
            
            obj.Results = cell(obj.NumParts, 1);

        end
                
        function Y = processPart(obj, Y, ~)
            
             Y = obj.preprocessImageData(Y);
            
             output = obj.segmentPartition(Y);
             
             obj.Results{obj.CurrentPart} = output;
             obj.saveResults()
             
             %Y = obj.postprocessImageData();

        end
        
        function onCompletion(obj)
                  
            disp('finished')
            %todo:
            % merge rois. 
            % Save final rois
            
            % Extract signals
            
            % Save signals..
            
        end
        
    end
    
    
    methods (Access = protected) % Methods for processing each partition

        function Y = preprocessImageData(obj, Y)
             
        end
        
        function Y = postprocessImageData(obj, Y)
             
        end

    end
    
    
    methods (Access = protected) % Other utiliy methods for roi segmentation
        
        function runImageSegmentation(obj)
                        
            % Initialize file reference for raw 2p-images
            imageStack = obj.DataRef;
            
            numFramesPerPart = obj.DataOptions.numFramesPerPart;
            IND = imageStack.getChunkedFrameIndices(numFramesPerPart);
            
            numParts = numel(IND);

            
            % Todo: Implement temporal downsampling.
                        
            % Only use 1 worker for the parpool, because some cnmf
            % functions are overloading the memory.
            p = gcp('nocreate');
            if isempty(p) || p.NumWorkers > 1
                delete(p)
                parpool(1);
            end
            
            T = [];
            
            [rois, cnmfRes] = deal( cell(numParts,1) );
            
            % Loop through 
            for iPart = 1:numParts
                
                iIndices = IND{iPart};
                
                % Load data Todo: Make method. Two photon session method?
                Y = imageStack.getFrameSet(iIndices);
                
                if obj.DataOptions.TemporalDownsamplingFactor == 1
                    [roiArray, cnmfResults] = obj.segmentImageData(Y);
                else
                    Y_ = single( utilities.getMovingAverage(Y, 10) );

                    if isempty(T)
                        T = zeros(size(Y), 'single');
                        tempInd = 1:size(Y_, 3);
                    else
                        tempInd = tempInd(end) + (1:size(Y_, 3));
                    end
                    
                    T(:, :, tempInd) = Y_; %#ok<AGROW>

                    if mod(iPart, obj.DataOptions.TemporalDownsamplingFactor ) == 0
                        tic
                        [roiArray, cnmfResults] = obj.segmentImageData(T);
                        toc
                        rois{iPart} = roiArray;
                        cnmfRes{iPart} = cnmfResults;
                        T = [];
                    end
                end
                
            end
            
            keep = cellfun(@(c) ~isempty(c), rois, 'uni', 1);
            cnmfRes = cnmfRes(keep);
            
            rois = rois(keep);
            roiArray = cat(2, rois{:});
            
            % Reset parpool
            p = gcp('nocreate');
            if isempty(p) || p.NumWorkers == 1
                delete(p)
                %parpool();
            end
        end

        function [roiArray, cnmfResults] = segmentImageData(obj, Y)
            
            import nansen.wrapper.cnmf.*
            [roiArray, cnmfResults] = run(Y, obj.ToolboxOptions);
        
        end
       
        function appendResults(obj)
            
        end
        
        function dsFactor = getTemporalDownsamplingFactor(obj)
            dsFactor = obj.Options.TemporalDownsamplingFactor;
        end
        
    end
    
    
    methods (Static)
        function S = getDefaultOptions()
            
            S = struct.empty;
        end
% % %             
% % %             S.numFramesPerPart = 1000;
% % %             S.TemporalDownsampling = true; % needed?
% % %             S.TemporalDownsamplingFactor = 10; % 1 = no downsampling...
% % %             S.SpatialDownsamplingFactor = 1;
% % %             
% % %             % S.SpatialPartitioning
% % %             % S.TemporalPartitioning
% % %             
% % %         end
    end

    
    
    methods % Implementation of abstract, public methods
        
        function tf = preview(obj)
            %TODO:
            
            CLASSNAME = obj.ImviewerPluginName();
            
            pluginPackage = {'imviewer.plugin', 'nansen.plugin.imviewer'};
            
            pluginFcn = [];
            for i = 1:2
                pluginFcnName = strjoin([pluginPackage(i), CLASSNAME], '.');
                str = which(pluginFcnName);
                if ~isempty(str)
                    pluginFcn = str2func(pluginFcnName);
                end
            end
            
            if ~isempty(pluginFcn)
                hImviewer = imviewer(obj.SourceStack);
                h = hImviewer.openPlugin(pluginFcn, obj.Parameters);
%                 error('NANSEN:Roisegmentation:PluginMissing', ...
%                     'Plugin for %s was not found', CLASSNAME)
                newParameters = h.settings;
                hImviewer.quit()
                tf = true;
            else
                [newParameters, wasAborted] = tools.editStruct(obj.Parameters);
                tf = ~wasAborted;
            end
            
            obj.Parameters = newParameters;

        end
        
        
    end
    
    methods (Access = protected)
        
        function opts = initializeOptions(obj, opts, optionsVarname)
        % Get filepath for saving options file to session folder
            filePath = obj.getDataFilePath(optionsVarname, '-w', ...
                'Subfolder', obj.DATA_SUBFOLDER);
            
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
                    'Subfolder', obj.DATA_SUBFOLDER)
            end
            
        end
        
    end
    
end