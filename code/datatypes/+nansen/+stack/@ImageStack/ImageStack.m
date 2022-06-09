% Interface for reading and writing image frame data from a matlab array, 
% or tiff, binary or video files.
%
%   * Use for matlab array or virtual data (memorymap of data in file)
%   * Retrieve data using frame indices (channel / depth / time)
%   * Get frame chunks for batch processing of large data sets
%   * Get projections along depth or time dimensions
%
%   See also nansen.stack.ImageStack/ImageStack

classdef ImageStack < handle & uim.mixin.assignProperties
%ImageStack Wrapper for multi-dimensional image stack data
%
%   This class contains methods and properties for accessing image frames
%   in a standardized manner from a multidimensional data array. The data
%   can be a matlab array, or a VirtualData object.
%
%   A VirtualData object is a memory mapped representation of an image 
%   stack saved in a file, and some implementations include Binary, Tiff 
%   and video files. See VirtualData and existing subclasses for examples.
%
%   Data from an ImageStack is returned according to the default
%   dimensional order, YXCZT, corresponding to image height, image width,
%   channel/color, depth/planes (3D) and time respectively. If the length 
%   of any of these dimensions is 1 data is squeezed along that dimension.
%
%   The dimensional order of the output as well as the input can be
%   rearranged by providing a custom dimensional order using the letter
%   representations from above.
%
%   Furthermore, the apparent size of the ImageStack data can be
%   temporarily adjusted by setting the CurrentChannel and/or the 
%   CurrentPlane properties to a subset within the range of the 
%   NumChannels and NumPlanes properties
%
%   The ImageStack also provides methods for reading chunks of frames,
%   which can be useful for processing data from very large arrays that
%   don't fit in the computer memory.
%
%   Finally, the ImageStack class provides methods for calculating
%   projections along the depth or time dimensions.
%
%   EXAMPLES (Creating an ImageStack object):
%
%     imageStack = ImageStack(data) returns an ImageStack object based
%         on the data variable. The data variable must be an array with 2-5
%         dimensions.
%
%     imageStack = ImageStack(virtualData) returns an ImageStack object
%         based on the image data represented by the virtualData object.
%
%   DETAILED EXAMPLES (Use cases):    
%       


% - - - - - - - - QUESTIONS - - - - - - - - - - - 
%
%   1) Should output from getFrameSet be squeezed or not?
%
%   2) Should data not be deleted on destruction if it was provided as
%      input on construction.., i.e tied to imagestack or not??
%
%   3) How to set intensity limits without loading data on creation..




% - - - - - - - - - TODO - - - - - - - - - - - -
%   [ ] getFrameSet does not match description. Still not sure how to do
%       this in the best way. It should only grab according to last
%       dimension, and use CurrentPlane and CurrentChannel for selecting
%       subsets....
%   [ ] writeFrameSet same as above..
%
%   [ ] Add listener for DataCacheChanged and update flags for whether
%       projections should be updated...
%   [ ] Add event (or observable property) to allow listeners to detect if
%       data size changes
%
%   [x] Permute output from getFrameSet to correspond with DimensionOrder
%       Actually, this is done in the imageStackData class...
%   [ ] Rename DimensionOrder and make it obvious what it refers to and how
%       its different from DataDimensionOrder.
%   [ ] Make method to return data size according to the
%       DefaultDimensionOrder 
%   [ ] More work on dimension selection for frame chunks.
%   [ ] Make ProjectionCache class and add as property...
%   [ ] Set method for name
%   [ ] Fix projecton cache and retrieval for multichannel images
%
%   [ ] Properties: FrameSize and NumFrames. Useful, Keep? 
%
%   [ ] Is chunklength implemented?
%
%   [ ] Method for loading userdata/metadata/projections...
%
%   [ ] Update insert image to work with imagestack data.
%

% - - - - - - - - - - - - PROPERTIES - - - - - - - - - - - - - - - - - - - 

    properties (Constant, Hidden) % Default values for dimension order
        DEFAULT_DIMENSION_ORDER = 'YXCZT'
        DIMENSION_LABELS = {'Height', 'Width', 'Channel', 'Plane', 'Time'}
    end
    
    properties % Properties containing ImageStack name and data
        Name char = 'UNNAMED'   % Name of ImageStack
        Data                    % Data ImageStackData
    end
    
    properties (Dependent)
        DimensionOrder          % Dimension arrangement of stack (i.e output) Depends on ImageStackData
    end
    
    properties (Dependent, Hidden)
        DataDimensionOrder      % Dimension arrangement of data (i.e source) Depends on ImageStackData
    end
    
    properties (Dependent) % Properties for customization of dimension lengths and units
        ImagePhysicalSize       % Length of each dimension, i.e 1 pixel = 1.5 micrometer
        ImagePhysicalUnits      % Units of each dimension, i.e [micrometer, micrometer, second] for XYT stack
        StackDuration
    end
    
    properties (Dependent)
        MetaData
    end
    
    properties 
        FileName char = ''      % Filename (absolute path for file) if data is a virtual array
        UserData struct         % Userdata 

        DataXLim (1,2) double    % When these are set, any call to the getFrameSet will return the portion of the image within these limits
        DataYLim (1,2) double    % When these are set, any call to the getFrameSet will return the portion of the image within these limits

        CurrentChannel = 1      % Sets the current channel(s). getFrames picks data from current channels
        CurrentPlane  = 1       % Sets the current plane(s). getFrames picks data from current planes
        
        ColorModel = ''         % Name of colormodel to use. Options: 'BW', 'Grayscale', 'RGB', 'Custom' | Should this be on the imviewer class instead?
        DataIntensityLimits
    end
    
    properties (SetAccess = private, Dependent) % Should these be dependent instead?
        ImageHeight
        ImageWidth
        NumChannels
        NumPlanes
        NumTimepoints
        DataType
    end
    
    properties (Hidden, Dependent)
        FrameSize % Todo: Is this used?
        NumFrames % Todo: Is this used? Is it the product of channels, planes and timepoints?
        
        DimensionNames          % Names for dimensions of image stack data, i.e ImageHeight, Channels etc
        DynamicCacheEnabled matlab.lang.OnOffSwitchState % Depends on ImageStackData
        DataTypeIntensityLimits     % Min and max values of datatype i.e [0,255] for uin8 data
    end
    
    properties (Access = private) % Should it be public? 
        Projections
    end
    
    properties (SetAccess = private) % Dependent (For virtual data)
        IsVirtual
        HasStaticCache = false
    end
    
    properties (Hidden)
        CustomColorModel = []
        ChunkLength = inf; % Todo (Not implemented yet)
    end

    properties (Dependent = true)
        NumChunks
    end

    properties (Access = private)
        CacheChangedListener event.listener
        isDirty struct % Temp flag for whether projection cache was updated... Should be moved to a projection cache class
    end
    

