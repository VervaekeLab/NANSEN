classdef PrairieViewTiffs < nansen.stack.data.VirtualArray
%nansen.stack.virtual.Image Creates a virtual stack for a set of images
%
%   Works for set of image files (jpg, png, bmp) where all files have the
%   same resolution and data type.

    % Todo:
    % [ ] Implement folder initialization.  
    % [ ] implement methods for writing data
    % [ ] getFrameSet: This is the same for all. Should generalize
    % [ ] getFrameSet: Simplify. Do not need subs, only need stacksize...
    % [ ] getFrameSet: Add error handling if requested image is not right
    %       dimension
    % [ ] writeFrameSet: combine with getFrameSet???
    % [ ] writeFrameSet: Test thoroughly
    % [ ] Alternatively: make readFrame and writeFrame method... since this
    %       class will always (?) reference individual files...
    % [ ] assignFilePath: resolve if there are files from multiple channels or planes
    % [ ] assignFilePath: validate file formats...
    % [ ] assignDataClass: What if it is int? What if single or double?

properties (Constant, Hidden)
    VALID_FILE_FORMATS = {'TIF', 'TIFF'}
    FILE_PERMISSION = 'read'
end

properties
    NumCycles
    NumChannels_
    NumPlanes_
end

properties (Access = protected)
    FrameDeinterleaver
    InterleavedDimensions
end

properties (Access = protected)
    ChannelMode = ''
end

properties (Access = private, Hidden) % File Info
    NumFrames % Channels x Timepoints x nPlanes

    FilePathList = {} % Keep list of all filepaths if multiple files are open.
    numFiles
    
    numFramesPerFile = 1
    frameIndexInfo

    ImageInfo       % Should be for all images, but right now it stores info for first image... 
end


methods % Structors
    
    function obj = PrairieViewTiffs(filePath, varargin)
        import('nansen.stack.virtual.TiffMultiPart')
        filePath = TiffMultiPart.lookForMultipartFiles(filePath);
        
        obj@nansen.stack.data.VirtualArray(filePath, varargin{:})
    end
    
    function delete(obj)
        
    end
    
end

