classdef TiffMultiPart < nansen.stack.data.VirtualArray
%
%
%   Works for set (data split across multiple files) of multipage tiff files.

    % Todo: work with many parts
    % [ ] implement writable...
    % [ ] Create a property for keeping a list of multiple filepaths.
    %     FilePath property should be reserved for a single filepath.
    
    
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
        % this is done in coun frames method
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
        if numTimepoints > 1
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
        frameInd = subs{end};
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

            obj.tiffObj(fileNum).setDirectory(frameInFile);
            
            data(insertSub{:}) = obj.tiffObj(fileNum).read();
            
            if useWaitbar
                if mod(i, updateRate) == 0
                    waitbar(i/stackSize(end), 'Loading image frames')
                end
            end

        end
        
    end
    
    function writeFrames(obj, frameIndex, data)
        error('Not implemented yet')
    end
    
    
    
    function writeFrameSet(obj, data, frameInd, subs)
        
        % Todo: combine with getFrameSet???
        % Todo: Test thoroughly
        
        if nargin < 4
            subs = obj.frameind2subs(frameInd);
        end
        
        % Todo: Make assertion that data has the same size as the stack
        % (width and height, numchannels) 
        
        % Todo: Resolve which is the subs containing number of samples.
        sampleDim = strfind(obj.DimensionOrder, 'T'); % todo, store in property.
        frameIndices = subs{sampleDim};
        
        % Loop through frames and load into data.
        for i = 1:numel( frameIndices )

            frameNum = frameIndices(i);

            fileNum = obj.frameIndexInfo.fileNum(frameNum);
            frameInFile = obj.frameIndexInfo.frameInFile(frameNum);

            obj.tiffObj(fileNum).setDirectory(frameInFile);
            
            % Todo: include planes as well
            if obj.NumChannels > 1 && numel(obj.CurrentChannel) > 1
                obj.tiffObj(fileNum).write(data(:, :, :, i));
            else
                obj.tiffObj(fileNum).write(data(:,:,i));
            end

        end
        
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
                
                % Count backwards
                complete = false;
                while ~complete
                    try
                        obj.tiffObj(i).setDirectory(n);
                        complete = true;
                    catch
                        n = n-10;
                    end
                end
                
                % Count forwards
                complete = obj.tiffObj(i).lastDirectory();
                while ~complete
                    obj.tiffObj(i).nextDirectory();
                    n = n + 1;
                    complete = obj.tiffObj(i).lastDirectory();
                end
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
    
    function initializeFile(filePath, arraySize, arrayClass)
        
        imArray = zeros( arraySize, arrayClass);
        mat2stack( imArray, filePath )
        
        return
               
        % Todo: This is just a draft. Create this as a file that can be
        % written to....


        t = Tiff(filePath, 'a');
               
        % Todo:
        setTag(t, 'Photometric', Tiff.Photometric.MinIsBlack)
        
        setTag(t, 'Compression', Tiff.Compression.None)
        setTag(t, 'ImageLength', arraySize(1));
        setTag(t, 'ImageWidth', arraySize(2));
        
        switch arrayClass
            case 'uint8'
                setTag(t,'SampleFormat',Tiff.SampleFormat.UInt)
                setTag(t, 'BitsPerSample', 8);
%             case 'int8'
%                 setTag(t,'SampleFormat',Tiff.SampleFormat.Int)
%                 setTag(t, 'BitsPerSample', 8);
            case 'uint16'
                setTag(t,'SampleFormat',Tiff.SampleFormat.UInt)
                setTag(t, 'BitsPerSample', 16);
%             case 'int16'
%                 setTag(t,'SampleFormat',Tiff.SampleFormat.Int)
%                 setTag(t, 'BitsPerSample', 16);
            otherwise
                error('Not implemented yet')
        end
        
        setTag(t, 'SamplesPerPixel', 1);
        
    end
    
end

end