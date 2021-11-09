% Class for indexing data from a video file in the same manner that data 
% is indexed from matlab arrays.

classdef Video < nansen.stack.data.VirtualArray
        
    % Why is this so slow????

    properties (Access = private, Hidden)
        VideoReaderObj
    end
    
    properties
        FrameRate
    end
    
    methods % Structors
        
        function obj = Video(filePath, varargin)

            % Open folder browser if there are no inputs.
            if nargin < 1; filePath = uigetdir; end
            obj@nansen.stack.data.VirtualArray(filePath, varargin{:})
            
        end
        
        function delete(obj)
            if ~isempty(obj.VideoReaderObj)
                delete(obj.VideoReaderObj)
            end
        end
        
    end
    
    methods (Access = protected) % Implementation of abstract methods
        
        function obj = assignFilePath(obj, filePath, ~)
            
            % Todo: Add video formats and some validation of path
            
            if isa(filePath, 'cell') && numel(filePath) == 1
                filePath = filePath{1};
            end
            
            if isfolder(filePath)
                % Todo: Search folder, and select video. If several videos,
                % make a listbox dialog.
                error('Not implemented')
                
            elseif isfile(filePath) % Check that file is a supported video file
                [~, ~, ext] = fileparts(filePath);
                ffi = VideoReader.getFileFormats;
                
                ext = lower(strrep(ext, '.', ''));
                assert( any(contains({ffi.Extension} , ext) ), ...
                    'Video file format is not supported')
            else
                msg = 'Filepath does not point to any existing file or folder';
                error(msg);
            end
            
            obj.FilePath = filePath;

        end
        
        function getFileInfo(obj)
            
            obj.VideoReaderObj = VideoReader(obj.FilePath);
            obj.FrameRate = obj.VideoReaderObj.FrameRate;

            obj.assignDataSize()

            obj.assignDataType()

        end

        function createMemoryMap(~)
            % Not necessary, VideoReader is already initialized.
        end

        function assignDataSize(obj)

            obj.VideoReaderObj = VideoReader(obj.FilePath);
        
            obj.DataSize = [obj.VideoReaderObj.Height, obj.VideoReaderObj.Width];
            obj.DataDimensionArrangement = 'YX';

            obj.FrameRate = obj.VideoReaderObj.FrameRate;
            numTimepoints = round( obj.VideoReaderObj.Duration * obj.FrameRate );

            if contains(obj.VideoReaderObj.VideoFormat, 'RGB')
                numChannels = 3;
            elseif contains(obj.VideoReaderObj.VideoFormat, 'Grayscale')
                numChannels = 1;
            end
 
            % Add length of channels if there is more than one channel
            if numChannels > 1
                obj.DataSize = [obj.DataSize, numChannels];
                obj.DataDimensionArrangement(end+1) = 'C';
            end

            % Add length of sampling dimension.
            if numTimepoints > 1
                obj.DataSize = [obj.DataSize, numTimepoints];
                obj.DataDimensionArrangement(end+1) = 'T';
            end

        end

        function assignDataType(obj)
            tmpIm = readFrame(obj.videoReaderObj);
            obj.DataType = class(tmpIm);
        end

    end
    
    methods % Implementation of methods for reading data
           
        function data = readData(obj, subs)
            frameInd = subs{end};
            data = obj.getFrameSet(frameInd);
            data = data(subs{1:end-1}, ':');
        end
        
        function frameData = getFrame(obj, iFrame)
            obj.VideoReaderObj.currentTime = (iFrame-1) .* (1/obj.FrameRate);
            frameData = readFrame(obj.VideoReaderObj);    
        end
        
        function data = getFrameSet(obj, IND)
            
            newDataSize = obj.DataSize;
            newDataSize(end) = numel(IND);
        
            data = zeros(newDataSize, obj.DataType);
            
            if iscolumn(IND); IND = IND'; end
            
            c = 0;
            for i = IND
                
                if i > obj.NumTimepoints
                    break
                end
                
                obj.VideoReaderObj.currentTime = (i-1) .* (1/obj.FrameRate);
                frameData = obj.VideoReaderObj.readFrame();
                
                c = c+1;
                if obj.NumChannels == 1 && numel(newDataSize) == 3
                    data(:, :, c) = frameData;
                elseif obj.NumChannels > 1 && numel(newDataSize) == 4
                    data(:, :, :, c) = frameData;
                else
                    error('Unexpected data size')
                end
            end
            
        end
        
    end
    
end