% - - - - - - - - - - - - - METHODS - - - - - - - - - - - - - - - - - - - 

    methods % Structors
        
        function obj = ImageStack(datareference, varargin)
        %ImageStack Constructor of ImageStack objects
        %
        %   imageStack = ImageStack(data) returns an ImageStack object 
        %       based on the data variable. The data variable must be an 
        %       array with 2-5 dimensions.
        %
        %   imageStack = ImageStack(virtualData) returns an ImageStack 
        %       object based on the image data represented by the 
        %       virtualData object.   
        %
        %   imageStack = ImageStack(..., Name, Value) creates the
        %       ImageStack object and specifies values of properties on
        %       construction.
        %
        %   PARAMETERS (See property descriptions for details): 
        %       Name, CurrentChannel, CurrentPlane, ColorModel, 
        %       DataDimensionOrder, CustomColorModel, DynamicCacheEnabled,
        %       ChunkLength
        %
        
            if ~nargin; return; end
            
            % This method creates the appropriate subclass of 
            % ImageStackData and the returned object is assigned to the
            % Data property. See also onDataSet
            obj.Data = obj.initializeData(datareference, varargin{:});
            
            obj.parseInputs(varargin{:})
            
            % Todo: method for loading userdata/metadata/projections...
            
            % Todo: Part of onDataSet?
