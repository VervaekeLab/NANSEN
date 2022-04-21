classdef TiffMultiPart < nansen.stack.data.VirtualArray
%
%
%   Works for set (data split across multiple files) of multipage tiff files.

    % Todo: work with many parts
    % [ ] implement writable...
    % [ ] Create a property for keeping a list of multiple filepaths.
    %     FilePath property should be reserved for a single filepath.
    % [ ] Detect if other files are located in same location
    
    
properties (Constant, Hidden)
    FILE_PERMISSION = 'write'
end

properties (Access = private, Hidden)
    tiffObj Tiff
    fileSize    
end

properties (Access = private, Hidden) % File Info
    NumFrames % Channels x Timepoints x nPlanes
    FilePathList = {} % Keep list of all filepaths if multiple tiff files are open.
    
    numFiles
    numFramesPerFile
    frameIndexInfo
end


methods % Structors
    
    function obj = TiffMultiPart(filePath, varargin)
        import('nansen.stack.virtual.TiffMultiPart')
        filePath = TiffMultiPart.lookForMultipartFiles(filePath);
        
        obj@nansen.stack.data.VirtualArray(filePath, varargin{:})
    end
    
    function delete(obj)
        for i = 1:numel(obj.tiffObj)
            close(obj.tiffObj(i))
        end
    end
    
end

methods (Access = protected) % Implementation of abstract methods
        
    function obj = assignFilePath(obj, pathString, varargin)

        % Todo: resolve if there are files from multiple channels or planes
        
        if isa(pathString, 'cell')
            obj.numFiles = numel(pathString);
            obj.FilePathList = pathString;
            obj.FilePath = pathString{1};
            
        elseif isa(pathString, 'char') || isa(pathString, 'string')
            obj.numFiles = 1;
            obj.FilePathList = {pathString};
            obj.FilePath = char(pathString);
        end
        
        if obj.numFiles > 1
            for i = 1:numel(obj.FilePathList)
                obj.tiffObj(i) = Tiff(obj.FilePathList{i}, 'r+');
            end
        else
            obj.tiffObj = Tiff(obj.FilePath, 'r+');
        end
        
    end
    
    function getFileInfo(obj)
        
        if isempty(obj.tiffObj)
            error('Something unexpected has happened')
        end

        obj.assignDataSize()
        
        obj.assignDataType()
        
    end
    
    function createMemoryMap(obj)
        % Skip. Tiff objects are creating in assignFilePath method
    end
    
    function assignDataSize(obj)
                        
        % Get image dimensions and create empty array
        obj.DataSize(1) = obj.tiffObj(1).getTag('ImageLength');
        obj.DataSize(2) = obj.tiffObj(1).getTag('ImageWidth');
        numChannels = obj.tiffObj(1).getTag('SamplesPerPixel');
        
        obj.DataDimensionArrangement = 'YX';

        obj.countNumFrames();
        numPlanes = 1; % Todo: Add this from metadata.
        numTimepoints = obj.NumFrames;
        
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
        if numTimepoints >= 1
            obj.DataSize = [obj.DataSize, numTimepoints];
            obj.DataDimensionArrangement(end+1) = 'T';
        end

    end
    
    function assignDataType(obj)
        
        sampleFormat = obj.tiffObj(1).getTag('SampleFormat');
        bitsPerSample = obj.tiffObj(1).getTag('BitsPerSample');
        
        switch sampleFormat
            case 1
                obj.DataType = sprintf('uint%d', bitsPerSample);
            case 2
                obj.DataType = sprintf('int%d', bitsPerSample);
            case 3
                if bitsPerSample == 32
                    obj.DataType = 'single';
                elseif bitsPerSample == 64
                    obj.DataType = 'double';
                else
                    error('Sampleformat is not supported')
                end
                
            otherwise
                error('Tiff file is not supported')
        end

    end
    
end



