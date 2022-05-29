classdef TiffMultiPart < nansen.stack.data.VirtualArray
%TiffMultiPart Create virtual data for tiff stacks from multiple files
%
%   Works for set (data split across multiple files) of multipage tiff files.


    % Todo:
    % [v] Implement writable.
    % [ ] Set channel mode and write according to selection. I.e we can
    %     write multichannel data to interleaved tiffstacks with 1 sample
    %     per pixel or we can configure to tiff file with multiple samples 
    %     per pixels and write multichannel data to each tiff frame
    % [ ] Test that multi plane/ multi channel works with any kind of
    %     dimension arrangement
    %
    
    
properties (Constant, Hidden)
    FILE_PERMISSION = 'write'
end

properties (Hidden)
    SaveMetadata = false;   % Boolean flag specifying if Metadata should be saved. Default = false
end

properties (Access = protected, Hidden)
    tiffObj Tiff
    fileSize    
end

properties (Access = protected)
    FrameDeinterleaver
    InterleavedDimensions
end

properties (Access = protected, Hidden) % File Info
    NumFrames % Channels x Timepoints x nPlanes
    FilePathList = {} % Keep list of all filepaths if multiple tiff files are open.
    
    numFiles
    numFramesPerFile
    frameIndexInfo
end

properties (Access = protected)
    ChannelMode = '' % multisample, interleaved, multipart
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
    %assignFilePath Assign the provided pathString to FilePath property
    %
    %   This methods counts the number of provided filepaths and creates a
    %   Tiff object for each file.
            
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
        
        % Make sure lists are column vectors
        if isrow(obj.FilePathList)
            obj.FilePathList = obj.FilePathList';
        end
        
        if isrow(obj.tiffObj)
            obj.tiffObj = obj.tiffObj';
        end
        
    end
    
    function getFileInfo(obj)
    %getFileInfo Get file info
    
        if isempty(obj.tiffObj)
            error('Something unexpected has happened')
        end

        obj.assignDataSize()
        
        obj.assignDataType()
        
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
    
    function assignDataSize(obj)
        
        % Set DataSize from MetaData if available.
        if ~isempty(obj.MetaData.Size)
            obj.DataSize = obj.MetaData.Size;
        end
        
        % Todo: Get DataDimensionArrangement?
        
        if ~isempty(obj.DataSize)
            obj.countNumFrames()            
            return
        end
        
        % Autodetect DataSize from the tiff objects and the tiff files:
        
        % Get image dimensions and create empty array
        stackSize(1) = obj.tiffObj(1).getTag('ImageLength');
        stackSize(2) = obj.tiffObj(1).getTag('ImageWidth');
        
        % Need to assign this before counting number of frames
        obj.DataSize = stackSize;
        
        stackSize(3) = obj.detectNumberOfChannels();
        stackSize(4) = obj.detectNumberOfPlanes();

        numFrames = obj.countNumFrames();
        if strcmp(obj.ChannelMode, 'multisample')
            stackSize(5) = numFrames / stackSize(4);
        else
            stackSize(5) = numFrames / stackSize(4) / stackSize(3);
        end
        
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

methods (Access = protected)
    
    function numChannels = detectNumberOfChannels(obj)
        
        nSamplesPerPixel = obj.tiffObj(1).getTag('SamplesPerPixel');
        
        if nSamplesPerPixel > 1
            numChannels = nSamplesPerPixel;
            obj.ChannelMode = 'multisample';
        else
            numChannels = 1;
        end
        
    end
    
    function numFrames = countNumFrames(obj)
    %countNumFrames 
    %
    % Making some assumptions here to speed things up. 
    %   1) Number of frames depends on filesize (file not compressed)
    %   2) If there are many files, files with same filesize have same
    %   frame number
        
        import nansen.stack.utility.findNumTiffDirectories
        obj.numFramesPerFile = [];
        
        for i = 1:size(obj.FilePathList, 1)
            skipCount = false;
           
            % Estimate number of frames based on file size.
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

            obj.numFramesPerFile(i) = n;
        end
        
        % Todo: Add support for z dimension
        if size(obj.FilePathList, 2) > 1
            numRepeat = size(obj.FilePathList, 2);
            obj.numFramesPerFile = repmat(obj.numFramesPerFile, 1, numRepeat);
        end
        
        obj.NumFrames = sum(obj.numFramesPerFile);
        if nargout; numFrames = obj.NumFrames; end
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
    
    function createFrameIndexMap(obj)
    %createFrameIndexMap Create a mapping from frame number to file part    
        
        obj.frameIndexInfo = struct('frameNum', [], 'fileNum', [], 'frameInFile', []);

        count = 0;
        
        for i = 1:numel(obj.FilePathList)
            
            n = obj.numFramesPerFile(i);
            currentInd = count + (1:n);
            
            obj.frameIndexInfo.frameNum(currentInd) = currentInd; % Not really needed.
            obj.frameIndexInfo.fileNum(currentInd) = i;
            obj.frameIndexInfo.frameInFile(currentInd) = 1:n;
            
            count = count + n;
        end
    end
    
