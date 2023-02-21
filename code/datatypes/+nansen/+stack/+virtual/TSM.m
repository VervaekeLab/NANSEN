% Class for indexing data from a tsm file in the same manner that data 
% is indexed from matlab arrays.

classdef TSM < nansen.stack.data.VirtualArray
%Binary Create a virtual data adapter for a tsm file.
%
% NOTE: Currently assumes that data in tsm file is a 3D stack. This
% should(?) be changed to full support for 5D stacks

properties (Constant, Hidden)
    FILE_PERMISSION = 'read'       % Binary files have write permission
    FILE_FORMATS = {'TSM'}   % Supported file formats
end

properties (Access = private, Hidden)
    MemMap                          % A matlab memorymap for a binary file
    DarkFrame 
end

methods % Structors
    
    function obj = TSM(filePath, varargin)
       
        % Open folder browser if there are no inputs.
        if nargin < 1; filePath = uigetdir; end
        
        if isa(filePath, 'char')
            filePath = {filePath};
        end
        
        % Create a virtual stack object
        obj@nansen.stack.data.VirtualArray(filePath, varargin{:})
    end
    
end

methods (Access = protected) % Implementation of abstract methods
        
    function assignFilePath(obj, filePath, ~)
    %ASSIGNFILEPATH Assign path to the raw imaging data file.
    
        if isa(filePath, 'cell') && numel(filePath)==1
            filePath = filePath{1};
        end
        
        % Find fileName from folderPath
        if obj.isSupportedFileType(filePath)
            [folderPath, fileName, ext] = fileparts(filePath);
            fileName = strcat(fileName, ext);

        elseif isfolder(filePath)
            folderPath = filePath;
            listing = dir(fullfile(folderPath, '*.tsm'));
            fileName = listing(1).name;
            if isempty(fileName) 
                error('Did not find tsm file in the specified folder')
            end
            
        else
            error('Filepath does not point to a supported TSM file.')
        end
        
        obj.FilePath = fullfile(folderPath, fileName);
    end
    
    function getFileInfo(obj)
    %getFileInfo Get file info from metadata and assign to properties
    
        warning('off', 'MATLAB:imagesci:fitsinfo:unknownFormat');
        fileInfo    = fitsinfo(obj.FilePath);
        warning('on', 'MATLAB:imagesci:fitsinfo:unknownFormat');
            
        % Data is stored as x-y
        obj.MetaData.Size = fileInfo.PrimaryData.Size([2,1,3]);
        obj.MetaData.Class = 'int16';

        % Index for exposure time. Hope this is stable...
        obj.MetaData.TimeIncrement = fileInfo.PrimaryData.Keywords{11,2};

        obj.assignDataSize() % Assign size related properties
        
        obj.assignDataType() % Assign data type property
    end

    function assignDataSize(obj)
    %assignDataSize Assign DataSize (and DataDimensionArrangement)
    
        % DataSize should be present in MetaData.
        obj.DataSize = obj.MetaData.Size;
        
        % Assume default data dimension arrangement
        if isempty(obj.DataDimensionArrangement)
            if numel(obj.DataSize) == 5
                error('Not implemented')
                obj.DataDimensionArrangement = 'XYCZT';
            elseif numel(obj.DataSize) == 4
                error('Not implemented')
                obj.DataDimensionArrangement = 'XYCT';
            elseif numel(obj.DataSize) == 3
                obj.DataDimensionArrangement = 'XYT';
            end
        end
    end
    
    function assignDataType(obj)
        obj.DataType = obj.MetaData.Class;
    end
        
    function createMemoryMap(obj)
    %createMemoryMap Create a memory map for the binary file.
        
        HEADER_SIZE = 2880;
        
        mapFormat = {...
            'uint8', HEADER_SIZE, 'FileHeader'; ...
            obj.DataType, obj.DataSize(), 'ImageArray'; ...
            obj.DataType, obj.DataSize(1:2), 'DarkFrame'};
        
        % Memory map the file (newly created or already existing)
        obj.MemMap = memmapfile( obj.FilePath, 'Writable', false, ...
            'Format', mapFormat );
    end
    
end

methods % Implementation of abstract methods
    
    function data = readData(obj, subs)
        data = obj.MemMap.Data.ImageArray(subs{:});
        
        if isempty(obj.DarkFrame)
            obj.DarkFrame = obj.MemMap.Data.DarkFrame;
        end
        data = data - obj.DarkFrame;
    end
    
    function writeData(~, ~, ~)
        %obj.MemMap.Data.ImageArray(subs{:}) = data;
    end
    
    function data = readFrames(obj, frameInd) 	% defined in nansen.stack.data.VirtualArray
        subs = obj.frameind2subs(frameInd);
        data = obj.MemMap.Data.ImageArray(subs{:});
    end
    
    function writeFrames(obj, data, frameInd)	% defined in nansen.stack.data.VirtualArray
        obj.writeFrameSet(data, frameInd)
    end

    function writeFrameSet(obj, data, frameInd, subs)
    %writeFrameSet Write provided set of data frames to file
    
        % Todo: Can I make order of arguments equivalent to upstream
        % functions?
        
        if nargin < 3
            subs = obj.frameind2subs(frameInd);
        end
        
        obj.MemMap.Data.ImageArray(subs{:}) = data;
    end
    
end

methods (Access = private)
    
    function tf = isSupportedFileType(obj, filePath)
    %isSupportedFileType Check if given filepath is supported file type    
        [~, ~, ext] = fileparts(filePath);
        ext = strrep(ext, '.', '');
        
        tf = any(strcmpi(obj.FILE_FORMATS, ext));
    end
    
end

methods (Static)
    
    function createFile(~, ~, ~)
        error('Writing of data to tsm file is not supported')
    end
    
    function initializeFile(~, ~, ~)
        error('Creating tsm files is not supported')
    end
    
end

end