methods % Implementation of abstract methods
    
    function data = readData(obj, subs)
        
        % Special case for single frame image
        if ndims(obj) == 2 %#ok<ISMAT>
            frameInd = 1;
        else
            frameInd = subs{end};
        end
        data = obj.readFrames(frameInd);
    end

    function data = readFrames(obj, frameInd)
             
        global waitbar
        useWaitbar = false;
        if ~isempty(waitbar); useWaitbar = true; end
        
        % Determine size of requested data
        stackSize = obj.DataSize;
        stackSize(end) = numel(frameInd);

        % Preallocate data
        data = zeros(stackSize, obj.DataType);
        insertSub = repmat({':'}, 1, numel(stackSize));
        
        if useWaitbar
            waitbar(0, 'Loading image frames')
            updateRate = round(stackSize(end)/50);
        end
        
        % Loop through frames and load into data.
        for i = 1:numel( frameInd )

            frameNum = frameInd(i);
            insertSub{end} = i;
            
            fileNum = obj.frameIndexInfo.fileNum(frameNum);
            frameInFile = obj.frameIndexInfo.frameInFile(frameNum);
            
            warning('off', 'imageio:tiffmexutils:libtiffWarning')
            obj.tiffObj(fileNum).setDirectory(frameInFile);
            warning('on', 'imageio:tiffmexutils:libtiffWarning')
            
            data(insertSub{:}) = obj.tiffObj(fileNum).read();
            
            if useWaitbar
                if mod(i, updateRate) == 0
                    waitbar(i/stackSize(end), 'Loading image frames')
                end
            end

        end
        
    end
    
    function writeFrames(obj, data, frameIndices)
        %error('Not implemented yet')
        obj.writeFrameSet(data, frameIndices)
    end
    
    
    
    function writeFrameSet(obj, data, frameIndices, subs)
        
        % Todo: combine with getFrameSet???
        % Todo: Test thoroughly
        
% %         if nargin < 4
% %             subs = obj.frameind2subs(frameInd);
% %             insertSub = repmat({':'}, 1, ndims(obj));
% %         end
% %         
% %         % Todo: Make assertion that data has the same size as the stack
% %         % (width and height, numchannels) 
% %         
% %         % Todo: Resolve which is the subs containing number of samples.
% %         sampleDim = strfind(obj.DimensionOrder, 'T'); % todo, store in property.
% %         frameIndices = subs{sampleDim};

        
        % Preallocate data
        insertSub = repmat({':'}, 1, numel(obj.DataSize));

        % Loop through frames and load into data.
        for i = 1:numel( frameIndices )

            frameNum = frameIndices(i);
            insertSub{end} = i;

            fileNum = obj.frameIndexInfo.fileNum(frameNum);
            frameInFile = obj.frameIndexInfo.frameInFile(frameNum);

            obj.tiffObj(fileNum).setDirectory(frameInFile);
            
            % Todo: include planes as well
            obj.tiffObj(fileNum).write(data(insertSub{:}));

        end
        
    end

    function writeMetadata(~)
        % Pass. This class will most likely be used to open generic tiffs,
        % and we don't want to drop metadata files all over the place.
    end
    
end


methods % Override superclass methods
    
    function assignDataClass(obj)
        % Todo: what if it is int? What if single or double?    
    
        sampleFormat = obj.tiffObj(1).getTag('SampleFormat');
        bitsPerSample = obj.tiffObj(1).getTag('BitsPerSample');
        
        switch sampleFormat
            case 1
                obj.DataType = sprintf('uint%d', bitsPerSample);
            case 2
                obj.DataType = sprintf('int%d', bitsPerSample);
            case 3
                if bitsPerSample == 32
                    obj.DataType = 'single';
                elseif bitsPerSample == 64
                    obj.DataType = 'double';
                else
                    error('Sampleformat is not supported')
                end
                
            otherwise
                error('Tiff file is not supported')
        end

    
    end
    
