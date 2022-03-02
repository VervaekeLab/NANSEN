classdef DownsampledStack < nansen.stack.ImageStack
%DownsampledStack Class for creating a temporally downsampled ImageStack
%
%   imageStack = DownsampledStack(imageData, n) creates an
%   ImageStack for the process of downsampling another ImageStack. 
%   imageData can be an image array (virtual or in-memory) or
%   another ImageStack. If input is an ImageStack, a new imageArray 
%   is created. n is the downsampling factor (default = 10)
%
%   imageStack = DownsampledStack(imageData, n, method)
%   additionally specified the method. Downsampling is by binning,
%   and the following methods are available:
%   
%       'mean' : take the mean projection of frames from each bin
%       'min'  : take the min projection of frames from each bin
%       'max'  : take the max projection of frames from each bin
%
%   Creating an object of this class does not actually perform the
%   downsampling, but it has a method (addFrames) which is used for
%   consecutively adding frames for downsampling.
%
%   For example use case: 
%   See also nansen.stack.ImageStack.downsampleT    


% Todo:
%   [ ] Adapt for new ImageStack class, supporting multiple channels and
%   planes..

    properties (Constant, Hidden)
        VALIDMODES = {'mean', 'max', 'min'}
    end

    properties (SetAccess = private)
        DownsamplingMethod = 'mean'
        DownsamplingFactor = nan;
    end
    
    properties
        AdjustWhenFinished = true   % Adjust pixelvalue brightness when downsampling has finished? % Todo.
    end
    
    properties (Hidden)
        BrightnessAdjustmentTolerance = 0.5; % What percentile of pixel values to use for brightness adjustment
    end
    
    properties (Access = private)
        ExcessFrames = []           % Frames that are left over from before
        
        FrameCounter = 0;           % Count of frames that are saved
        
        MinPixelValue = inf;        % Values to use for imadjustment
        MaxPixelValue = -inf;       % Values to use for imadjustment
        
        IsInitialized = false;      % Did downsampling start?
        IsFinished = false;         % Did downsampling finish?
    end

    
    methods % Structors
        
        function obj = DownsampledStack(imageData, n, method, varargin)
        %DownsampledStack Constructor for creating a downsampled ImageStack
        
            if nargin < 2 || isempty(n)
                n = 10;
            end
            
            if nargin < 3 || isempty(method)
                method = 'mean';
            end
            
            % If input is an imagestack, we need to derive a new image 
            % array for collecting the downsampled frames. 
            if isa(imageData, 'nansen.stack.ImageStack')
                imageData = nansen.stack.DownsampledStack.allocateData(imageData, ...
                    n, method, varargin{:});
            end
            
            obj@nansen.stack.ImageStack(imageData);
            
            %obj.parseInputs(varargin{:})

            % Set these after the name-value parsing (just in case...)
            obj.DownsamplingFactor = n;
            obj.DownsamplingMethod = method;
            
            % obj.checkFinished()
            
        end
        
    end
    
    methods
        
        function tf = isInitialized(obj)
            % To get around warnings when setting property using set method
            tf = obj.IsInitialized;
        end
        
        function addFrames(obj, data, indices)
                        
            % Todo: implement indices specification?
            
            if ndims(data) ~= 3
                error('Only implemented for 3D image data')
            end
            
            % Add excess frames from last iteration to beginning of data
            if ~isempty(obj.ExcessFrames)
                data = cat(3, obj.ExcessFrames, data);
                obj.ExcessFrames = [];
            end
            
            if isnan(obj.DownsamplingFactor)
                error('Downsampling factor is not set')
            end
            
            binSize = obj.DownsamplingFactor;
            method = obj.DownsamplingMethod;
            
            % Get excess frames indices for current iteration
            numFramesTmp = size(data, 3);
            numFramesExcess = mod(numFramesTmp, binSize);
            
            indExcess = (numFramesTmp-numFramesExcess+1) : numFramesTmp;
            
            % Slice of excessive frames
            obj.ExcessFrames = data(:, :, indExcess);
            data(:, :, indExcess) = [];
            
            % Downsample using the binprojection method
            data = stack.downsample.binprojection(data, binSize, method);

            IND = (1:size(data,3)) + obj.FrameCounter;

            obj.Data(:, :, IND) =  data;
            
            if obj.FrameCounter == 0
                obj.IsInitialized = true;
            end
            
            obj.FrameCounter = IND(end);
            
            
            % Todo: Add tolerances
            minValTmp = min(data(:));
            obj.MinPixelValue = min(obj.MinPixelValue, minValTmp);
            maxValTmp = max(data(:));
            obj.MaxPixelValue = max(obj.MaxPixelValue, maxValTmp);
            obj.DataIntensityLimits = [obj.MinPixelValue, obj.MaxPixelValue];
            
            
            % Finished?
            if obj.FrameCounter == obj.NumTimepoints
                obj.IsFinished = true;
                if obj.AdjustWhenFinished
                    obj.adjustBrightness()
                end
            end
            
        end
        
        function recast(obj, newDataType)
            % Todo.
            
        end
        
        function adjustBrightness(obj)
            % Todo.
        end
        
    end

    methods % Set/get
        
        function set.DownsamplingMethod(obj, newValue)
            if ~obj.isInitialized
                validatestring(newValue, obj.VALIDMODES);
                obj.DownsamplingMethod = newValue;
            else
                msg = 'Can not set mode for downsampling because downsampling process has started';
                error(msg)
            end
        end
        
        function set.DownsamplingFactor(obj, newValue)
            if ~obj.isInitialized
                validateattributes(newValue, {'numeric'}, {'integer'})
                obj.DownsamplingFactor = newValue;
            else
                msg = 'Can not set factor for downsampling because downsampling process has started';
                error(msg)
            end
        end
        
    end
    
    methods (Static)
                
        function imArray = allocateData(hIm, n, method, varargin)
        %allocateData Allocate imagedata (virtual or in-memory)
        %
        %   imArray = obj.allocateData(ImageStack, n, method, name, value)
        %
        %   This method creates an image array (virtual or in-memory) for
        %   collecting the resulting data from downsampling of an
        %   ImageStack instance. The image array has the same resolution
        %   and datatype as the original ImageStack, but the number of
        %   frames/samples depends on the downsampling factor.
        %
        %   Inputs: 
        %       n = downsampling factor
        %       method = downsampling method
        %       name, value = one of the following parameters
        %   Paramters:
        %       CreateVirtualOutput (logical)       : Is output a virtual or in-memory image array?
        %       UseTransientVirtualStack (logical)  : Is virtual stack transient?
        %       FilePath (char)                     : Filepath for image array (if virtual...) 
        
        
            % Default parameters for creation/allocation of image array
            params = struct();
            params.CreateVirtualOutput = false;         % Create output as virtual stack or stack in memory?
            params.UseTransientVirtualStack = true;     % Transient virtual stack (i.e file is deleted when virtual stack is deleted)
            params.FilePath = '';
            
            % Parse name-value pairs from input
            params = utility.parsenvpairs(params, 1, varargin{:});
                        
            % Create filename if it is not given (when using virtual data)
            if params.CreateVirtualOutput && isempty(params.FilePath)
                if isempty(hIm.FileName)
                    error('Not implemented yet for non-virtual (?) stack')
                else
                    [~, ~, ext] = fileparts(hIm.FileName);
                    postfix = sprintf('_downsampled_%s_x%d', method, n);
                    postfix = strcat(postfix, ext);
                    params.FilePath = strrep(hIm.FileName, ext, postfix);
                end
            end

            % Determine size of image array to output
            numFrames = floor(hIm.NumTimepoints / n);
            newStackSize = [hIm.ImageHeight, hIm.ImageWidth, numFrames];
            newStackType = hIm.DataType;
            
            % Preallocate image array (virtual/in-memory) for output
            if params.CreateVirtualOutput
                nvPairs = {'IsTransient', params.UseTransientVirtualStack};
%                 imArray = virtualStack(params.FilePath, newStackSize, ...
%                     newStackType, nvPairs{:});
                
                imArray = nansen.stack.open(params.FilePath, newStackSize, ...
                    newStackType, nvPairs{:});
                
            else
                imArray = zeros(newStackSize, newStackType);
            end
            
        end
        
    end
    
    
end


% Todo:
% [ ] Generalize so that frames does not have to be added in specific
%       order? See register images rotation...
% [x] Downsampling factor should be fixed from onset. The number of
%       frames in the data depends on this, but currently does not
%       change if factor changes
% [ ] Write some properties to ini file. I.e IsFinished. If array is
%       loaded at a later time, can skip computations?