methods (Access = protected) % Implementation of abstract methods
        
    function obj = assignFilePath(obj, filePath, ~)

        % Todo: resolve if there are files from multiple channels or planes
        % Todo: validate file formats...
        
        if isa(filePath, 'cell')
            obj.numFiles = numel(filePath);
            obj.FilePathList = filePath;
            obj.FilePath = filePath{1};
            
        elseif isa(filePath, 'char') || isa(filePath, 'string')
            obj.numFiles = 1;
            obj.FilePathList = {filePath};
            obj.FilePath = char(filePath);
        end
        
        % Make sure lists are column vectors
        if isrow(obj.FilePathList)
            obj.FilePathList = obj.FilePathList';
        end
        
        
    end
    
    function getFileInfo(obj)
        
        warning('off', 'imageio:tifftagsread:badTagValueDivisionByZero')
        obj.ImageInfo = imfinfo(obj.FilePathList{1});
        warning('on', 'imageio:tifftagsread:badTagValueDivisionByZero')
        
        S = obj.getPrairieViewRecordingInfo();
        
        % Specify data dimension sizes
        obj.MetaData.SizeX = S.xpixels;
        obj.MetaData.SizeY = S.ypixels;
        obj.MetaData.SizeZ = S.nPlanes;
        obj.MetaData.SizeC = S.nCh;
        obj.MetaData.SizeT = sum(S.nFrames)/S.nPlanes;
        
        % Specify physical sizes
        obj.MetaData.SampleRate = 1/S.dt;
        obj.MetaData.PhysicalSizeY = S.umPerPx_y;
        obj.MetaData.PhysicalSizeYUnit = 'micrometer';
        obj.MetaData.PhysicalSizeX = S.umPerPx_x;
        obj.MetaData.PhysicalSizeXUnit = 'micrometer';
        
        obj.assignDataSize()
        
        obj.assignDataType()
        
        % Todo: Update metadata properties
    end
    
    function createMemoryMap(obj)
        % Tiff objects for each file was already assigned in
        % assignFilePath, here we just assign the mapping from frame number
        % to file part
        
        obj.createFrameIndexMap()
        
        if strcmp(obj.ChannelMode, 'multisample')
            % Todo: Test that this works
            dims = 4:numel(obj.DataSize);
        else
            dims = 3:numel(obj.DataSize);
        end
        
        if isempty(dims)
            return
        end
        
        obj.InterleavedDimensions = dims;
        obj.FrameDeinterleaver = nansen.stack.Deinterleaver(...
            obj.DataDimensionArrangement(dims), obj.DataSize(dims));
        
    end
    
    function createFrameIndexMap(obj)
    %createFrameIndexMap Create a mapping from frame number to file part    
        
        obj.frameIndexInfo = struct('frameNum', [], 'fileNum', [], 'frameInFile', []);

        count = 0;
        
        for i = 1:numel(obj.FilePathList)
            
            n = obj.numFramesPerFile;
            currentInd = count + (1:n);
            
            obj.frameIndexInfo.frameNum(currentInd) = currentInd; % Not really needed.
            obj.frameIndexInfo.fileNum(currentInd) = i;
            obj.frameIndexInfo.frameInFile(currentInd) = 1:n;
            
            count = count + n;
        end
    end
    
    function assignDataSize(obj)
        
        % Get image dimensions and create empty array
        
        stackSize = [obj.ImageInfo.Height,  obj.ImageInfo.Width];
        obj.DataDimensionArrangement = 'YX';
        
        stackSize(3) = obj.detectNumberOfChannels();
        stackSize(4) = obj.detectNumberOfPlanes();
        
        numFrames = numel(obj.FilePathList);
        stackSize(5) = numFrames / stackSize(3) / stackSize(4);

        
        % Following is identical to TiffMultiPart (todo: make this into separate method, i.e autoresolveDataDimensionArrangement)
        
        % Find singleton dimensions.
        isSingleton = stackSize == 1;
        
        % Get arrangement of dimensions of data
        try
            dataDimensionArrangement = obj.DATA_DIMENSION_ARRANGEMENT;
        catch
            dataDimensionArrangement = obj.DEFAULT_DIMENSION_ARRANGEMENT;
        end
        
        % Get order of dimensions of data
        [~, ~, dimensionOrder] = intersect( obj.DEFAULT_DIMENSION_ARRANGEMENT, ...
            dataDimensionArrangement, 'stable' );
        
        % Rearrange beased on dimension order
        isSingleton_(dimensionOrder) = isSingleton;
        dataSize(dimensionOrder) = stackSize;
        
        % Assign size and dimension arrangement for data excluding
        % singleton dimension.
        obj.DataSize = dataSize(~isSingleton_);
        obj.DataDimensionArrangement = dataDimensionArrangement(~isSingleton_);

    end
    
    function assignDataType(obj)
        % Todo: what if it is int? What if single or double?
        
        ind = strfind(obj.DataDimensionArrangement, 'C');
        if isempty(ind)
            numChannels = 1;
        else
            numChannels = obj.DataSize(ind);
        end
        
        % todo:
        bitsPerSample = obj.ImageInfo.BitDepth;
        obj.DataType = sprintf('uint%d', bitsPerSample);
    end
    
end

methods % Implementation of abstract methods for reading/writing data
    
    
    function getFrame(obj, frameInd, subs)
        obj.getFrameSet(frameInd, subs)
    end
    
    function data = readData(obj, subs)
    %readData Reads data from multipart tiff file
    %
    %   See also nansen.stack.data.VirtualArray/readData
    
        % Special case for single frame image
        if ndims(obj) == 2 %#ok<ISMAT>
            frameInd = 1;
        else
            dims = obj.InterleavedDimensions;
            frameInd = obj.FrameDeinterleaver.Map(subs{dims});
        end
       
        data = obj.readFrames(frameInd);
        
        % Deinterleave frames:
        if ~isempty(obj.FrameDeinterleaver)
            data = obj.FrameDeinterleaver.deinterleaveData(data, subs);
        end
        
        % Crop frames:
        data = obj.cropData(data, subs);
    end

    function data = readFrames(obj, frameInd)
             
        global waitbar
        useWaitbar = false;
        if ~isempty(waitbar); useWaitbar = true; end

        % Determine size of requested data
        if strcmp(obj.ChannelMode, 'multisample')
            dataSize = [obj.DataSize(1:3), numel(frameInd)];
        else
            dataSize = [obj.DataSize(1:2), numel(frameInd)];
        end
        
        % Preallocate data
        data = zeros(dataSize, obj.DataType);
        insertSub = arrayfun(@(n) 1:n, dataSize, 'uni', 0);
        
        if useWaitbar
            waitbar(0, 'Loading image frames')
            updateRate = round(dataSize(end)/50);
        end
        
        % Loop through frames and load into data.
        for i = 1:numel( frameInd )

            frameNum = frameInd(i);
            insertSub{end} = i;
            
            fileNum = obj.frameIndexInfo.fileNum(frameNum);
