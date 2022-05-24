classdef VirtualArray < nansen.stack.data.abstract.ImageStackData
%VirtualArray ImageStackData superclass for mapping data to virtual array
%
%   Abstract class for creation of virtual data adapters for files
%   containing ImageStack data.
%
%   
%   


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


    properties (Abstract, Constant, Hidden)
        FILE_PERMISSION char % File access permission ('read' or 'write')
    end

    properties
        FilePath
        Writable = false    % Todo: implement this
    end
    
    properties (SetAccess = protected)
        %MetaData nansen.metadata.ImageMetaData
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
        %VirtualArray Constructor for VirtualArray class
        
            [nvPairs, varargin] = utility.getnvpairs(varargin{:});

            if ~isa(filePath, 'cell'); filePath = {filePath}; end
            
            % Todo: obj.validateFileReference(filePath) Add this method...
            
            % Create new file (if file does not exist and stack size and
            % type is given) Todo: Check that varargin contains one size
            % argument and one datatype argument.
            if ischar(filePath{1}) && ~isfile(filePath{1}) && ~isempty(varargin)
                obj.createFile(filePath{1}, varargin{:})
                obj.setDataSizeOnCreation(varargin{1})
                
                obj.FileAccessMode = 'create';
                % TODO: ASSIGN size properties, but leave actual file
                % empty, so that it can be written to later by appending
                % data.
            end
            
            % Parse potential name-value pairs and assign to properties
            obj.parseInputs(nvPairs{:})
            
            % Make sure transient is turned off if existing stack was
            % opened (In case property was set to true using name-value pairs). 
            if obj.IsTransient && strcmp(obj.FileAccessMode, 'open')
                obj.IsTransient = false;
            end
            
            obj.assignFilePath(filePath);
            
            obj.initializeMetaData()
            obj.getFileInfo()
            
            % Todo: open input dialog?
            assert(~isempty(obj.DataSize), 'DataSize should be given as input or set in the getFileInfo method')
            assert(~isempty(obj.DataType), 'DataType should be given as input or set in the getFileInfo method')
        
            obj.setDefaultDataDimensionArrangement()
            obj.setDefaultStackDimensionArrangement()
            
            obj.createMemoryMap()
            
            obj.updateMetadata()
            
            if obj.UseDynamicCache
                obj.initializeDynamicFrameCache()
            end
            
        end
        
        function delete(obj)
        %delete Delete VirtualArray object.        
            
            obj.writeMetadata() % Save metadata

            if obj.IsTransient % Delete files
                obj.MetaData.deleteFile()
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
        %readData Reads data using the readFrames methods of subclasses.
        %
        %   INPTUS
        %       obj  : virtual array object
        %       subs : subscripts with indices of which elements to read 
        %              for each dimension of the stack. subscripts should
        %              match the data dimension arrangement of the data.
        %              Subscripts are a cell array according to the "()"
        %              subscripts type, or "indexing by position"
        %
        %   OUTPUT: 
        %       data : data which is read from file. Data should match the
        %              subscripts.
            
            % This function assumes that data is organized as YXCT or YXCZ
            if numel(subs) < numel(obj.DataSize)
                assert(obj.DataSize(end)==1, 'Something unexpected')
                subs{end+1} = 1;
            end

            % Get the subs (frame indices) for the frame indexing dimension
            dim = obj.getFrameIndexingDimension();
            frameInd = subs{dim};

            data = obj.readFrames(frameInd);
            
            % Index into the other dimensions
            subs{dim} = ':';
            data = data(subs{:});
        end
        
        function writeData(obj, subs, data)
        %writeData Write data using the writeFrames method of subclasses.
        %
        %   The default behavior of writeData for the virtual array is to
        %   assume that subclasses implement a writeFrameSet method, where
        %   data is provided as full frames (i.e. it is not possible to 
        %   write cropped data to the files).
        %
        %   Subclasses where it is possible to write cropped data should
        %   override the writeData method.
            
        %   Todo: This should also work with deinterleaved data, or if 
        %   writing a subset of channels and/or planes.
        
            % Check that data has a valid frame size (i.e not cropped)
            obj.validateFrameSize(data)
   
            dim = obj.getFrameIndexingDimension();
            frameInd = subs{dim};
            
            obj.writeFrames(data, frameInd);
        end
        
        function readMetadata(obj)
            obj.MetaData.readFromFile()
        end
        
        function writeMetadata(obj)
        %writeMetadata Write metadata for stack.
            if strcmp(obj.FILE_PERMISSION, 'write') && ~obj.IsTransient
                obj.MetaData.writeToFile()
            else
                % Skip
            end
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
        
        function validateFrameSize(obj, data)
            
            dimX = obj.getDataDimensionNumber('X');
            dimY = obj.getDataDimensionNumber('Y');
            
            assert(size(data, dimX) == obj.DataSize(dimX), ...
                'Width of image data to write must match the width of the image frames')
            assert(size(data, dimY) == obj.DataSize(dimY), ...
                'Height of image data to write must match the height of the image frames')
            
        end
        
        function obj = assignFilePath(obj, filePath, ~)
            obj.FilePath = filePath;
        end
        
        function initializeMetaData(obj, varargin)
        %initializeMetaData Initialize metadata for imagestack data    
            if strcmp(obj.FILE_PERMISSION, 'write')
                obj.MetaData = nansen.stack.metadata.StackMetadata(obj.FilePath);
            else
                obj.MetaData = nansen.stack.metadata.StackMetadata();
            end
        end
        
        function updateMetadata(obj)
        %updateMetadata General update of metadata after initialization    
            
            % Add the DataSize if MetaData.Size is empty.
            if isempty(obj.MetaData.Size)
                obj.MetaData.Size = obj.DataSize;
            end
            
            % The size of the data will be configured on the obj and the
            % length of individual dimensions are retrieved from the 
            % getDimLength method:
            obj.MetaData.SizeX = obj.getDimLength('X');
            obj.MetaData.SizeY = obj.getDimLength('Y');
            obj.MetaData.SizeC = obj.getDimLength('C');
            obj.MetaData.SizeZ = obj.getDimLength('Z');
            obj.MetaData.SizeT = obj.getDimLength('T');
            
            % Save updated metadata
            obj.writeMetadata()
        end
        
        function numChannels = detectNumberOfChannels(obj)
            numChannels = 1;
        end
        
        function numPlanes = detectNumberOfPlanes(obj)
            numPlanes = 1;
        end
        
        function data = getData(obj, subs)
        %getData Get data corresponding to provided subs.
        %        
        %   Implementation of superclass method.
        %
        %   INPTUS
        %       obj  : virtual array object
        %       subs : subscripts with indices of which elements to read 
        %              for each dimension of the stack. subscripts should
        %              match the data dimension arrangement of the data.
        %              Subscripts are a cell array according to the "()"
        %              subscripts type, or "indexing by position"
        %
        %   OUTPUT: 
        %       data : indexed data. Data should match the subscripts.
        
            % Are any of these frames found in the cache?
            if obj.HasCachedData
                data = obj.getDataUsingCache(subs);
            else
                data = obj.readData(subs);
            end
            
        end
        
        function setData(obj, subs, data)
            
            if ~strcmp(obj.FILE_PERMISSION, 'write')
                error('No write permission for %s', builtin('class', obj))
            end
            
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
        
        function data = cropData(obj, data, subs)
        %cropData Crops data along x- and/or y-dimension    

            dimX = obj.getDataDimensionNumber('X');
            dimY = obj.getDataDimensionNumber('Y');
            
            cropSubs = repmat({':'}, 1, ndims(obj));
            imageSubs = subs([dimX, dimY]);
            cropSubs([dimX, dimY]) = imageSubs;
            
            iscolon = @(sub) ischar(sub) && isequal(sub, ':');
            isColon = all( cellfun(@(c) iscolon(c), imageSubs) );
            
            dataSize = size(data);
            
            doCrop = ~all( dataSize([dimX, dimY]) == cellfun(@numel, imageSubs) );
            if ~isColon && doCrop
                data = data(cropSubs{:});
            end
            
        end
        
        function subs = frameind2subs(obj, frameInd)
        %frameind2subs Get data subs for the given frame ind
        
        % Todo: Adapt to work for subsindexing along channel/plane frame
        % dimensions.
        
            numDims = ndims(obj);
            subs = cell(1, numDims);
            subs(1:end-1) = {':'};
            subs{end} = frameInd;
        end
        
    end
    
    methods (Access = private, Sealed)
        
        function setDataSizeOnCreation(obj, dataArray)
        %setDataSizeOnCreation Set the DataSize property if array is created
        
            if isvector(dataArray)
                % Case 1: Virtual array is created based on a size input
                obj.DataSize = dataArray;
            else
                % Case 2: Virtual array is created based on a data array
                obj.DataSize = size(dataArray);
            end
        end
        
        function initializeDynamicFrameCache(obj)
        %initializeDynamicFrameCache Initializes a dynamic frame cache
                    
            dataSize = obj.DataSize; %obj.StackSize;
            dataType = obj.DataType;
            
            % Return if this is empty. Object is not properly constructed yet.
            if isempty(dataType); return; end 
                              
            cacheLength = obj.DynamicCacheSize;
  
            obj.DynamicFrameCache = nansen.stack.utility.FrameCache(...
                                        dataSize, dataType, cacheLength, ...
                                        'LeadingDimension', obj.getFrameIndexingDimension());
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
        %getDataUsingCache Get data by fetching from cache and reading rest
            
            % Note: this function assumes that x and y are always along the
            % two first dimensions.
            
            % Note2 : This function retrieves full size image frames and
            % all channels / planes from cache and readData. This is in
            % order to easily concatenate cached data with newly read data
            % without worrying whether previously cached data were not
            % complete along all dimensions...
            
            % Note3: Data is indexed before return statement, in order to 
            % match the subscripts of the input.
            
            sampleDim = obj.getFrameIndexingDimension();
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
                cacheSubs = subs;
                cacheSubs{sampleDim} = ':';
                data = cachedData(cacheSubs{:});
                return
            end
            
            % Get all data (uncropped) for missing frames. Crop after 
            % submitting to cache (if necessary)
            if ~isempty(missInd)
                tmpSubs = repmat({':'}, 1, ndims(obj));
                tmpSubs{sampleDim} = missInd;
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
                tmpSubs = subs;
                tmpSubs{sampleDim} = ':';
                data = uncachedData(tmpSubs{:});
                return
            end
                        
            % If we got this far, we need to concatenate cached and unchached data
            data = cat(sampleDim, cachedData, uncachedData);

            % Reorder data to have same order as frameIndices
            dataFrameIndices = [hitInd, missInd];
            
            % Make sure output gets cropped (if necessary) and frames are
            % in the right order.
            if isequal(dataFrameIndices, frameIndices)
                tmpSubs = subs;
                tmpSubs(sampleDim) = {':'};
            else
                [~, ~, iB] = intersect(frameIndices, dataFrameIndices);
                tmpSubs = subs;
                tmpSubs{sampleDim} = iB;
            end
            
            iscolon = @(sub) ischar(sub) && strcmp(sub, ':');
            
            % Crop and/or rearrange frames..
            if ~all(cellfun(@(sub) iscolon(sub), tmpSubs))
                data = data(tmpSubs{:}) ;
            end
            
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
            elseif obj.UseDynamicCache
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
        
            [h, w, ~] = size(imData);
            if isequal([h,w], obj.StackSize(1:2))
                permuteData = true;
            else
                permuteData = false;
            end
            
            % Create a static frame cache if it does not exist.
            if isempty(obj.StaticFrameCache)
                dataSize = size(imData);
                if permuteData
                    dataSize = dataSize(obj.StackDimensionOrder);
                end
                dataType = obj.DataType;
                obj.StaticFrameCache = FrameCache(dataSize, dataType, [], ...
                    'static', 'LeadingDimension', obj.getFrameIndexingDimension());
            end
            
            if permuteData
                imData = ipermute(imData, obj.StackDimensionOrder);
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