end


methods
    
    function countNumFrames(obj)
    %countNumFrames 
    %
    % Making some assumptions here to speed things up. 
    %   1) Number of frames depends on filesize (file not compressed)
    %   2) If there are many files, files with same filesize have same
    %   frame number
        
        import nansen.stack.utility.findNumTiffDirectories
    
        obj.NumFrames = 0;
        
        obj.frameIndexInfo = struct('frameNum', [], 'fileNum', [], 'frameInFile', []);
        
        for i = 1:obj.numFiles
            skipCount = false;
            
            % Get number of frames
            %initialFrame = obj.tiffObj(i).currentDirectory();

            % Todo: Add safety margin...
            n = obj.estimateNumberOfFrames(i);
            
            if i > 1
                if obj.fileSize(i) == obj.fileSize(i-1)
                    obj.numFramesPerFile(i) = obj.numFramesPerFile(i-1);
                    n = obj.numFramesPerFile(i);
                    skipCount = true;
                end
            end

            if ~skipCount
                n = findNumTiffDirectories(obj.tiffObj(i), 1, 10000);
            end
            
            currentInd = obj.NumFrames + (1:n);
            
            obj.frameIndexInfo.frameNum(currentInd) = currentInd;
            obj.frameIndexInfo.fileNum(currentInd) = i;
            obj.frameIndexInfo.frameInFile(currentInd) = 1:n;

            obj.NumFrames = obj.NumFrames + n;
            obj.numFramesPerFile(i) = n;
            %obj.tiffObj(i).setDirectory(initialFrame);
            
        end
        
    end
    
    function n = estimateNumberOfFrames(obj, fileNum)
    %estimateNumberOfFrames based on fileSize
        
        if nargin < 2; fileNum = 1; end
    
        L = dir(obj.FilePathList{fileNum});
        obj.fileSize(fileNum) = L.bytes;
        
        bytesPerSample = obj.tiffObj(fileNum).getTag('BitsPerSample') ./ 8;
        bytesPerFrame = obj.DataSize(1) .* obj.DataSize(2) .* bytesPerSample;
        
        samplesPerPixel = obj.tiffObj(fileNum).getTag('SamplesPerPixel');
        
     	n = floor( obj.fileSize(fileNum) ./ bytesPerFrame ./ samplesPerPixel );
        
        n = max([n, 1]); % Ad hoc, for single compressed tiffs, saved using imwrite.
    end
    
end


methods (Static)

    function createFile(filePath, varargin)
    %createFile Create a new tiff stack
    %
    %   virtualTiffObj.createFile(filePath, imageArray) creates a new tiff
    %   file and writes the data in imageArray to the file.
    %
    %   virtualTiffObj.createFile(filePath, stackSize, dataType) creates a
    %   new tiff file and writes frames with zeros according to specified
    %   stackSize and dataType
    
    %   Todo: Accept number of parts from inputs and write to multiple parts
    
        if numel(varargin) >= 2
            arraySize = varargin{1};
            arrayClass = varargin{2};
            imArray = zeros( arraySize, arrayClass);
        elseif numel(varargin) == 1
            imArray = varargin{1};
        elseif numel(varargin) == 0
            error('Not enough input arguments')
        end
        
        nansen.stack.utility.mat2tiffstack( imArray, filePath )
    end
    
    function filepath = lookForMultipartFiles(filepath)
        
        if ischar(filepath) || (iscell(filepath) && numel(filepath)==1)
            if iscell(filepath)
                [folder, ~, ext] = fileparts(filepath{1});
            else
                [folder, ~, ext] = fileparts(filepath);
            end
            L = dir(fullfile(folder, ['*', ext]));
            
            if numel(L) > 1 && numel( unique(cellfun(@numel, {L.name})) ) == 1
                filepath = fullfile({L.folder}, {L.name});
            end
        end
        
    end
end

end