% %             frameInFile = obj.frameIndexInfo.frameInFile(frameNum);
            
% %             warning('off', 'imageio:tiffmexutils:libtiffWarning')
% %             obj.tiffObj(fileNum).setDirectory(frameInFile);
% %             warning('on', 'imageio:tiffmexutils:libtiffWarning')
% %             
% %             data(insertSub{:}) = obj.tiffObj(fileNum).read();
            
            filepath = obj.FilePathList{fileNum};
            data(insertSub{:}) = imread(filepath);

            
            if useWaitbar
                if mod(i, updateRate) == 0
                    waitbar(i/dataSize(end), 'Loading image frames')
                end
            end

        end
        
    end
    
    
% %     function data = readFrames(obj, frameInd)
% %         
% %         % Note: Assume that frames are the last dimension of data...
% %         
% %         % Todo: This is the same for all. Should generalize
% %         
% %         % Todo: simplify. Do not need subs, only need stacksize...
% %         
% %         % Todo: Add error handling if requested image is not right
% %         % dimension
% % 
% %         
% %         % Determine size of requested data
% %         newDataSize = obj.DataSize;
% %         newDataSize(end) = numel(frameInd);
% % 
% %         nDim = numel(obj.DataSize);
% % 
% %         % Preallocate data
% %         data = zeros(newDataSize, obj.DataType);
% % 
% %         % Loop through frames and load into data.
% %         for i = 1:numel( frameInd )
% % 
% %             frameNum = frameInd(i);
% % 
% %             if nDim == 4
% %                 data(:,:,:,i) = imread(obj.FilePathList{frameNum});
% %             elseif nDim == 3
% %                 data(:,:,i) = imread(obj.FilePathList{frameNum});
% %             else
% %                 error('Virtual data from images must be 3D or 4D')
% %             end
% % 
% %         end
% % 
% %     end
% %     
    function writeFrames(obj, data, frameInd)
        
        % Todo: combine with getFrameSet???
        % Todo: Test thoroughly

        % Todo: Make assertion that data has the same size as the stack
        % (width and height, numchannels) 
        
        nDim = numel(obj.DataSize);

                
        % Loop through frames and write data.
        for i = 1:numel( frameInd )

            frameNum = frameInd(i);
            iFilePath = obj.FilePathList{frameNum};
            
            % Todo: include planes as well
            if nDim == 4
                imwrite(iFilePath, data(:, :, :, i));
            elseif nDim == 3
                imwrite(iFilePath, data(:, :, i));
            else
                error('Virtual data from images must be 3D or 4D')
            end

        end
        
    end

end

methods (Access = protected)
    
    function metadata = getPrairieViewRecordingInfo(obj)
    %getPrairieViewRecordingInfo Get recording info from prairieview xml file
        tSeriesPath = fileparts(obj.FilePath);
        metadata = ophys.twophoton.prairieview.getPrairieMetaData( tSeriesPath );
    end
    
    function numChannels = detectNumberOfChannels(obj)
       
        if numel(obj.FilePathList) > 1

            % expression for capturing channel and part numbers as tokens
            expression = 'Cycle(?<cycle>\d{5})_Ch(?<channel>\d{1})';

            tokens = regexp( obj.FilePathList, expression, 'names');
            tokens = cat(1, tokens{:});

            channelIdx = cellfun(@(c) str2double(c), {tokens.channel});
            cycleIdx = cellfun(@(c) str2double(c), {tokens.cycle});

            tokens = cellfun(@(c) str2double(c), struct2cell(tokens));
            tokens = transpose(tokens); % each row is one file


            % channel is first, part numbers are second.
            % Sort according to channels:
            % [~, ix] = sortrows(tokens, [1,2]); 

            numChannels = numel( unique(channelIdx) );
            obj.ChannelMode = 'multipart';
            
            numParts = numel( obj.FilePathList );
            numPartsPerChannel = floor(numParts / numChannels);
            
            [~, sortedChIdx] = sort(channelIdx);
            
            obj.FilePathList = reshape(obj.FilePathList(sortedChIdx), ...
                numPartsPerChannel, numChannels);
            
        end       
    end
    
    function numPlanes = detectNumberOfPlanes(obj)
        numPlanes = 1;
    end
    
end

methods (Static)
    
    function initializeFile(filePath, arraySize, arrayClass)
        error('Not implemented yet')
    end
    
end

end