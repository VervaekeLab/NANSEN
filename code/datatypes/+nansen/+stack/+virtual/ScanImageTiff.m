classdef ScanImageTiff < nansen.stack.data.VirtualArray


properties (Access = private, Hidden)
    hTiffStack TIFFStack
    tiffInfo
end

properties (Access = private, Hidden) % File Info
    NumChannels_
    NumPlanes_
    NumTimepoints_
end


methods % Structors
    
    function obj = ScanImageTiff(filePath, varargin)
        obj@nansen.stack.data.VirtualArray(filePath, varargin{:})
    end
    
    function delete(obj)
        
        if ~isempty(obj.hTiffStack)
            delete(obj.hTiffStack)
        end
        
        if ~isempty(obj.tiffInfo)
            close(obj.tiffInfo)
        end

    end
    
end


methods (Access = protected) % Implementation of abstract methods
        
    function assignFilePath(obj, filePath, ~)
        
        if isa(filePath, 'cell')
            obj.FilePath = filePath{1};
            
        elseif isa(filePath, 'char') || isa(filePath, 'string')
            obj.FilePath = char(filePath);
        end
        
    end
    
    function getFileInfo(obj)
        
        obj.tiffInfo = Tiff(obj.FilePath);

        obj.assignDataSize()
        
        obj.assignDataType()

    end
    
    function createMemoryMap(obj)
        
        % This should already have happened in assignDataSize
        if ~isempty(obj.hTiffStack)
           return 
        end
        
        % Just in case...
        numDirs = obj.NumChannels_ * obj.NumTimepoints_;
        
        warning('off', 'TIFFStack:SlowAccess')
        warning('off', 'TIFFStack:LongStack')

        obj.hTiffStack = TIFFStack(obj.FilePath, [], obj.NumChannels_, false, numDirs);
        warning('on', 'TIFFStack:SlowAccess')
        warning('on', 'TIFFStack:LongStack')

    end
    
    function assignDataSize(obj)
        
        evalc(obj.tiffInfo.getTag('ImageDescription'));
        evalc(obj.tiffInfo.getTag('Software'));
        
        obj.DataSize(1) = obj.tiffInfo.getTag('ImageLength');
        obj.DataSize(2) = obj.tiffInfo.getTag('ImageWidth');
        
        obj.NumTimepoints_ = SI.hStackManager.framesPerSlice;

        %obj.ImageSize(1) = SI.hRoiManager.linesPerFrame;
        %obj.ImageSize(2) = SI.hRoiManager.pixelsPerLine;

        obj.NumChannels_ = numel( SI.hChannels.channelSave );
        obj.countNumFrames();
        
        if obj.NumChannels_ == 1
            obj.DataSize(3) = obj.NumTimepoints_;
            obj.DataDimensionArrangement = 'YXT';
        else 
            obj.DataSize(3) = obj.NumChannels_;
            obj.DataSize(4) = obj.NumTimepoints_;
            obj.DataDimensionArrangement = 'YXCT';
        end

    end
    
    function assignDataType(obj)
        
        % Todo: Should be part of a tiff superclass
        sampleFormat = obj.tiffInfo.getTag('SampleFormat');
        bitsPerSample = obj.tiffInfo.getTag('BitsPerSample');
        
        switch sampleFormat
            case 1
                obj.DataType = sprintf('uint%d', bitsPerSample);
            case 2
                obj.DataType = sprintf('int%d', bitsPerSample);
            case 3
                
            otherwise
                error('Tiff file is not supported')
        end
    end
    
end

methods % Implementation of VirtualArray abstract methods
    
    function data = readData(obj, subs)
       data = obj.hTiffStack(subs{:});
    end
    
    function data = readFrames(obj, frameIndex)
        
        subs = cell(1, ndims(obj));
        subs(1:2) = {':'};
        
        if isa(frameIndex, 'cell')
            nCells = numel(frameIndex);
            subs(end-nCells+1:end) = frameIndex;
        elseif isnumeric(frameIndex)
            subs(end) = {frameIndex};
        end
        
        data = obj.hTiffStack(subs{:});
        
    end
       
    function writeFrames(obj, frameIndex, data)
        error('Not implemented yet')
    end
    
end


methods (Access = private)
    
    function countNumFrames(obj)
    %countNumFrames 
        
        % Need to create the memorymap in order to correct the framecount.
        obj.createMemoryMap()
        
        % Use the TIFFStack object and trial/error to get the correct
        % framecount. 
        frame_low = 1;
        frame_high = obj.NumTimepoints_;
        frame_current = frame_high;
        
        while frame_high - frame_low > 1
            try
                im = obj.hTiffStack(:,:, obj.NumChannels_, frame_current);
                frame_low = frame_current;
            catch e
                frame_high = frame_current;
            end
            
            frame_current = frame_low + floor((frame_high - frame_low)/2);
        end
        
        obj.NumTimepoints_ = frame_current;
    end
    
end


methods (Static)
    
    function createFile(filePath, arraySize, arrayClass)
        
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