%             if isempty( obj.DataIntensityLimits )
%                 obj.autoAssignDataIntensityLimits()
%             end
            
            if isempty(obj.ColorModel)
                obj.autoAssignColorModel()
            end
            
        end
        
        function delete(obj)
            
            if obj.IsVirtual
                delete(obj.CacheChangedListener)
            end
            
            % Delete the data property.
            % Todo: Only delete if data is created internally. 
            if ~isempty(obj.Data) && isvalid(obj.Data)
                delete(obj.Data)
            end
            
            % fprintf('Deleted ImageStack.\n') % For testing
        end

    end

    methods % User methods
        
    % - Methods for accessing data using frame indices
    
        function imArray = getFrameSet(obj, frameInd, mode, varargin)
        %getFrameSet Get set of image frames from image stack
        %
        %   imArray = imageStack.getFrameSet(indN) gets the frames
        %   specified by the vector, indN, where indN specified the frame
        %   indices along the last dimension of the ImageStack Data. 
        %   
        %   imArray = imageStack.getFrameSet(indN, indN-1) gets frames as
        %   subset where indN and indN-1 are indices to get along the last
        %   two dimensions of the Data.
        %
        %   imArray = imageStack.getFrameSet('all') returns all available
        %   frames. For VirtualData, all available frames equals frames in
        %   the Cache. If Caching is off, a subset of N frmaes are
        %   retrieved.
        %
        %   NOTE: The behavior of getFrameSet is influenced by the values
        %   of CurrentChannel and CurrentPlane. I.e: If CurrentChannel is
        %   set to 1, and the data contains 3 channels, only data from the
        %   first channel is retrieved, even if more channelIndices are
        %   specifiec in inputs. To override this behavior, index the Data 
        %   property instead.
        %
        %   Note: If the length of any of the frame dimensions (channel /
        %   plane / time) is one, this dimension is not regarded.
        %
        %   Examples:
        %     1) imageStack is XYCT.
        %       data = imageStack.getFrameSet(1:10) will return an array of
        %       size h x w x numChannels x 10
        %
        %       data = imageStack.getFrameSet(1:10, 1:2) will return an 
        %       array of size h x w x 2 x 10
        %
        %       However: If CurrentChannel is set to 1, the data will be of
        %       size h x w x 10
        %
        %     2) imageStack is XYCZT.
        %       data = imageStack.getFrameSet(1:10) will return an array of
        %       size h x w x numChannels x numPlanes x 10
        %
        %       data = imageStack.getFrameSet(1:10, 1:3) will return an 
        %       array of size h x w x numChannels x 3 x 10
        %
        %     3) imageStack is XYZCT.
        %       data = imageStack.getFrameSet(1:10, 1:3) will return an 
        %       array of size h x w x numPlanes x 3 x 10
        
            % TODO: Generalize so that X and y can be on any dimension, not
            % just 1 or 2.
            
            if nargin < 3 || isempty(mode); mode = 'standard'; end
        
            switch mode
                case 'standard'
                    indexingSubs = obj.getDataIndexingStructure(frameInd, varargin);
                case 'extended'
                    indexingSubs = obj.getFullDataIndexingStructure(frameInd);
            end
            
            doCropImage = ~all(cellfun(@(c) strcmp(c, ':'), indexingSubs(1:2)));
            % Note: Do crop subsrefing only if necessary. 
            
            selectFrameSubset = ~all(cellfun(@(c) strcmp(c, ':'), indexingSubs(3:end-1)));
            % Note: Selecting frame subset is necessary if getting cached
            % data and some frame dimensions (C, Z) are subsref'ed.
            
            % Todo: make another keyword, like 'all' or 'cache' but return
            % a chunk also if cache is empty
            
            % Case 1: All frames (along last dimension) are requested.
            if (ischar(frameInd) && strcmp(frameInd, 'all')) || ...
                 (isnumeric(frameInd) && numel(frameInd) == obj.NumFrames)
                
                % Check if there is enough memory for operation.
                obj.assertEnoughMemoryForFrameRequest(indexingSubs)

                % Assign image data to temp variable.
                if obj.IsVirtual
                    imArray = obj.Data(indexingSubs{:});
                    [doCropImage, selectFrameSubset] = deal( false );
                else
                    imArray = obj.Data.DataArray;
                end
                
            % Case 2; Get cached frames
            elseif (ischar(frameInd) && strcmp(frameInd, 'cache'))
                if obj.IsVirtual
                    if obj.Data.HasCachedData
                        if obj.HasStaticCache
                            imArray = obj.Data.getStaticCache();
                        else
                            imArray = obj.Data.getCachedFrames();
                        end
                    else
                        imArray = [];
                    end
                    
                    if isempty(imArray) % If cache is empty, get images directly from Data
                        numFrames = min([obj.NumTimepoints, 500]);
                        imArray = obj.getFrameSet(1:numFrames, mode);
                        [doCropImage, selectFrameSubset] = deal( false );
                    end
                    
                else
                    imArray = obj.Data.DataArray;
                end

            % Case 3: Subset of frames are requested.
            else
                % Check if there is enough memory for operation.
                obj.assertEnoughMemoryForFrameRequest(indexingSubs)
                imArray = obj.Data(indexingSubs{:});
                [doCropImage, selectFrameSubset] = deal( false );
            end
            
            if isempty(imArray); return; end
            
            % Todo: Subselect channels and or planes
            
            % Only apply subindexing if necessary
            if doCropImage && selectFrameSubset
                imArray = imArray(indexingSubs{1:end-1}, ':');

            elseif doCropImage
                imArray = obj.cropData(imArray, indexingSubs);

            elseif selectFrameSubset
                imArray = obj.selectFrameSubset(imArray, indexingSubs);
            end
            
            %imArray = squeeze(imArray);
            
            % Set data intensity limits based on current data if needed.
            if isempty( obj.DataIntensityLimits )
                obj.autoAssignDataIntensityLimits(imArray) % todo
            end
        end
        
        function writeFrameSet(obj, imageArray, frameInd)
        %writeFrameSet Write set of image frames to image stack
            
            % Get indexing subs for assigning to Data
            %[indC, indZ, indT] = obj.getFrameInd(varargin{:});
            indexingSubs = obj.getDataIndexingStructure(frameInd);
    
            % Make sure dimensions match with imageArray.
            isColon = @(x) ischar(x) && strcmp(x, ':');
            isDimensionSubset = ~cellfun(@(x)isColon(x), indexingSubs);
            dimensionLength = cellfun(@numel, indexingSubs(isDimensionSubset));
           
            % Assign imArray to indexes of Data
            
            assert(prod(dimensionLength) == prod(size(imageArray, find(isDimensionSubset)) ), ...
                'Frame indices and data size does not match')
            obj.Data(indexingSubs{:}) = imageArray;
           
        end
        
        function imArray = getCompleteFrameSet(obj, frameInd)
            % Returns a frameset disregarding current channel and current
            % plane settings
            
            indexingSubs = obj.getFullDataIndexingStructure();
            if ~ischar(frameInd) && ~strcmp(frameInd, 'all')
                indexingSubs{end} = frameInd;
            end
            
            imArray = obj.Data(indexingSubs{:});

        end
        
        function imArray = getAllFrames(obj)

        end
        
        function addToStaticCache(obj, imData, frameIndices)
            
            if ~obj.IsVirtual
                error('Data can only be added to static cache for ImageStack with virtual data')
            end
            
            % Make sure data is same size as stack...
            dataSize = obj.Data.StackSize;
            tmpSize = size(imData);
            
            if ~isequal(dataSize(3:end-1), tmpSize(3:end-1))
                warning('Data being inserted in the cache is not complete along some of the dimensions.')
                %tmpInd = repmat({':'}, 1, ndims(obj.Data));
            end
            
            obj.Data.addToStaticCache(imData, frameIndices)
            
            obj.setProjectionCacheDirty()
            
        end
        
        function insertImage(obj, newImage, insertInd, dim)
            
            %error('Down for maintentance...')
            
            if obj.IsVirtual
                error('Can not insert image into virtual data stack')
            end
            
            if nargin < 4 || isempty(dim)
                dim = 'T';
            end
            
            newImageSize = size(newImage, 1,2);
            currentImageSize = size(obj.Data, [1,2] );
            
            if all( newImageSize < currentImageSize )
                newImage = stack.reshape.imexpand(newImage, currentImageSize);
            elseif all( newImageSize < currentImageSize )
                newImage = stack.reshape.imcropcenter(newImage, currentImageSize);
            else
                % Expand along longest dimension and crop along shortest. 
                % Todo: Test this
                expandSize = max([newImageSize; currentImageSize]);
                cropSize = min([newImageSize; currentImageSize]);
                newImage = stack.reshape.imexpand(newImage, expandSize);
                newImage = stack.reshape.imcropcenter(newImage, cropSize);
            end
            
            % Todo: Make sure image which is inserted has same number of
            % channels and planes as Data
            
            isSizeEqual = isequal( size(newImage, 1, 2), currentImageSize);
            assert(isSizeEqual, 'Image dimensions do not match')
            
            
            % Todo: Adapt according to dimensions....
            obj.Data.insertImageData(newImage, insertInd)
            

            % Todo: are all "dependent" properties updated?
            
            % Todo: 
            % Make sure classes are compatible
            % Make sure it works for 4dimensional arrays as well.
            % MAke implementation for inserting stacks.
        end
        
        function removeImage(obj, location, dim)
                    
            if obj.IsVirtual
                error('Can not remove image from virtual data stack')
            end
            
            error('Not implemented')
            
        end
        
    % - Methods for getting image stack metadata
        
        function sampleRate = getSampleRate(obj)
            sampleRate = obj.Data.MetaData.SampleRate ./ obj.NumPlanes;
        end
        
        function timeStep = getTimeStep(obj)
            timeStep = obj.Data.MetaData.TimeIncrement .* obj.NumPlanes;
        end
        
        function frameTimes = getFrameTimes(obj, frameIndex)
            
            if isempty(frameIndex)
                frameIndex = 1:obj.NumTimepoints;
            end
            
            if ~isempty(obj.MetaData.FrameTimes)
                frameTimes = obj.MetaData.FrameTimes(frameIndex);
            else
                frameTimes = (frameIndex-1) .* seconds(obj.getTimeStep());
                if ~isempty(obj.MetaData.StartTime) % Todo.
                    frameTimes = frameTimes + obj.MetaData.StartTime;
                end
            end

        end
        
        function framePosition = getFramePosition(obj, frameIndex)
            
            % Todo: How to represent this is stack has multiple planes and
            % multiple timepoints?
            
            if nargin < 2
                frameIndex = [];
            end
            
            if isempty(frameIndex) || isempty(obj.MetaData.FramePosition)
                framePosition = obj.MetaData.SpatialPosition;
            else
                framePosition = obj.MetaData.FramePosition(frameIndex, :);
            end
        end

    % - Methods for getting processed versions of data
    
        function [tf, filePath] = hasDownsampledStack(obj, method, downsampleFactor)
            
            % Todo; make this work for spatial downsampling as well.
                        
            if strcmp(method, 'temporal_mean'); method = 'mean'; end
            
            args = {obj, downsampleFactor, method};
            filePath = nansen.stack.DownsampledStack.createDataFilepath(args{:});
            
            tf = isfile(filePath);
            
            if nargout == 1
                clear filePath
            end
            
        end
        
        function downsampledStack = downsampleT(obj, n, method, varargin)
        %downsampleT Downsample stack by a given factor
        %
        %   downsampledStack = obj.downsampleT(n) where n is the
        %   downsampling factor.
        %
        %   downsampledStack = obj.downsampleT(n, method) performs the
        %   downsampling using the specified method. Default is 'mean', i.e
        %   the stack is binned by n frames at a time, and the result is
        %   the mean of each bin.
        %    
        %   downsampledStack = obj.downsampleT(n, method, name, value, ...)
        %   performs the downsampling according to specified name-value
        %   parameters.
        %
        %   Downsample stack through binning frames and calculating a
        %   projection for frames within each bin. n is the binsize and
        %   method specifies what projection to compute. Method can be 
        %   'mean', 'max', 'min'
        %
        %   Output can be a virtual or a direct imageStack. Output data
        %   type will be the same as input, but can be specified...
       
        
            % TODO: validate that imagestack contains a T dimension..
            % TODO: only works for 3d stacks..
            
            if nargin < 3 || isempty(method)
                method = 'mean';
            end
        
            params = struct();
            params.SaveToFile = false;
            params.UseTemporaryFile = true;
            params.FilePath = '';
            params.OutputDataType = 'same';
            params.Verbose = false;
            
            params = utility.parsenvpairs(params, 1, varargin{:});
            
            % Rename some fields for the downsampler class
            params.TargetFilePath = params.FilePath;
            params = rmfield(params, 'FilePath');
                       
            params.TargetFileType = params.OutputDataType;
            params = rmfield(params, 'OutputDataType');
            
            % Calculate number of downsampled frames
            numFramesFinal = floor( obj.NumTimepoints / n );
            
            % Get (or set) block size for downsampling. 
            % Todo: get automatically based on memory function
            if obj.ChunkLength == inf
                chunkLength = 2000;
            else
                chunkLength = obj.ChunkLength;
            end
            
            % Determine if we need to save data to file
            if obj.IsVirtual && numFramesFinal > chunkLength
                if ~params.SaveToFile
                    params.UseTransientVirtualStack = true;
                end
                params.SaveToFile = true;
            end
            
            % Create a new TemporalDownsampler ImageStackProcessor object.
            downsampler = nansen.processing.TemporalDownsampler(obj, n, method, params);
            
            if ~downsampler.existDownsampledStack()
                downsampler.runMethod()
            end
            
            downsampledStack = downsampler.getDownsampledStack();
            
            if ~nargout
                clear downsampledStack
            end
            
        end
        
        function projectionImage = getFullProjection(obj, projectionName)
        %getFullProjection Get stack projection image from the full stack
        
            % No need to calculate again if projection already exists
            if (isfield(obj.Projections, projectionName) && ~obj.IsVirtual) || ...
                (isfield(obj.Projections, projectionName) && obj.IsVirtual && ~obj.isDirty.(projectionName))
            
                projectionImage = obj.Projections.(projectionName);
                projectionImage = obj.getProjectionSubSelection(projectionImage);
                return 
            end
            
            global fprintf % Use highjacked fprintf if available
            if isempty(fprintf); fprintf = str2func('fprintf'); end
                       
            fprintf(sprintf('Calculating %s projection...\n', projectionName))

            projectionImage = obj.getProjection(projectionName, 'cache', 'T', 'extended');
            
            % Assign projection image to stackProjection property
            obj.Projections.(projectionName) = projectionImage;
            if isempty(obj.isDirty)
                obj.isDirty = struct(projectionName, false);
            else
                obj.isDirty.(projectionName) = false;
            end
            
            projectionImage = obj.getProjectionSubSelection(projectionImage);

        end
        
        function projectionImage = getProjection(obj, projectionName, frameInd, dim, mode)
        % getProjection Get stack projection image
        %
        %   Projection is always calculated along the last dimension unless
        %   something else is specified.
            
            % Todo: Put a limit on how many images to use for getting
            % percentiles of pixel values.
        
            if nargin < 3 || isempty(frameInd); frameInd = 'cache'; end
            
            tmpStack = obj.getFrameSet(frameInd, 'extended');

            % Todo: Handle different datatypes..
            %       i.e cast output to original type. Some functions
            %       require input to be single or double...
            
            if nargin < 5
                mode = 'standard';
            end
            
            
            % Set dimension to calculate projection image over.
            
            if nargin < 4 || isempty(dim)
                % Dim should be minimum 3, but would be 2 for single frame
                if contains(obj.Data.StackDimensionArrangement, 'T')
                    dim = obj.getDimensionNumber('T');
                elseif contains(obj.Data.StackDimensionArrangement, 'Z')
                    dim = obj.getDimensionNumber('Z');
                else
                    dim = max([3, ndims(tmpStack)]);
                end

            elseif ischar(dim)
                dim = obj.getDimensionNumber(dim);
                
            else
                error('Not implemented yet')
            end
            
            % Special case if the imagedata is a single rgb frame, need to
            % find max along 4th dimensions..

            if isempty(dim)
                dim = ndims(tmpStack) + 1; % (If not T dimension is present, i.e XYC or XYZ. Todo: IS this correct in all cases 
            elseif dim == 3 && numel(obj.CurrentChannel) > 1 
                dim = 4;
            end

            % Calculate the projection image
            switch lower(projectionName)
                case {'avg', 'mean', 'average'}
                    projectionImage = mean(tmpStack, dim);
                    projectionImage = cast(projectionImage, obj.DataType);
                    
                case {'std', 'standard_deviation'}
                    P = double( prctile(single(tmpStack(:)), [0.5, 99.5]) );
                    projectionImage = std(single(tmpStack), 0, dim);
                    projectionImage = (projectionImage - (min(projectionImage(:)))) ./ ...
                        range(projectionImage(:));
                    
                    projectionImage = projectionImage .* range(P) + P(1);
                    projectionImage = cast(projectionImage, class(tmpStack));
                    %projectionImage = stack.makeuint8(projectionImage);
                case {'max', 'maximum'}
                    projectionImage = max(tmpStack, [], dim);
                    
                case 'correlation'
                    % todo
                case 'clahe'
                    % todo
                    
                otherwise
                    projFun = nansen.stack.utility.getProjectionFunction(projectionName);
                    projectionImage = projFun(tmpStack, dim);

            end
            
            if strcmp(mode, 'standard')
                projectionImage = obj.getProjectionSubSelection(projectionImage);
            end
            
        end
        
        function setProjectionCacheDirty(obj)
        %setProjectionCacheDirty Set flags for all projections to dirty. 
        % Todo: move to another class
            fieldNames = fieldnames(obj.isDirty);
            for i = 1:numel(fieldNames)
                obj.isDirty.(fieldNames{i}) = true;
            end
        end
        
        function calculateProjection(obj, funcHandle)
            
        end
        
    % - Methods for getting frame chunks 
            
        function frameInd = getMovingWindowFrameIndices(obj, frameNum, windowLength, dim)
        %getMovingWindowFrameIndices Get frame indices for binned set of frames
        %
        %   frameInd = getBinningFrames(obj, frameNum, binningSize) returns
        %   frame indices frameInd around the frame given by frameNum. The
        %   length of frameInd is determined by binningSize.
        %
        %   % If the binned frames exceeds the image stack in the beginning
        %   or the end, the number of frame indices will be cut off. Also,
        %   if the number of images in the stack are fewer than the
        %   requested bin size, the frame indices are "cut off".
        
            if nargin < 4 || isempty(dim)
                dim = 'T';
            end
        
            assert(any(strcmp(dim, {'C', 'Z', 'T'})), 'dim must be ''C'', ''Z'', or ''T''')
            numFrames = obj.getDimensionLength(dim);

            if frameNum <= ceil( windowLength/2 )
                frameInd = 1:min([numFrames, windowLength]);
                
            elseif (numFrames - frameNum) < ceil( windowLength/2 )
                frameInd = max([numFrames-windowLength+1,1]):numFrames;
            
            else
                halfWidth = floor( windowLength/2 );
                frameInd = frameNum + (-halfWidth:halfWidth);
            end
            
        end
        
        function N = chooseChunkLength(obj, dataType, pctMemoryLoad, dim)
        %chooseChunkLength Find good number of frames for batch-processing
        %
        %   N = imageStack.chooseChunkLength() returns the number of frames (N) 
        %   for an ImageStack object that would use 1/8 of the available
        %   system memory.
        %
        %   N = hImageStack.chooseChunkLength(dataType) returns the number of
        %   frames that will use 1/8 of the system memory for imagedata 
        %   which is recast to another type. dataType can be any of the 
        %   numeric classes of matlab (uint8, int8, uint16, etc, single, 
        %   double).
        %
        %   N = hImageStack.chooseChunkLength(dataType, pctMemoryLoad) 
        %   adjusts number of frames to only use a given percentage of the
        %   available memory.
        %
        %   N = hImageStack.chooseChunkLength(dataType, pctMemoryLoad, dim)
        %   find chunk length along a different dimension that default
        %   (Default = T)
        
            if nargin < 2 || isempty(dataType)
                dataType = obj.DataType;
            end
            
            if nargin < 3 || isempty(pctMemoryLoad)
                pctMemoryLoad = 1/8;
            end
            
            if nargin < 4 || isempty(dim)
                dim = 'T';
            end
            
            availMemoryBytes = utility.system.getAvailableMemory();

            % Adjust available memory according to the memory load
            availMemoryBytes = availMemoryBytes * pctMemoryLoad;

            numBytesPerFrame = obj.getImageDataByteSize(obj.FrameSize, dataType);
            
            N = floor( availMemoryBytes / numBytesPerFrame );

            % Adjust based on selected dimension.
            switch dim
                case 'T'
                    N = N / obj.NumChannels / obj.NumPlanes;
                case 'Z'
                    N = N / obj.NumChannels / obj.NumTimepoints;
                case 'C'
                    N = N / obj.NumPlanes / obj.NumTimepoints;
            end
            
            N = min([N, obj.NumTimepoints]);
        end
        
        function [IND, numChunks] = getChunkedFrameIndices(obj, numFramesPerChunk, chunkInd, dim)
        %getChunkedFrameIndices Calculate frame indices for each subpart
            
            if nargin < 2 || isempty(numFramesPerChunk)
                numFramesPerChunk = obj.ChunkLength;
            end
            
            if nargin < 3 || isempty(chunkInd)
                chunkInd = [];
            end
            
            if nargin < 4 || isempty(dim)
                dim = 'T';
            end
            
            assert(any(strcmp(dim, {'C', 'Z', 'T'})), 'dim must be ''C'', ''Z'', or ''T''')
            
            numFramesDim = obj.getDimensionLength(dim);

            % Make sure chunk length does not exceed number of frames.
            numFramesPerChunk = min([numFramesPerChunk, numFramesDim]);
            
            % If there will be more than one chunk... Adjust so that last
            % chunkSize so that last chunk is not smaller than 1/3rd of
            % the chunk size... 
            % Todo: make sure options of various methods are updated before
            % saving if chunklength is adjusted.
% % %             if numFramesDim > numFramesPerChunk
% % %                 numFramesPerChunk = obj.autoAdjustChunkLength(numFramesPerChunk, numFramesDim);
% % %             end

            % Determine first and last frame index for each chunk
            firstFrames = 1:numFramesPerChunk:numFramesDim;
            lastFrames = firstFrames + numFramesPerChunk - 1;
            lastFrames(end) = numFramesDim;
            
            % Create cell array of frame indices for each block/part.
            numChunks = numel(firstFrames);
            IND = arrayfun(@(i) firstFrames(i):lastFrames(i), 1:numChunks, 'uni', 0);
           
            if ~isempty(chunkInd)
                if numel(chunkInd) == 1
                    IND = IND{chunkInd}; % Return as array
                else
                    IND = IND(chunkInd); % Return as cell array
                end
                
            end
            
            if nargout == 1
                clear numChunks
            end
        end
        
        function numFramesPerChunk = autoAdjustChunkLength(obj, numFramesPerChunk, numFramesDim)
        %autoAdjustChunkLength Adjust chunklength to avoid short last chunk    
           
            fractionalSize = 1/3;
            
            % Check how many frames are part of last chunk:
            numFramesLastChunk = mod(numFramesDim, numFramesPerChunk);
            if numFramesLastChunk < numFramesPerChunk * fractionalSize
                numChunks = floor(numFramesDim / numFramesPerChunk);
                numFramesPerChunk = numFramesPerChunk + ceil(numFramesLastChunk/numChunks);
            end
            
        end
        
        function [imArray, IND] = getFrameChunk(obj, chunkNumber)
            
            IND = obj.getChunkedFrameIndices([], chunkNumber);
            imArray = obj.getFrameSet(IND);

            % Todo: This only works as intended if T is the last
            % dimension..
            
            if nargout == 1
                clear IND
            end
            
        end
        
    % - Methods for getting data specific information
        
        function dimNum = getDimensionNumber(obj, dimName)
            dimNum = strfind(obj.Data.StackDimensionArrangement, dimName);
        end
        
        function cLim = getDataIntensityLimits(obj)
            
            if isempty(obj.DataIntensityLimits)
                obj.autoAssignDataIntensityLimits()
            end
            
            cLim = obj.DataIntensityLimits;
            
        end
    
        function length = getDimensionLength(obj, dimName)
        %getDimensionLength Get length of dimension given dimension label
        %
        %   TODO: Combine with private method getStackDimensionLength
        
            switch dimName
                case {'T', 'Time'}
                    length = obj.NumTimepoints;
                case {'C', 'Channel'}
                    length = obj.NumChannels;
                case {'Z', 'Plane'}
                    length = obj.NumPlanes;
                case {'X', 'Width', 'ImageWidth'}
                    length = obj.ImageWidth;
                case {'Y', 'Height', 'ImageHeight'}
                    length = obj.ImageHeight;
            end
            
        end

        function tf = isDummyStack(obj)
        %isDummyStack Check is stack is dummy, i.e contains only nan values
            
            tf = false;
        
            if isa(obj.Data, 'nansen.stack.data.MatlabArray')
                data = obj.getFrameSet('all');
                tf = all( isnan( data(:) ) );
            end
        
        end

        function tf = isvirtual(obj)
            tf = isa(obj.Data, 'nansen.stack.data.VirtualArray');
        end
        
        function enablePreprocessing(obj, varargin)
        %enablePreprocessing Enable preprocessing of data on retrieval
            obj.Data.enablePreprocessing(varargin{:})
        end
        
        function disablePreprocessing(obj, varargin)
        %disablePreprocessing Disable preprocessing of data on retrieval
            obj.Data.disablePreprocessing(varargin{:})
        end
    end
    
    methods % Set/get methods
        
        function metadata = get.MetaData(obj)
            metadata = obj.Data.MetaData;
        end
        
        function set.Data(obj, newValue)
            
            if isequal(obj.Data, newValue)
                obj.Data = newValue;
            else % Trigger onDataSet to update internal properties
                obj.Data = newValue;
                if ~isempty(newValue)
                    obj.onDataSet()
                end
            end
        end
        
        function set.CurrentChannel(obj, newValue)
            msg = 'CurrentChannel must be a vector where all elements are in the range of number of channels';
            assert(all(ismember(newValue, 1:obj.NumChannels)), msg) %#ok<MCSUP> This should not be a problem because...
            
            obj.CurrentChannel = newValue;
        end
        
        function set.CurrentPlane(obj, newValue)
            msg = sprintf('CurrentPlane must be a vector where all elements are in the range of [1, %d]', obj.NumPlanes); %#ok<MCSUP>
            assert(all(ismember(newValue, 1:obj.NumPlanes)), msg) %#ok<MCSUP> This should not be a problem because...
            
            obj.CurrentPlane = newValue;
        end
      
        function set.ColorModel(obj, newValue)
            %= 'RGB' % Mono, rgb, custom
            msg = 'ColorModel must be ''BW'', ''Grayscale'', ''RGB'' or ''Custom''';
            assert(any(strcmp({'BW', 'Grayscale', 'RGB', 'Custom'}, newValue)), msg)
            obj.ColorModel = newValue; 
        end
        
        function set.DimensionOrder(obj, newValue)
            if isempty(obj.Data); return;end
            obj.Data.StackDimensionArrangement = newValue;
            obj.onDataDimensionOrderChanged()
        end
        
        function value = get.DimensionOrder(obj)
            if isempty(obj.Data); return;end
            value = sprintf('%s (%s)', obj.Data.StackDimensionArrangement, ...
                obj.DimensionNames);
        end
        
        function set.DataDimensionOrder(obj, newValue)
            if isempty(obj.Data); return;end
            obj.Data.DataDimensionArrangement = newValue;
            obj.onDataDimensionOrderChanged()
        end
        
        function value = get.DataDimensionOrder(obj)
            if isempty(obj.Data); return;end
            value = sprintf('%s (%s)', obj.Data.DataDimensionArrangement, ...
                obj.DimensionNames);
        end
        
        function names = get.DimensionNames(obj)
            [~, ~, iB] = intersect(obj.Data.StackDimensionArrangement, ...
                obj.DEFAULT_DIMENSION_ORDER, 'stable');
            
            names = strjoin(obj.DIMENSION_LABELS(iB), ' x ');
            
        end
        
        function dimLength = get.ImageHeight(obj)
            dimLength = obj.getStackDimensionLength('Y');
        end
        
        function dimLength = get.ImageWidth(obj)
            dimLength = obj.getStackDimensionLength('X');
        end
        
        function dimLength = get.NumChannels(obj)
            dimLength = obj.getStackDimensionLength('C');
        end
        
        function dimLength = get.NumPlanes(obj)
            dimLength = obj.getStackDimensionLength('Z');
        end
        
        function dimLength = get.NumTimepoints(obj)
            dimLength = obj.getStackDimensionLength('T');
        end
        
        function dataType = get.DataType(obj)
            dataType = obj.Data.DataType;
        end
        
        function set.ChunkLength(obj, newValue)
            
            classes = {'numeric'};
            attributes = {'integer', 'nonnegative'};
            validateattributes(newValue, classes, attributes)
                
            if obj.ChunkLength == inf || obj.ChunkLength == newValue
                obj.ChunkLength = newValue;
            else
                warning('ChunkLength is already set and can not be set again')
            end
            
        end
        
        function set.DynamicCacheEnabled(obj, newValue)
            obj.Data.UseDynamicCache = newValue;
            obj.onDynamicCacheEnabledChanged()
        end
        
        function state = get.DynamicCacheEnabled(obj)
            state = obj.Data.UseDynamicCache;
        end

        function tf = get.HasStaticCache(obj)
            
            tf = false;
            
            if obj.IsVirtual
                tf = obj.Data.HasStaticCache;
            end

        end
        
        function numChunks = get.NumChunks(obj)
            % Todo: Depend on chunking dimension..
            numChunks = ceil( obj.numTimepoints / obj.ChunkLength );
        end
        
        function numFrames = get.NumFrames(obj)
            %numFrames = obj.NumChannels * obj.NumPlanes * obj.NumTimepoints;
            
            numFrames = numel(obj.CurrentChannel) .* numel(obj.CurrentPlane) * obj.NumTimepoints;
            
        end
        
        function frameSize = get.FrameSize(obj)
            frameSize = [obj.ImageHeight, obj.ImageWidth];
        end
        
        function clim = get.DataTypeIntensityLimits(obj)
            clim = obj.getDataTypeIntensityLimits(obj.DataType);
            if strcmp(obj.DataType, 'single') ||  strcmp(obj.DataType, 'double')
                clim(1) = min([clim(1), obj.DataIntensityLimits]);
                clim(2) = max([clim(2), obj.DataIntensityLimits]);
            end
            
        end
        
        function physicalSize = get.ImagePhysicalSize(obj)
            physicalSize = [obj.MetaData.PhysicalSizeX .* obj.ImageWidth, ...
                obj.MetaData.PhysicalSizeY .* obj.ImageHeight];
            physicalSize = round(physicalSize, 1);
        end
        
        function physicalUnits = get.ImagePhysicalUnits(obj)
            physicalUnits = {obj.MetaData.PhysicalSizeXUnit, obj.MetaData.PhysicalSizeYUnit};
        end
        
        function stackDuration = get.StackDuration(obj)
            stackDuration = obj.NumTimepoints * seconds(obj.getTimeStep);
            stackDuration.Format = 'hh:mm:ss'; 
        end
    end

    methods (Access = private) % Internal methods
        
        function projectionImage = getProjectionSubSelection(obj, projectionImage)
            indexingSubs = obj.getDataIndexingStructure(1);
            projectionImage = projectionImage(indexingSubs{:});
        end
        
    % - Methods for getting the indices according to the dimension order
        
        function [indC, indZ, indT] = getFrameInd(obj, varargin)
        %getFrameInd Get frame indices for the each dimension (C, Z, T)
        
            % Todo: input validation...
        
            if ischar(varargin{1}) && strcmp(varargin{1}, 'all')
                
                indC = obj.CurrentChannel;
                indZ = obj.CurrentPlane;
                indT = 1:obj.NumTimepoints;

            else
                
                % Initialize:
                [indC, indZ, indT] = deal(1);
            
                for i = 1:numel(varargin)
                    
                    thisDim = obj.DataDimensionOrder(end-i+1); % Start from end
                    
                    switch thisDim
                        case 'T'
                            indT = varargin{i};
                        case 'C'
                            indC = varargin{i};
                        case 'Z'
                            indZ = varargin{i};
                    end
            
                end
                
                % Todo: Add checks to ensure indices stays within valid
                % range
                
            end
            
        end
        
        function subs = getDataIndexingStructure(obj, frameInd, varargin)
        %getDataIndexingStructure Get cell of subs for indexing data
        %
        %   Returns a cell array of subs for retrieving data given a list
        %   of frameInd. frameInd is a list of frames to retrieve, where
        %   the frames are taken from the last dimension of data (assuming
        %   the last dimension is time (T) or depth (Z). 
        %
        %   Subs for the image X- and Y- dimensions based on the values of
        %   the properties DataXLim and DataYLim, while subs for channels
        %   are set based on the CurrentChannel property. If the stack is 
        %   5D, containing both time and depth, the planes will be selected 
        %   according to the CurrentPlane property.
        % 
        %   Note, if frameInd is equal to 'all', the subs of the last
        %   dimension will be equivalent to ':'
            
            numDims = ndims(obj.Data);
            
            S = utility.nvpairs2struct(varargin{:});
            
            % Initialize list of subs
            subs = cell(1, numDims);
            subs(:) = {':'};
            
            for i = 1:numDims
                % Get subs according to stack dimension arrangement
                thisDim = obj.Data.StackDimensionArrangement(i);
                
                switch thisDim
                    case 'C'
                        subs{i} = obj.CurrentChannel;
                        
                    case 'Z'
                        
                        if ~contains(obj.Data.DataDimensionArrangement, 'T')
                            if ischar(frameInd) && strcmp(frameInd, 'all')
                                subs{i} = 1:obj.NumPlanes;
                            else
                                subs{i} = frameInd;
                            end
                        else
                            subs{i} = obj.CurrentPlane;
                        end
                        
                    case 'T'
                        if ischar(frameInd) && strcmp(frameInd, 'all')
                            subs{i} = 1:obj.NumTimepoints;
                        else
                            subs{i} = frameInd;
                        end

                        
                        % Make sure requested frame indices are in range.
                        if isnumeric(subs{i})
                            isValid = subs{i} >= 1 & subs{i} <= obj.NumTimepoints;
                            if any(~isValid)
                                error('Invalid data indexing along T dimension')
                            end
                            %subs{i} = subs{i}(isValid);
                        end
                        
                        % Todo: Generalize and do this for all dimensions
                    
                    case 'X'
                        if isfield(S, 'X')
                            subs{i} = S.X;
                        elseif ~all(obj.DataXLim==0)
                            subs{i} = obj.DataXLim(1):obj.DataXLim(2);
                        end
                        
                    case 'Y'
                        if isfield(S, 'Y')
                            subs{i} = S.Y;
                        elseif ~all(obj.DataYLim==0)
                            subs{i} = obj.DataYLim(1):obj.DataYLim(2);
                        end
                end
            end
            
            
%             % Special case for 2d images.a
%             if numDims == 2 && frameInd == 1
%                 subs{end+1} = frameInd;
%             end
            
        end
        
        function subs = getFullDataIndexingStructure(obj, frameInd)
        %getFullDataIndexingStructure Get cell of subs for indexing data
        %
        %   Returns a cell array of subs for retrieving data given a list
        %   of frameInd. frameInd is a list of frames to retrieve, where
        %   the frames are taken from the last dimension of data (assuming
        %   the last dimension is time (T) or depth (Z). If frameInd is
        %   empty, all frames along that dimension are selected
        %
        %   Subs for all the dimensions except for the T (or Z) will be set
        %   based on the length of that dimension. So, in contrast to the
        %   method getDataIndexingStructure, DataXLim, DataYLim,
        %   CurrentChannel and CurrentPlane is not considered.

            if nargin < 2; frameInd = []; end
            
            numDims = numel(obj.Data.StackDimensionArrangement);
            
            % Initialize list of subs
            subs = cell(1, numDims);
            for i = 1:numDims
                thisDim = obj.Data.StackDimensionArrangement(i);
                
                switch thisDim
                    case 'Z'
                        if ~contains(obj.Data.StackDimensionArrangement, 'T')
                            if isempty(frameInd) || (ischar(frameInd) && strcmp(frameInd, 'all'))
                                subs{i} = 1:obj.NumTimepoints;
                            else
                                subs{i} = frameInd;
                            end
                        else
                        	subs{i} = 1:obj.getDimensionLength(thisDim); 
                        end
                    case 'T'
                        if isempty(frameInd) || (ischar(frameInd) && strcmp(frameInd, 'all'))
                            subs{i} = 1:obj.NumTimepoints;
                        else
                            subs{i} = frameInd;
                        end
                    otherwise
                        subs{i} = ':';
                end
            end
            
        end
        
    % - Methods for getting subsets of data
    
        function imArray = cropData(obj, imArray, indexingSubs) %#ok<INUSL>
            % Todo: make sure we crop x and y dimensions. I.e what if the
            % stack is a weird configuration where x- and y are not 1st and
            % 2nd dimension?
            
            indexingSubsTmp = indexingSubs;
            indexingSubsTmp(3:end) = {':'};
            
            imArray = imArray(indexingSubsTmp{:});
        end
        
        function imArray = selectFrameSubset(obj, imArray, indexingSubs)
            dimT = obj.getDimensionNumber('T');
            indexingSubsTmp = indexingSubs;
            indexingSubsTmp(1:2) = {':'};
            indexingSubsTmp(dimT) = {':'};
            imArray = imArray(indexingSubsTmp{:});
        end
    
        
    % - Methods for assigning property values based on data
        
        function autoAssignDataIntensityLimits(obj, tmpData)
            %autoAssignDataIntensityLimits Set brightness limits of stack
        
            % Get a subset of of the image data
            if nargin < 2 || isempty(tmpData)
                tmpData = obj.getFrameSet(1:min([31, obj.NumTimepoints]));
            end
            
            [S, L] = bounds(tmpData(:));

            if isnan(S); S = 0; end
            if isnan(L); L = 1; end
            
            obj.DataIntensityLimits = double( [S, L] );
        end
        
        function autoAssignColorModel(obj)
        
            if obj.NumChannels == 1
            	obj.ColorModel = 'Grayscale';
            elseif obj.NumChannels == 3
            	obj.ColorModel = 'RGB';
            else
                obj.ColorModel = 'Custom';
                if isempty(obj.CustomColorModel)
                    obj.CustomColorModel = hsv(obj.NumChannels);
                end
            end
            
            % Todo: Set CustomColorModel, i.e color for each channel
            
            
            if islogical(obj.Data)
                obj.ColorModel = 'BW';
            end
            
            % Todo: what if there are multichannel logical arrays?
            
        end
        
        function onCachedDataChanged(obj, src, evt)
        %onCachedDataChanged Callback for cache changed event
        
        % This method is used for resetting the projection "cache", i.e the
        % projection images that are stored in the Projections property.
            
            persistent counter resetProjectionCacheInterval
            if isempty(counter); counter = 0; end
            if isempty(resetProjectionCacheInterval); resetProjectionCacheInterval = 10; end
            
            % Todo: selective reset, ie some projections are heavier and
            % should be reset less often. 
            
            counter = counter + 1;
            if mod(counter, resetProjectionCacheInterval) == 0
                obj.setProjectionCacheDirty()
                
                if resetProjectionCacheInterval < 50
                    resetProjectionCacheInterval = resetProjectionCacheInterval + 10;
                end

            end
            % Todo: Set projection images to dirty. Only do this every once
            % in a while...
            %disp('Cache changed...')
        end
        
    % - Methods for getting dimension lengths
        
        function dimLength = getStackDimensionLength(obj, dimLabel)
            
            ind = strfind(obj.Data.StackDimensionArrangement, dimLabel);
                
            if isempty(ind)
                dimLength = 1;
            else
                dimLength = size(obj.Data, ind);
            end

        end
        
        function assertEnoughMemoryForFrameRequest(obj, indexingSubs)
            
            persistent nAvailMemoryBytes
            if isempty(nAvailMemoryBytes)
                nAvailMemoryBytes = utility.system.getAvailableMemory();
            end
            
            requestedArraySize = zeros(size(indexingSubs));
            
            for i = 1:length(requestedArraySize)
                if ischar(indexingSubs{i}) && strcmp(indexingSubs{i}, ':')
                    requestedArraySize(i) = obj.Data.StackSize(i);
                else
                    requestedArraySize(i) = numel(indexingSubs{i});
                end
            end
            
            nRequestedBytes = obj.getImageDataByteSize(...
                requestedArraySize, obj.DataType);

                
            if nRequestedBytes > nAvailMemoryBytes
                arraySizeChar = strjoin(arrayfun(@(x) num2str(x), requestedArraySize, 'uni', 0), 'x');
                numBytesGb = nRequestedBytes / 1024^3;
                
                exception = MException('MATLAB:array:SizeLimitExceeded', ...
                    'Requested %s (%.1f GB) array exceeds maximum array size preference.', ...
                    arraySizeChar, numBytesGb);
                
                throwAsCaller(exception)
            end
        end
    end
    
    methods (Access = private) % Callbacks for property value set
        
        function onDataSet(obj)
            
            % Set some property values that depends on whether data is
            % virtual or not.
            if isa(obj.Data, 'nansen.stack.data.VirtualArray')
                obj.IsVirtual = true;

                % Update cache dependent properties.
                obj.onDynamicCacheEnabledChanged()
                
                obj.FileName = obj.Data.FilePath;
                [~, obj.Name] = fileparts(obj.Data.FilePath);
                
            else
                
                obj.IsVirtual = false;

                if ~isempty(obj.CacheChangedListener)
                    delete(obj.CacheChangedListener)
                    obj.CacheChangedListener = [];
                end

            end
            
            if ~obj.IsVirtual
                obj.autoAssignDataIntensityLimits()
            end
            
            % Set size
            obj.onDataDimensionOrderChanged()

            obj.CurrentChannel = 1:obj.NumChannels;
            
        end
        
        function onDataDimensionOrderChanged(obj)
            
            % This is outsource to ImageStackData..
            % IS there any reason to keep this method??
            
% %             stackSize = size(obj.Data);
% %             
% %             % Assign property value for each of the dimension lengths
% %             for i = 1:numel(obj.DEFAULT_DIMENSION_ORDER)
% %                 
% %                 thisDim = obj.DEFAULT_DIMENSION_ORDER(i);
% %                 ind = strfind(obj.Data.StackDimensionArrangement, thisDim);
% %                 
% %                 if isempty(ind)
% %                     dimLength = 1;
% %                 else
% %                     dimLength = stackSize(ind);
% %                 end
% %                 
% %                 switch thisDim
% %                     
% %                     case 'Y'
% %                         obj.ImageHeight = dimLength;
% %                     case 'X'
% %                         obj.ImageWidth = dimLength;
% %                     case 'C'
% %                         obj.NumChannels = dimLength;
% %                     case 'Z'
% %                         obj.NumPlanes = dimLength;
% %                     case 'T'
% %                         obj.NumTimepoints = dimLength;
% %                 end
% %                 
% %             end
        end
        
        function onDynamicCacheEnabledChanged(obj)
            
            switch obj.DynamicCacheEnabled
                case {'on', true}
                    obj.CacheChangedListener = listener(obj.Data, ...
                        'DynamicCacheChanged', @obj.onCachedDataChanged);
                case {'off', false}
                    if ~isempty(obj.CacheChangedListener)
                        delete(obj.CacheChangedListener)
                        obj.CacheChangedListener = event.listener.empty;
                    end
                otherwise
                    warning('Value of DynamicCacheChanged is not valid')
            end
            
        end
        
    end
    
    methods (Static)
        
        function imageStack = validate(imageData)
        %validate Validate image stack
        %
        % This function checks if a variable/object is an image array or an
        % ImageStack object. If the variable is numeric and has 3 or more
        % dimension, it is returned as an ImageStack.
            
            % If image data is numeric, place it in an ImageStack object.                
            if isa(imageData, 'numeric')
                message = 'Image data must have at least 2 dimensions';
                assert( ndims(imageData) >= 2, message ) %#ok<ISMAT>
                imageStack = nansen.stack.ImageStack(imageData);
                
            elseif isa(imageData, 'nansen.stack.data.abstract.ImageStackData')
                imageStack = nansen.stack.ImageStack(imageData);
                
            elseif isa(imageData, 'nansen.stack.ImageStack')
                imageStack = imageData;
                
            else
                errorId = 'NANSEN:Stack:InvalidImageStack';
                throw(nansen.stack.getException(errorId))
            end
            
        end
        
        function tf = isStackComplete(fileRef, numChunks)
        %isStackComplete Check if image stack is complete 
        %
        %   Note, check that a random subset of frames are not just zeros.
        
        % Todo: Adjust number of random frames to load based on the number
        % of chunks. Bigger chunks, fewer frames
        
            if isa(fileRef, 'char')
                imageStack = nansen.stack.ImageStack(fileRef);
            elseif isa(fileRef, 'nansen.stack.ImageStack')
                imageStack = fileRef;
            else
                error('Invalid input')
            end
            
            % Pick 100 random frames.
            numFrames = min([imageStack.NumTimepoints, 100]);
            randFrameIdx = randperm(imageStack.NumTimepoints, numFrames);
            
            data = imageStack.getFrameSet(sort(randFrameIdx));
            tf = all( mean(mean(data,2),1) ~= 0 );
            
        end
        
        function byteSize = getImageDataByteSize(imageSize, dataType)
            
            switch dataType
                case {'uint8', 'int8', 'logical'}
                    bytesPerPixel = 1;
                case {'uint16', 'int16'}
                    bytesPerPixel = 2;
                case {'uint32', 'int32', 'single'}
                    bytesPerPixel = 4;
                case {'uint64', 'int64', 'double'}
                    bytesPerPixel = 8;
            end
            
            byteSize = prod(imageSize) .* bytesPerPixel;
            
        end
        
        function limits = getDataTypeIntensityLimits(dataType)
            
            switch dataType                    
                case 'uint8'
                    limits = [0, 2^8-1];
                case 'uint16'
                    limits = [0, 2^16-1];
                case 'uint32'
                    limits = [0, 2^32-1];
                case 'int8'
                    limits = [-2^7, 2^7-1];
                case 'int16'
                    limits = [-2^15, 2^15-1];
                case 'int32'
                    limits = [-2^31, 2^31-1];
                case {'single', 'double', 'logical'}
                    limits = [0, 1];
            end
            
        end
        
    end
    
    methods (Static) %Methods in separate files
        data = initializeData(datareference, varargin)
        
    end
    
end