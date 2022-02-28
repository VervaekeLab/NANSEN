classdef RoiSegmentation < nansen.session.SessionMethod

    % Todo: 
    %   [ ] Implement a preprocessing function property, for preprocessing
    %       images before correction. Could be an alternative to running e.g
    %       stretch correction in the getframeSet method of the rawstack.
    %   [ ] Multichannel support
    
        
    properties (Constant) % SessionMethod attributes
        BatchMode = 'serial'
        IsQueueable = true;
    end
    
    properties 
        DataOptions
        ToolboxOptions
        
        DataRef
    end
    
    properties
        preprocessFcn = []
    end
    
    methods (Abstract)
        S = getToolboxSpecificOptions(obj, varargin)
    end
    
    
    methods
        
        function runMethod(obj)
            
            iSession = obj.SessionObjects;
            
            % Todo: Get these from inputs.
            obj.DataOptions = obj.getDefaultOptions();
            
            % Initialize file reference for raw 2p-images
            imageStack = iSession.openTwoPhotonSeries('corrected');
                        
            % Turn off caching, its not needed here.
            imageStack.imageData.UseCache = false;
            obj.DataRef = imageStack; % Todo: rename to image stack...??
            
            obj.ToolboxOptions = obj.getToolboxSpecificOptions();
                        
            obj.runImageSegmentation()
        end
        
    end
    
    
    methods
        
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
        
    end
    
    
    methods (Static)
        function S = getDefaultOptions()
                    
            S.numFramesPerPart = 1000;
            S.TemporalDownsampling = true; % needed?
            S.TemporalDownsamplingFactor = 10; % 1 = no downsampling...
            S.SpatialDownsamplingFactor = 1;
            
        end
    end

    
    
    methods % Implementation of abstract, public methods
        
        function tf = preview(obj)
            %TODO:
            
            %CLASSNAME = class(obj);
            CLASSNAME = obj.getImviewerPluginName();
            
            rawStack = openRawTwoPhotonStack(obj);
            
            hImviewer = imviewer(rawStack);
            
            h = imviewer.plugin.(CLASSNAME)(hImviewer, obj.Parameters);
            
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
                'Subfolder', 'image_segmentation');
            
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
                    'Subfolder', 'image_segmentation')
            end
            
        end
        
    end
    

    
    


end