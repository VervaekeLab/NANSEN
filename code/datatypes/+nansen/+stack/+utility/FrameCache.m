classdef FrameCache < handle %< utility.class.StructAdapter
%nansen.stack.utility.FrameCache Implement a cache for stack data read with a FileAdapter.
%
%   This class can be used with a nansen.stack.data.VirtualArray instance 
%   to increase performance when reading frames from files on a harddrive.
%
%   The cache deposits and withdraws framedata along the last dimension. If
%   the cache belongs to a 4D or 5D stack, all frames of the 3rd (and 4th)
%   dimension are cached.
%
%   Common use case: 
%       When viewing data in imviewer, or if it is expected that data is
%       accessed more than once.
%
%   
%   USAGE: 
%
%       frameCache = nansen.stack.utility.FrameCache(sz, cls) creates a
%       framecache with the default length of 1000 frames. 
%
%       frameCache = nansen.stack.utility.FrameCache(..., cacheLength)
%       creates a framecache with the specified length. 


%   Note: For 4D (or 5D stacks), all frames for the 3rd (and 4th) dimension
%   are cached. This might in some cases not be very efficient, i.e if a
%   stack is open where the current channels (and/or planes) are set to a
%   subset of all available. An improvement would be to cache subsets of
%   frames along these dimensions as well, possibly using the frame
%   deinterleaver class in order to have a "1D" cache for up to "3D" frame
%   indices.


