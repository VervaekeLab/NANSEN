classdef TemporalDownsampler < nansen.stack.ImageStackProcessor
%TemporalDownsampler Class for running temporal downsampling on ImageStack
%
%   This method creates a downsampled ImageStack (virtual or in-memory) 
%   The downsampled ImageStack has the same resolution and datatype as 
%   the original ImageStack, but the number of frames/samples depends on 
%   the downsampling factor.
    
    
    % Todo: How to deal with the slicing off excessive frame because
    % binning size might not always match chunk size? 
    
    % [ ] Add cache and methods in order to do "live downsampling" by
    % receiving unspecified chunks of data and adding them to target stack
    
    % = Autoadjust chunk size? Definitely yes
    
    properties (Constant, Hidden)
        VALIDMODES = {'mean', 'max', 'min'}
    end
    
    properties (Constant) % Attributes inherited from nansen.DataMethod
        MethodName = 'Temporal Downsampling'
        IsManual = false        % Does method require manual supervision?
        IsQueueable = true      % Can method be added to a queue?
        OptionsManager nansen.manage.OptionsManager = ...
            nansen.OptionsManager(mfilename('class'))
    end

    properties (Constant, Hidden)
        DATA_SUBFOLDER = ''	% defined in nansen.DataMethod
        VARIABLE_PREFIX	= '' % defined in nansen.DataMethod
    end 
    
    properties (SetAccess = private)
        DownsamplingFactor
        DownsamplingMethod
    end
    
    properties (Dependent) % Options
        SaveToFile                  % Save downsampled stack to file? (logical) Default = true
        TargetFilepath              % Filename to use for result. Autogenerated if empty (char) Default = ''
        TargetFileType              % File type to save stack to (char) Default = 'raw'
        UseTemporaryFile            % Delete file when ImageStack is deleted (logical) Default = false
        AdjustWhenFinished          % Adjust pixelvalue brightness when downsampling has finished? (logical) Default = false % Todo.
    end

    properties (Hidden)
        BrightnessAdjustmentTolerance = 0.5; % What percentile of pixel values to use for brightness adjustment
    end
    
    properties (Access = private)
        FrameCount
        DataPrevIter
        
        MinPixelValue = inf;        % Values to use for imadjustment
        MaxPixelValue = -inf;       % Values to use for imadjustment
        
        TargetFrameIndPerPart
        
        %IsInitialized = false;      % Did downsampling start?
        %IsFinished = false;         % Did downsampling finish?
    end
    
    methods (Static)
        
        function S = getDefaultOptions()
        % Get default options for the temporal downsampler    
            S.DownsamplingFactor    = 10;               % Number of frames to bin. Default = 10;
            S.DownsamplingMethod    = 'mean';           % Method used for downsampling (binning of frames) Default = 'mean';
            S.SaveToFile            = true;             % Save downsampled stack to file? (logical)
            S.TargetFilepath        = '';               % Filename to use for result. Autogenerated if empty (char)
            S.TargetFileType        = 'raw';            % File type to save stack to (char)
            S.UseTemporaryFile      = false;            % Delete file when ImageStack is deleted (logical)
            S.AdjustWhenFinished    = false;            % Adjust pixelvalue brightness when downsampling has finished? (logical) % Todo.
           
            S.TargetFilepath_       = 'transient';
            S.DownsamplingMethod_   = {'mean', 'max'};
            S.TargetFileType_       = {'raw', 'tif'}; % Todo h5?
            
            className = mfilename('class');
            superOptions = nansen.mixin.HasOptions.getSuperClassOptions(className);
            S = nansen.mixin.HasOptions.combineOptions(S, superOptions{:});            
        end
        
    end
    
    methods % Constructor
        
        function obj = TemporalDownsampler(sourceStack, n, method, varargin)
        %DownsampledStack Constructor for creating a downsampled ImageStack
        %
        %   Inputs :          
        %       n = downsampling factor
        %       method = downsampling method
        %
        %   Options : See properties.
        
        
            if nargin < 2 || isempty(n)
                n = 10;
            end
            
            if nargin < 3 || isempty(method)
                method = 'mean';
            end

            %TemporalDownsampler Constructor for TemporalDownsampler processor
            obj@nansen.stack.ImageStackProcessor(sourceStack, varargin{:})
            
            obj.DownsamplingFactor = n;
            obj.DownsamplingMethod = method;
            
            if ~nargout
                obj.runMethod()
                clear obj
            end
            
        end
        
    end
    
    methods % Set/get
        
        function set.DownsamplingMethod(obj, newValue)
            validatestring(newValue, obj.VALIDMODES);
            obj.DownsamplingMethod = newValue;
        end
        
        function set.DownsamplingFactor(obj, newValue)
            validateattributes(newValue, {'numeric'}, {'integer'})
            obj.DownsamplingFactor = newValue;
        end
        
        function value = get.SaveToFile(obj)
            value = obj.Options.SaveToFile;
        end        % Get
        function set.SaveToFile(obj, value)
            obj.Options.SaveToFile = value;
        end         % Set
        
        function value = get.TargetFilepath(obj)
            value = obj.Options.TargetFilepath;
        end
        function set.TargetFilepath(obj, value)
            obj.Options.TargetFilepath = value;
        end
        
        function value = get.TargetFileType(obj)
            value = obj.Options.TargetFileType;
        end
        function set.TargetFileType(obj, value)
            obj.Options.TargetFileType = value;
        end
        
        function value = get.AdjustWhenFinished(obj)
            value = obj.Options.AdjustWhenFinished;
        end
        function set.AdjustWhenFinished(obj, value)
            obj.Options.AdjustWhenFinished = value;
        end
        
        function value = get.UseTemporaryFile(obj)
            value = obj.Options.UseTemporaryFile;
        end
        function set.UseTemporaryFile(obj, value)
            obj.Options.UseTemporaryFile = value;
        end
        
    end
    
    methods 
        
        function tf = existDownsampledStack(obj)
            
            % Todo: Use this as a backup? I.e if targetStack already
            % exists, but for some reason the IsCOmplete flag was not
            % added.
            
            if ~isempty(obj.TargetStack)
                nansen.stack.ImageStack.isStackComplete(obj.TargetStack)
            end
            
            if isempty(obj.TargetStack)
                obj.openTargetStack()
            end
            tf = obj.TargetStack.MetaData.Downsampling.IsCompleted;
        end
        
        function imageStack = getDownsampledStack(obj)
            imageStack = obj.TargetStack;
            % Since someone requested TargetStack, assume they use it for
            % something and don't clean up when processor is destroyed.
            obj.DeleteTargetStackOnDestruction = false;
        end
        
    end
    
    methods (Access = protected) 
                   
        function openTargetStack(obj, ~, ~, ~)
        %openTargetStack Open (or create) and assign the target image stack
            
            stackSize = obj.getTargetStackSize();
            dataType = obj.SourceStack.DataType;
            
            if obj.SaveToFile && isempty(obj.TargetFilepath)
                obj.TargetFilepath = obj.createTargetFilepath();
            end
            
            if obj.SaveToFile
                nvPairs = {'IsTransient', obj.UseTemporaryFile, ...
                    'DataDimensionArrangement', obj.SourceStack.Data.StackDimensionArrangement};

                % Call method of ImageStackProcessor
                openTargetStack@nansen.stack.ImageStackProcessor(obj, ...
                    obj.TargetFilepath, stackSize, dataType, nvPairs{:})
            else
                imArray = zeros(stackSize, dataType);
                obj.TargetStack = nansen.stack.ImageStack(imArray);
            end
            
            obj.updateTargetMetadata()
            
            % Make sure caching is turned off...
            obj.TargetStack.Data.UseDynamicCache = false;

        end

        function iIndices = getTargetIndices(obj, ~)
        %getTargetIndices Get downsampled target indices    
            iPart = obj.CurrentPart;
            iIndices = obj.TargetFrameIndPerPart{iPart};
        end
        
        function onInitialization(obj)
        
           % Recompute chunking size to be a factor of the bin size...
            
            N = obj.NumFramesPerPart;
            x = obj.DownsamplingFactor;
            
            % Adjust chunksize
            N = floor(N./x) .* x;
           
            obj.NumFramesPerPart = N;
           
            obj.openTargetStack()
            
            obj.configureTargetFrameIndicesPerPart()
            
        end
        
        function [data, summary] = processPart(obj, data, iIndices)
            
            binSize = obj.DownsamplingFactor;
            method = obj.DownsamplingMethod;
            
            % Frames for the last part might not be the correct size for
            % the binsize, to trim excessive frames
            if obj.CurrentPart == obj.NumParts
                numFramesExcess = mod(size(data, 3), binSize);
                data(:, :, end-numFramesExcess+1:end) = [];
            end

            % Downsample using the binprojection method
            data = stack.downsample.binprojection(data, binSize, method);
            
            
            % Todo: Add tolerances
            
            % Save minimum and maximum values of data (for adjusting at end)
            minValTmp = min(data(:));
            obj.MinPixelValue = min(obj.MinPixelValue, minValTmp);
            maxValTmp = max(data(:));
            obj.MaxPixelValue = max(obj.MaxPixelValue, maxValTmp);
            
            summary = struct();
            summary.minPixelValue = min(data(:));
            summary.maxPixelValue = max(data(:));
        end
        
        function onCompletion(obj)
              
            obj.TargetStack.DataIntensityLimits = [obj.MinPixelValue, obj.MaxPixelValue];
            
            if obj.AdjustWhenFinished
                obj.adjustBrightness()
            end
            
            ds = obj.TargetStack.MetaData.Downsampling;
            ds.IsCompleted = true;
            obj.TargetStack.MetaData.set('Downsampling', ds)
        end
        
    end

    methods (Access = private)
        
        function tf = isInitialized(obj)
            % To get around warnings when setting property using set method
            tf = obj.IsInitialized;
        end
        
        function stackSize = getTargetStackSize(obj)
        %getTargetStackSize Get size of downsampled target stack
        
            n = obj.DownsamplingFactor;
        
            % Determine size of image array to output
            numFrames = floor(obj.SourceStack.NumTimepoints / n);
            dimT = obj.SourceStack.getDimensionNumber('T');
            
            assert(~isempty(dimT), 'T is not a dimension of this stack')
            stackSize = size(obj.SourceStack.Data);
            
            stackSize(dimT) = numFrames;
        end
        
        function configureTargetFrameIndicesPerPart(obj)
        %configureTargetFrameIndicesPerPart Get frame indices for target.   
            n = obj.NumFramesPerPart / obj.DownsamplingFactor;
            assert( mod(n, 1) == 0, 'Number of frames per part is not set correctly, please report' )
            
            [frameIndPerPart, ~] = obj.TargetStack.getChunkedFrameIndices(n);
            obj.TargetFrameIndPerPart = frameIndPerPart;
        end
        
        function filePath = createTargetFilepath(obj)
        %createTargetFilepath Create filepath for a downsampled stack
        %
        %   Add extension to filename of source stack describing both
        %   downsampling method and downsampling factor.
        %
        %   Example : filename.tif --> filename_downsampled_mean_x10.tif
            
            n = obj.DownsamplingFactor;
            method = obj.DownsamplingMethod;
        
            [~, ~, ext] = fileparts(obj.SourceStack.FileName);
            
            postfix = sprintf('_downsampled_%s_x%d', method, n);
            postfix = strcat(postfix, ext);
            filePath = strrep(obj.SourceStack.FileName, ext, postfix);
            
            % Change filetype (extension) if filetype is specified.
            if ~strcmp(obj.TargetFileType, 'same')
                newExt = obj.TargetFileType;
                if ~strncmp(newExt, '.', 1)
                    newExt = strcat('.', newExt);
                end
                filePath = strrep(filePath, ext, newExt);
            end
        end
        
        function updateTargetMetadata(obj)
        %updateTargetMetadata Update metadata of target stack              

            if ~isprop(obj.TargetStack.MetaData, 'Downsampling')
                
                % Inherit metadata from the source stack
                obj.TargetStack.MetaData.updateFromSource(obj.SourceStack.MetaData)
                
                % Update time increment based on amount of downsampling
                obj.TargetStack.MetaData.TimeIncrement = ...
                    obj.TargetStack.MetaData.TimeIncrement * obj.DownsamplingFactor;
                
                % Add info about downsampling to metadata.
                ds = struct();
                ds.IsCompleted = false;
                ds.DownsamplingFactor = obj.DownsamplingFactor;
                ds.DownsamplingMethod = obj.DownsamplingMethod;
                obj.TargetStack.MetaData.set('Downsampling', ds)
            end
        end
        
        function adjustBrightness(obj)
            warning('Adjusting of brightness is not implemented yet')
        end
    end

end