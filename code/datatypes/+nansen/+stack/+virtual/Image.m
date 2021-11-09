classdef Image < nansen.stack.data.VirtualArray
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
    VALID_FILE_FORMATS = {'JPG', 'JPEG', 'PNG', 'BMP', 'TIF', 'TIFF'}
end

properties (Access = private, Hidden) % File Info
    FilePathList = {} % Keep list of all filepaths if multiple files are open.
    numFiles
    
    ImageInfo       % Should be for ll images, but right now it stores info for first image... 
end


methods % Structors
    
    function obj = Image(filePath, varargin)
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
        
    end
    
    function getFileInfo(obj)
        
        obj.ImageInfo = imfinfo(obj.FilePathList{1});

        obj.MetaData = struct;
        obj.MetaData.numFrames = obj.numFiles;
        

        obj.assignDataSize()
        
        obj.assignDataType()
        
    end
    
    function createMemoryMap(obj)
        
        mapFormat = {obj.DataType, obj.DataSize, 'ImageArray'};
        
        % Memory map the file (newly created or already existing)
        obj.MemMap = memmapfile( obj.FilePath, 'Writable', true, ...
            'Format', mapFormat );

    end
    
    function assignDataSize(obj)
        
        % Get image dimensions and create empty array
        
        % Assume all files are the same size.
        obj.ImageInfo = imfinfo(obj.FilePathList{1});
        
        obj.DataSize = [obj.ImageInfo.Height,  obj.ImageInfo.Width];
        obj.DataDimensionArrangement = 'YX';
        
        
        switch obj.ImageInfo.ColorType
            case 'truecolor'
                numChannels = 3;
            case 'grayscale'
                numChannels = 1;
            case 'indexed'
                numChannels = 1; %??
            otherwise
                error('Image type is not supported')
        end
          
        numPlanes = 1; % Todo: Add this from metadata.
        numTimepoints = obj.numFiles;
        
        % Add length of channels if there is more than one channel
        if numChannels > 1
            obj.DataSize = [obj.DataSize, numChannels];
            obj.DataDimensionArrangement(end+1) = 'C';
        end
        
        % Add length of planes if there is more than one plane
        if numPlanes > 1
            obj.DataSize = [obj.DataSize, numPlanes];
            obj.DataDimensionArrangement(end+1) = 'Z';
        end
        
        % Add length of sampling dimension.
        if numTimepoints > 1
            obj.DataSize = [obj.DataSize, numTimepoints];
            obj.DataDimensionArrangement(end+1) = 'T';
        end

    end
    
    function assignDataType(obj)
        % Todo: what if it is int? What if single or double?
        
        bitsPerSample = obj.ImageInfo.BitDepth ./ obj.NumChannels;
        obj.DataType = sprintf('uint%d', bitsPerSample);
    end
    
end

methods % Implementation of abstract methods for reading/writing data

    function data = readData(obj, subs)
        frameInd = subs{end};
        data = obj.getFrameSet(frameInd);
        data = data(subs{1:end-1}, ':');
    end
    
    function getFrame(obj, frameInd, subs)
        obj.getFrameSet(frameInd, subs)
    end
    
    function data = getFrameSet(obj, frameInd, subs)
        % Todo: This is the same for all. Should generalize
        % Todo: simplify. Do not need subs, only need stacksize...
        % Todo: Add error handling if requested image is not right
        % dimension
        if nargin < 3
            subs = repmat({':'}, 1, ndims(obj));
            subs{end} = frameInd;
            % subs = obj.frameind2subs(frameInd);
        end

        % Resolve which is the subs containing number of samples. Hmm,
        % should always be the last one....? Todo: Is this necessary?
        sampleDim = strfind(obj.DataDimensionArrangement, 'T');
        frameInd = subs{sampleDim};

        % Determine size of requested data
        newDataSize = obj.DataSize;
        newDataSize(end) = numel(frameInd);

        % Preallocate data
        data = zeros(newDataSize, obj.DataType);

        % Loop through frames and load into data.
        for i = 1:numel( frameInd )

            frameNum = frameInd(i);

            if obj.NumChannels > 1
                data(:,:,:,i) = imread(obj.FilePathList{frameNum});
            else
                data(:,:,i) = imread(obj.FilePathList{frameNum});
            end

        end

    end
    
    function writeFrameSet(obj, data, frameInd, subs)
        
        % Todo: combine with getFrameSet???
        % Todo: Test thoroughly
        
        if nargin < 4
            subs = repmat({':'}, 1, ndims(obj));
            subs{end} = frameInd;
        end
        
        % Todo: Make assertion that data has the same size as the stack
        % (width and height, numchannels) 
        
        % Resolve which is the subs containing number of samples. % Todo:
        % Test in all possible cases.
        sampleDim = strfind(obj.DimensionOrder, 'T');
        frameIndices = subs{sampleDim};
                
        % Loop through frames and load into data.
        for i = 1:numel( frameIndices )

            frameNum = frameIndices(i);
            iFilePath = obj.FilePathList{frameNum};
            
            % Todo: include planes as well
            if obj.NumChannels > 1
                imwrite(iFilePath, data(:, :, :, i));
            else
                imwrite(iFilePath, data(:, :, i));
            end

        end
        
    end

end


methods % Override superclass methods
    
    function assignDataClass(obj)
        % Todo: what if it is int? What if single or double?
        
        bitsPerSample = obj.ImageInfo.BitDepth ./ obj.NumChannels;
        obj.DataType = sprintf('uint%d', bitsPerSample);
    end
    
end


methods (Static)
    
    function initializeFile(filePath, arraySize, arrayClass)
        error('Not implemented yet')
    end
    
end

end