%   In a perfect world, there would be an abstract framecache class and
%   a static and a dynamic subclass.
%
%       [ ] Should be possible to specify to cache only a subset of each 
%           of the dimensions... Not Urgent, Not Important
%       [ ] Swap names for cachelength and num frames...


    properties        
        Mode = 'dynamic'        % 'dynamic' or 'static'
        CacheLength = 1000      % Length of the number of frames in cache (in total)
        LeadingDimension        % Not implemented yet.
    end
    
    % Dependent
    properties (Dependent)
        NumFrames               % Number of image frames to cache (along last dimension)
        CacheSize               % Size of data in cache
        CacheRange              % First and last frame index in the cache
    end
    
    properties (SetAccess = private)
        DataSize = []           % Size of data that is being cached
        DataType = []           % Type of data that is being cached     
    end
    
    properties (Access = private)
        Data = []               % Holds the cached data
        
        CachedFrameIndices = []  % Indices of image frames that are present in the cache
        CachedFrameBoolMap = [] % Indices of image frames that are present in the cache
        
        CacheIndices = 0;       % Rolling subset of indices where data is inserted into the chache
    end
    
    properties (Access = private)
        CacheSize_
    end


    methods % Constructor
        
        function obj = FrameCache(dataSize, dataType, cacheLength, varargin)

            obj.DataSize = dataSize;
            obj.DataType = dataType;
            
            if nargin < 3 || isempty(cacheLength)
                obj.adaptCacheLength()
            else
                obj.CacheLength = cacheLength;
            end
            
            % Will assign mode if any of the varargin is 'static' or 'dynamic'
            obj.getModeFromVarargin(varargin{:});
            
            obj.getLeadingDimFromVarargin(varargin{:})
                        
            % Initialize
            if strcmp(obj.Mode, 'dynamic')
                obj.initialize();
            end
            
        end
    
    end
    
    methods % set
        
        function set.CacheLength(obj, newValue)
            newValue = obj.validateCacheLength(newValue);
            
            obj.CacheLength = newValue;
            obj.onCacheLengthChanged()
        end
        
        function set.CacheSize(obj, newValue)
            obj.validateCacheLength(newValue)
            
            obj.CacheSize_ = newValue;
            obj.CacheLength = prod(newValue);
        end
        
        function cacheSize = get.CacheSize(obj)
            cacheSize = obj.CacheSize_;
            cacheSize = [obj.DataSize(1:2), cacheSize];
        end

        function cacheRange = get.CacheRange(obj)
            cacheRange = [min(obj.CachedFrameIndices), ...
                max(obj.CachedFrameIndices)];
        end
        
        function numFrames = get.NumFrames(obj)
            numFrames = obj.CacheSize_(end);
        end
    end
    
    methods (Access = private)
        
        function subs = getCacheSubs(obj, frameIndices)
                
            subs = cell(1, max([3, ndims(obj.Data)]));
            subs(:) = {':'};
            subs{obj.LeadingDimension} = frameIndices;

        end
        
        function cacheLength = validateCacheLength(obj, cacheLength)
        % validateCacheLength Make sure cache length is valid according to
        % the size of the data
        
            if numel(cacheLength) == 1
        
                if cacheLength > obj.DataSize(end)
                    cacheLength = obj.DataSize(end);
                end

            else
                nRequiredEntries = numel(obj.DataSize)-2;
            
                msg = sprintf('The specified cache size must have %d entries', ...
                    nRequiredEntries);
                assert(numel(cacheLength) == nRequiredEntries, msg)
                
                cacheLength = prod(cacheLength);
            end
            
            if ~nargout 
                clear cacheLength
            end
                
        end
        
        function adaptCacheLength(obj, cacheLength)
        %updateCacheLength Update cache length if data is set. Cache length
        % is adapted to fit with the length of dimensions of the dataset.
        %
        % This function updates the cache length so that it is set
        % according to the data size.
            
            if nargin < 2
                cacheLength = obj.CacheLength;
            end
            
            if numel(obj.DataSize) > 3
                                
                % Find cacheSize so that prod(cacheSize) = cacheLength,
                % keeping the length of the last dimension unfixed...
                
                cacheSize = obj.DataSize(3:end);
                cacheSize(end) = round( cacheLength ./ prod(cacheSize(1:end-1)) );
                
                if cacheSize(end) > obj.DataSize(end)
                    cacheSize(end) = obj.DataSize(end);
                end
                
                % Adapt cache length based on the assigned CacheSize
                obj.CacheLength = prod(cacheSize);
                obj.CacheSize_ = cacheSize;
            end
            
        end
        
        function setCacheSize(obj)
        %setCacheSize Set cache size (ND) based on cache length (1D)
        
            cacheLength = obj.CacheLength;
            cacheSize = obj.DataSize(3:end);
            if isempty(cacheSize); cacheSize = 1; end


            if isscalar(cacheLength) && ~isscalar(cacheSize)
                cacheSize(end) = cacheLength ./ prod(cacheSize(1:end-1));
                cacheSize = round(cacheSize);
            else
                assert(ndims(cacheLength)==ndims(cacheSize), 'Cache length must be of size n-2 where n is the number of dimensions in the data')
                cacheSize = cacheLength;
            end
            
            % If this assertion fails, either the cache length has been set
            % to a number that does not match the data size (which should
            % not happend), or this function is called before a valid cache
            % length has been set, which should also not happen. So in
            % other words, if this fails, I have made a mistake somewhere..
            assert(mod(cacheSize(end), 1) == 0, ...
                'Cache length does not match length of data dimensions')
            
            obj.CacheSize_ = cacheSize;
            
        end
        
        function varargin = getModeFromVarargin(obj, varargin)
            % Get mode from varargin if present.
            
            isChar = cellfun(@(c) ischar(c), varargin);
            
            if ~any(isChar)
                return
            else
                charInputs = varargin(isChar);
                isModeInput = cellfun(@(c) any(strcmp(c, {'static', 'dynamic'})), charInputs);
                
                if any(isModeInput)
                    assert(sum(isModeInput)==1, 'Only one mode allowed...')
                    obj.Mode = charInputs{isModeInput};
                    
                    ind = find(isChar);
                    ind = ind(isModeInput);
                    
                    varargin(ind) = [];
                end
                
            end
            
            if ~nargout
                clear varargout
            end
            
        end
        
        function getLeadingDimFromVarargin(obj, varargin)
           
            nvPairs = utility.getnvpairs(varargin);
            nvPairs = utility.nvpairs2struct(nvPairs);
            
            if isfield(nvPairs, 'LeadingDimension')
                obj.LeadingDimension = nvPairs.LeadingDimension;
            else
                obj.LeadingDimension = numel(obj.DataSize);
            end
            
        end
        
        function initialize(obj)
            
            % Dimensionality of stacks are always in the order of XYCZT.
            % If any of C or Z is missing, data is squeezed, so if number
            % of channels and number of planes are 1, the stack
            % dimensionality is XYT. 
            
            % Determine size for cached data
            if numel(obj.CacheLength) == 1
                cacheSize = [obj.DataSize(1:end-1), obj.CacheLength];
            else
                cacheSize = obj.CacheLength;
            end
            
            obj.Data = zeros(cacheSize, obj.DataType);
            obj.CachedFrameIndices = zeros(1, obj.CacheLength);
        end
        
        function onCacheLengthChanged(obj)
            
            obj.setCacheSize()
            
            if isempty(obj.Data); return; end % Return on initialization.
            
            % Update the data and related properties to reflect a new cache
            % length.
            
            cacheLengthOld = numel(obj.CachedFrameIndices);
            cacheLengthDiff = abs(cacheLengthOld - obj.NumFrames);

            % Update cache indices (where to insert or remove)
            %obj.CacheIndices = obj.CacheIndices(end) + (1:cacheLengthDiff);
            tmpInd = obj.CacheIndices(end) + (1:cacheLengthDiff);
            
            if obj.CacheLength > cacheLengthOld % Insert more data

                % Insert new frames at the current cache indices
                obj.CachedFrameIndices = utility.insertIntoArray(obj.CachedFrameIndices, ...
                    zeros(1, cacheLengthDiff), tmpInd, 2 );
                
                try
                    newData = zeros([obj.DataSize(1:end-1), cacheLengthDiff], obj.DataType);
    
                    % Insert data along the last dimension of data (should be 3rd...)
                    obj.Data = utility.insertIntoArray(obj.Data, ...
                        newData, tmpInd, ndims(obj.Data) );
                catch ME
                    try %#ok<TRYNC>
                        % This try block is a quickfix for the case when
                        % the cache size is set to a number which produce a
                        % an array with a datasize which exceeds the
                        % maximum allowed data size (memory) for a matlab
                        % array. The cache length is reset to the old
                        % length, but this means it tries to delete frames
                        % from the data cache. However, since the expansion
                        % of the data cache failed, reducing it will also
                        % fail (the following line below:
                        %   obj.Data(subs{:}) = [];
                        % 
                        % A proposed fix is to be able to set the
                        % cache length without automatically trying to
                        % adjust the size of tha data cache.
                        % Todo: Set cachelength without adjusting data..
                        obj.CacheLength = cacheLengthOld;
                    end
                    rethrow(ME)
                end

            elseif obj.CacheLength < cacheLengthOld % Remove data

                % Use mod to work in a circular manner on the cache
                tmpInd = mod(tmpInd-1, cacheLengthOld)+1;

                obj.CachedFrameIndices(tmpInd) = [];
                
                subs = obj.getCacheSubs(tmpInd);
                obj.Data(subs{:}) = [];

                % Need to update cacheIndices because the current cache
                % position might have been cut off while reducing the size
                % of the cache. Use -1, +1 to correct for end point, which
                % will be zero after mod operation.
                obj.CacheIndices = mod(obj.CacheIndices-1, obj.NumFrames)+1;
                
            end
            
        end

    end
    
    methods
        
        function hitMiss = queryData(obj, frameIndices)
        %QUERYDATA Check if frames are available in the cache
        %
        %   hitMiss = queryData(obj, frameIndies) returns a logical vector
        %   (hitMiss) the same length as frameIndices where each element of
        %   hitMiss is true if the frame is available and false if the data
        %   is not available.
            
            hitMiss = ismember(frameIndices, obj.CachedFrameIndices);
        
        end
        
        function [frameData, hitIndices, missIndices] = fetchData(obj, frameIndices)
        %FETCHDATA Return data if available in cache
        %
        %   [frameData, hitIndices] = fetchData(obj, frameIndices) returns
        %   stackData and those indices (hitIndices) that were available in
        %   the cache. 
        
        %   % Todo: make sure data is provided in stable order (i.e
        %   according the order of frame indices)?
        
            if isempty(obj); frameData = []; return; end 
            
            % Todo: Should make 2 classes, dynamic and static and implement
            % these methods differently
            if nargin < 2 && strcmp( obj.Mode, 'static')
                frameData = obj.Data; return
            end
            
            if nargin < 2
                isRequested = obj.CachedFrameIndices ~= 0;
            else
                isRequested = ismember(obj.CachedFrameIndices, frameIndices);
            end
            
            subs = obj.getCacheSubs(isRequested);
            frameData = obj.Data(subs{:});
            
            if nargin < 2; return; end
            
            hitIndices = obj.CachedFrameIndices(isRequested);
            isProvided = obj.queryData(frameIndices);
            missIndices = frameIndices(~isProvided);
        end
        
        function submitData(obj, frameData, frameInd)
        %SUBMITDATA Submit data to the cache.
        %
        %   obj = submitData(obj, imdata, frInd) inserts the imdata and
        %   saves the corresponding frameIndices for later retrieval.
        
            if isempty(frameInd)
                return
            end
        
            % Todo: Only insert frames that are not inserted from before...
            
            % TODO: Check, is it faster to add frames in blocks, or is it
            % the same to add frames individually.
            
            % Save images to temporary buffer.
            if ~any(ismember(obj.CachedFrameIndices, frameInd))
                numTempFrames = numel(frameInd);
                
                % Update the cache indices. The updated cache indices are
                % the indices of positions in the cache where new data is
                % inserted. Using mod makes this work in a rolling manner.
                obj.CacheIndices = obj.CacheIndices(end) + (1:numTempFrames);
                obj.CacheIndices = mod(obj.CacheIndices-1, obj.NumFrames)+1;
                
                subs = obj.getCacheSubs(obj.CacheIndices);
                obj.Data(subs{:}) = frameData;
                
                obj.CachedFrameIndices(obj.CacheIndices) = frameInd;
            end

        end
        
        function submitStaticData(obj, frameData, frameInd)
            % Todo: Expand so that data can be appended...
            obj.Data = frameData;
            obj.CachedFrameIndices = frameInd;
        end
        
        function cls = class(obj)
            cls = class(obj.Data);
        end
    end

end