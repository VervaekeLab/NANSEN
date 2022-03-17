classdef VirtualArray < nansen.stack.data.abstract.ImageStackData
%VirtualArray ImageStackData superclass for mapping data to virtual array

% Note: 
%   Since data is stored in one way, and the virtual array allows data to
%   be represented in a different way, this class is a bit complex. Some
%   issues that might be developed in a clearer way is the caching of data,
%   and how it is returned...
%   
%   When subsrefing a virtual array (through the superclass, 
%   nansen.stack.data.abstract.ImageStackData) the data is added to the
%   cache in the getData/getDataUsingCache methods of this class, so before
%   data is permuted and output to the user. 
%
%   Therefore, in the methods, getCachedFrames and getStaticCache data is
%   also permuted before outputting. This is important to be aware if using
%   these methods or creating new methods for outputting data.


% Todo: 
%   [ ] Get data should call method readFrames instead of method
%       readData??? Or need to add both readData and readFrames as abstract
%       methods.


    properties
        FilePath
        Writable = false    % Todo: implement this
    end
    
    properties 
        MetaData % hm....
        UserData % Move to imagestack...
    end
    
    properties % Caching preference properties
        UseDynamicCache = false
        DynamicCacheSize = 1000    % Size of cache in number of frames
    end
    
    properties (Access = protected) % Cache properties
        DynamicFrameCache nansen.stack.utility.FrameCache   % Dynamic frame cache (loaded image data is added here when cache is enabled)
        StaticFrameCache nansen.stack.utility.FrameCache    % Static frame cache (does not dynamically update)
    end
    
    properties (Dependent)
        HasStaticCache
        HasCachedData
    end
    
    properties (Access = private)
        FileAccessMode = 'open' % Token indicating the mode of accessing the file. 'open' or 'create'. Todo: add more alternatives?
    end
    
    properties (Hidden)
        % set access = private. Use true if file path is not provided....
        IsTransient = false     % If stack is transient, the file with data is deleted when object is deleted.
    end
    
    events
        DynamicCacheChanged
        StaticCacheChanged
    end
    
    
    methods (Abstract, Access = protected)
        
        getFileInfo(obj)                        % Method for getting info about image stack data in file. At minimum, need to set DataSize and DataType
        createMemoryMap(obj)                    % Method for creating a memory-map based (virtual) representation of the data

    end
    
    methods (Abstract)
        % todo: readData and writeData
        
        data = readFrames(obj, frameIndex)      % Frame index is a vector or a cell array of vectors.
        writeFrames(obj, frameIndex, data)      % Frame index is a vector or a cell array of vectors.

    end
    
    methods % Structors
        
        function obj = VirtualArray(filePath, varargin)
        
            %obj@nansen.stack.data.abstract.ImageStackData()
            
            [nvPairs, varargin] = utility.getnvpairs(varargin{:});

            if ~isa(filePath, 'cell'); filePath = {filePath}; end
            
            % Create new file (if file does not exist and stack size and
            % type is given) Todo: Check that varargin contains one size
            % argument and one datatype argument.
            if ~isfile(filePath{1}) && ~isempty(varargin)
                obj.createFile(filePath{1}, varargin{:})
                obj.FileAccessMode = 'create';
                % TODO: ASSIGN size properties, but leave actual file
                % empty, so that it can be written to later by appending
                % data.                
            end
            
            % Parse potential name-value pairs and assign to properties
            obj.parseInputs(nvPairs{:})
            
            % Make sure transient is turned off if existing stack was
            % opened
            if obj.IsTransient && strcmp(obj.FileAccessMode, 'open')
                obj.IsTransient = false;
            end
            
            obj.assignFilePath(filePath);
            obj.getFileInfo()
            
            % Todo: open input dialog?
            assert(~isempty(obj.DataSize), 'DataSize should be given as input or set in the getFileInfo method')
            assert(~isempty(obj.DataType), 'DataType should be given as input or set in the getFileInfo method')
        
            obj.setDefaultDataDimensionArrangement()
            obj.setDefaultStackDimensionArrangement()
            
            obj.createMemoryMap()
            
            if obj.UseDynamicCache
                obj.initializeDynamicFrameCache()
            end
            
        end
        
        function delete(obj)
            if obj.IsTransient
                delete( obj.FilePath )
            end
        end
    end
    
    methods % Set methods for properties
               
        function set.UseDynamicCache(obj, newValue)
            assert(islogical(newValue), 'Value of UseCache must be a logical' )
            obj.UseDynamicCache = newValue;
            obj.onUseCacheChanged()
        end
        
        function set.DynamicCacheSize(obj, newValue)
            obj.DynamicCacheSize = newValue;
            obj.onCacheSizeChanged()
        end
    end
    
    methods % Get methods for properties
        
        function tf = get.HasCachedData(obj)
            tf = obj.UseDynamicCache || ~isempty(obj.StaticFrameCache);
        end
        
        function tf = get.HasStaticCache(obj)
            tf = ~isempty(obj.StaticFrameCache);
        end 
        
    end
    
    methods % Methods for reading/writing data; subclasses can override
        
        function data = readData(obj, subs)
            % Reads data using the readFrames methods of subclasses.

            % This function assumes that data is organized as YXCT or YXCZ
            if numel(subs) < numel(obj.DataSize)
                assert(obj.DataSize(end)==1, 'Something unexpected')
                subs{end+1} = 1;
            end

            frameInd = subs{end};

            data = obj.readFrames(frameInd);
            data = data(subs{1:end-1}, ':');
        end
        
        function writeData(obj, subs, data)
            
            frameInd = subs{end};
            obj.writeFrames(data, frameInd);

            %error('Not implemented yet')
        end
    end
    
    methods (Access = protected) % Override methods of superclass
        function onDataSizeChanged(obj)
            onDataSizeChanged@nansen.stack.data.abstract.ImageStackData(obj)
            
            if obj.UseDynamicCache
                % Todo: Reset dynamic cache
                obj.initializeDynamicFrameCache()
            end
            
            if obj.HasStaticCache
                error('This is not implemented yet. Please report')
                % Todo: Reset static cache
            end
        end
    end
    
    methods (Access = protected) % Subclasses can override
        
        function obj = assignFilePath(obj, filePath, ~)
            obj.FilePath = filePath;
        end
        
        function data = getData(obj, subs)
             
            % Todo, use readFrames, not readData. And resolve which
            % frameindices to retrieve....
            
            % Are any of these frames found in the cache?
            if obj.HasCachedData
                data = obj.getDataUsingCache(subs);
            else
                data = obj.readData(subs);
                %data = obj.readFrames(subs);
            end
            
            if ~all( size(data, [1,2]) == cellfun(@numel, subs(1:2) ) )
                subs(3:end) = {':'}; % Only subindex along x-y dimension here.
                data = data(subs{1:ndims(data)});
            end
                
        end
        
        function setData(obj, subs, data)
            
            % Are any of these frames found in the cache?
            if obj.HasCachedData
                % Add to cache?
            else
                obj.writeData(subs, data);
            end
            
        end
        
        function data = getLinearizedData(obj)
            error('Linear indexing is not implemented for virtual data yet')
        end
        
    end
    
    methods (Access = private, Sealed)
        
        function initializeDynamicFrameCache(obj)
        %initializeDynamicFrameCache Initializes a dynamic frame cache
                    
            dataSize = obj.DataSize; %obj.StackSize;
            dataType = obj.DataType;
            
            % Return if this is empty. Object is not properly constructed yet.
            if isempty(dataType); return; end 
                              
            cacheLength = obj.DynamicCacheSize;
  
            obj.DynamicFrameCache = nansen.stack.utility.FrameCache(...
                                        dataSize, dataType, cacheLength);

        end
        
        function disableDynamicFrameCache(obj)
        %disableDynamicFrameCache Disables the dynamic frame cache
        %
        %   TODO: Should make it disabled instead of deleting it...
            if ~isempty(obj.DynamicFrameCache) && isa(obj.DynamicFrameCache, 'handle')
                delete(obj.DynamicFrameCache)
            end
            
            obj.DynamicFrameCache = nansen.stack.utility.FrameCache.empty;
            
        end
        
        function data = getDataUsingCache(obj, subs)

            sampleDim = numel(subs);
            frameIndices = subs{sampleDim};            

            % Get data from static or dynamic cache
            if ~isempty(obj.StaticFrameCache) && obj.UseDynamicCache
                [cachedDataS, hitIndS, missInd] = obj.StaticFrameCache.fetchData(frameIndices);
                [cachedDataD, hitIndD, missInd] = obj.DynamicFrameCache.fetchData(missInd);
                
                % Combine static & dynamic cache:
                cachedData = cat(sampleDim, cachedDataS, cachedDataD);
                hitInd = [hitIndS, hitIndD];
            
            elseif ~isempty(obj.StaticFrameCache) && ~obj.UseDynamicCache
                [cachedData, hitInd, missInd] = obj.StaticFrameCache.fetchData(frameIndices);
            
            elseif obj.UseDynamicCache
                [cachedData, hitInd, missInd] = obj.DynamicFrameCache.fetchData(frameIndices);
            
            else
                [cachedData, hitInd] = deal([]);
                missInd = frameIndices;
                warning('This condition should not occur...')
            end      
            
            % Todo: What if data is in different order....
            if isequal(hitInd, frameIndices)
                data = cachedData;
                return
            end
            
            % Get all data for missing frames. Crop after submitting to
            % cache (if necessary)
            if ~isempty(missInd)
                tmpSubs = [repmat({':'}, 1, sampleDim-1), missInd];
                uncachedData = obj.readData(tmpSubs);
            else
                uncachedData = [];
            end
            
            % Submit uncached data.
            if obj.UseDynamicCache
                if ~isempty(missInd)
                    obj.DynamicFrameCache.submitData(uncachedData, missInd);
                    obj.notify('DynamicCacheChanged', event.EventData)
                end
            end
            
            if isequal(missInd, frameIndices)
                data = uncachedData;
                return
            end
                        
            % If we got this far, we need to concatenate cached and unchached data
            data = cat(sampleDim, cachedData, uncachedData);

            % Reorder data to have same order as frameIndices
            dataFrameIndices = [hitInd, missInd];
            
            if isequal(dataFrameIndices, frameIndices)
                return
            else
                [~, ~, iB] = intersect(frameIndices, dataFrameIndices);
                tmpSubs = [ repmat({':'}, 1, sampleDim-1), {iB} ];
                data = data(tmpSubs{:}) ;
            end
            
            data = data(subs{1:end-1}, ':');

            
        end
        
        function cacheSubs = getCacheSubs(obj, subs)

            cacheSubs = subs{3:end};

            for i = 1:numel(cacheSubs)
                
            end
            
        end
    end
    
    methods (Sealed)
        
        % % % Methods for getting all cached data

        function data = getCachedFrames(obj)
        %getCachedFrames Get all data from static and/or dynamic FrameCache

            data = [];
            
            if obj.HasStaticCache
                data = obj.StaticFrameCache.fetchData();
            end
            
            if obj.UseDynamicCache
                data = obj.DynamicFrameCache.fetchData();
            end
            
            % Note, data in cache has same dimensional order as original,
            % so need to permute data before returning.
            data = permute(data, obj.StackDimensionOrder);
            
        end
        
        function data = getStaticCache(obj)
        %getStaticCache Get data which is stored in static FrameCache
            data = obj.StaticFrameCache.fetchData();
             
            % Note, data in cache has same dimensional order as original,
            % so need to permute data before returning.
            data = permute(data, obj.StackDimensionOrder);
        end
        
        % % % Methods for adding data to cache

        function addToStaticCache(obj, imData, frameIndices)
        %addToStaticCache Add image data to FrameCache for given frameIdx
        %
        %  dataObj.addToStaticCache(imData, frameIndices)
        
            import nansen.stack.utility.FrameCache
        
            % Create a static frame cache if it does not exist.
            if isempty(obj.StaticFrameCache)
                dataSize = size(obj); % obj.StackSize;
                dataType = obj.DataType;
                obj.StaticFrameCache = FrameCache(dataSize, dataType, [], 'static');
            end
            
            obj.StaticFrameCache.submitStaticData(imData, frameIndices)
            obj.notify('StaticCacheChanged')
        end
        
        function onCacheSizeChanged(obj)
        %onCacheSizeChanged Callback if cache size changes.    
            if obj.UseDynamicCache && ~isempty(obj.DynamicFrameCache)
                obj.DynamicFrameCache.CacheLength = obj.DynamicCacheSize;
            end
        end
        
        function onUseCacheChanged(obj)
        %onUseCacheChanged Callback if flag to use cache or not changes.
            if obj.UseDynamicCache
                if isempty(obj.DynamicFrameCache)
                    obj.initializeDynamicFrameCache()
                end
            else
                obj.disableDynamicFrameCache()
            end
            
        end
    
    end
    
    methods (Static)
        function createFile(filePath, dataSize, dataType)
            % Subclass can override
            error('No method is defined for creating new files for %s', 'N/A')
            %Todo: get name of caller...
        end
         
    end
    
end