end


methods % Implementation of abstract methods for readin/writing
    
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
    
    function writeData(obj, subs, data)
        
        obj.validateFrameSize(data)
        
        % Special case for single frame image
        if ndims(obj) == 2 %#ok<ISMAT>
            frameInd = 1;
        else
            dims = obj.InterleavedDimensions;
            frameInd = obj.FrameDeinterleaver.Map(subs{dims});
        end
        
        obj.writeFrames(data, frameInd)
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
            frameInFile = obj.frameIndexInfo.frameInFile(frameNum);
            
            warning('off', 'imageio:tiffmexutils:libtiffWarning')
            obj.tiffObj(fileNum).setDirectory(frameInFile);
            warning('on', 'imageio:tiffmexutils:libtiffWarning')
            
            data(insertSub{:}) = obj.tiffObj(fileNum).read();
            
            if useWaitbar
                if mod(i, updateRate) == 0
                    waitbar(i/dataSize(end), 'Loading image frames')
                end
            end

        end
        
    end
    
    function writeFrames(obj, data, frameIndices)
        %error('Not implemented yet')
        obj.writeFrameSet(data, frameIndices)
    end
    
    function writeFrameSet(obj, data, frameIndices, subs)
        
        % Todo: Test thoroughly

% %         % Todo: Make assertion that data has the same size as the stack
% %         % (width and height, numchannels) 
% %         
% %         % Todo: Resolve which is the subs containing number of samples.
% %         sampleDim = strfind(obj.DimensionOrder, 'T'); % todo, store in property.
% %         frameIndices = subs{sampleDim};
        
        % dataSub should be 3D if writing channel data interleaved or
        % 4D if writing channel data to multiple samples per pixel...

        % Determine size of requested data
        if strcmp(obj.ChannelMode, 'multisample')
            dataSize = [obj.DataSize(1:3), numel(frameIndices)];
        else
            dataSize = [obj.DataSize(1:2), numel(frameIndices)];
        end
        
        % Create cell array of subs for getting frame data from data array
        dataSub = repmat({':'}, 1, numel(dataSize));

        % Loop through frames and load into data.
        for i = 1:numel( frameIndices )

            frameNum = frameIndices(i);
            dataSub{end} = i;

            fileNum = obj.frameIndexInfo.fileNum(frameNum);
            frameInFile = obj.frameIndexInfo.frameInFile(frameNum);

            obj.tiffObj(fileNum).setDirectory(frameInFile);
            
            % Todo: include planes as well
            obj.tiffObj(fileNum).write(data(dataSub{:}));

        end
        
    end

    function writeMetadata(obj)
        % Pass. This class will most likely be used to open generic tiffs,
        % and we don't want to drop metadata files all over the place.
        
        if obj.SaveMetadata
            writeMetadata@nansen.stack.data.VirtualArray(obj)
        end
        
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
        
        [imHeight, imWidth, n] = size(imArray); % Save as interleaved
        imArray = reshape(imArray, imHeight, imWidth, n);
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
            
            keep = ~ strncmp({L.name}, '.', 1);
            L = L(keep);
            
            % If many files are found and all filenames are same length
            if numel(L) > 1 && numel( unique(cellfun(@numel, {L.name})) ) == 1
                filepathCandidates = fullfile({L.folder}, {L.name});
                
                % Remove all numbers from filenames. If all names are 
                % identical after, we assume folder contains multipart files.
                
                filepathCandidates_ = regexprep(filepathCandidates, '\d*', '');
                if numel( unique(filepathCandidates_) ) == 1
                    filepath = filepathCandidates;
                else
                    % Return original filepath.
                end
            end
        end
    end
end

end