%   Supports the following file extensions:

%   See also nansen.stack.virtual.Sequence/Sequence (Constructor)
    
% Todo: Describe/wrap dependency
%       RGB video?
%       Datatype
%       Frames per sec
%       Other metadata?

classdef Sequence < nansen.stack.data.VirtualArray
% Sequence - Class for to represent a virtual data adapter for a sequence file.
    
    properties (Constant, Hidden)
        FILE_PERMISSION = 'read'       % Only support reading from .seq files
        FILE_FORMATS = {'SEQ'}         % Supported file formats
    end
    
    properties (Access = private, Hidden)
        SequenceObject
        IsDirty = false                 % A flag indicating whether the file has been modified
    end
    
    methods % Structors
        
        function obj = Sequence(filePath, varargin)
        % Sequence - Creates a VirtualArray from a .seq file
        %
        %   Syntax:
        %
        %   virtualData = nansen.stack.virtual.Sequence(filePath) opens a
        %       virtualData object from a file with data stored in Sequence
        %       format.

            % Open folder browser if there are no inputs.
            if nargin < 1; filePath = uigetdir; end
            
            if isa(filePath, 'char')
                filePath = {filePath};
            end
            
            % Create a virtual stack object
            obj@nansen.stack.data.VirtualArray(filePath, varargin{:})
        end
         
        function delete(obj)

        end
    end

    methods (Access = protected) % Implementation of abstract methods
            
        function assignFilePath(obj, filePath, ~)
        %ASSIGNFILEPATH Assign path to the raw imaging data file.
        %
        %   Resolve whether the input pathString is pointing to the recording
        %   .ini file, the recording .raw file or the recording folder.
        
            if isa(filePath, 'cell') && numel(filePath)==1
                filePath = filePath{1};
            end
            
            % Find fileName from folderPath
            if obj.isSupportedFileType(filePath)
                [folderPath, fileName, ext] = fileparts(filePath);
                fileName = strcat(fileName, ext);

                
            elseif isfolder(filePath)
                folderPath = filePath;
                listing = dir(fullfile(folderPath, '*.seq'));
                fileName = listing(1).name;
                if isempty(fileName)
                    error('Did not find .seq file in the specified folder')
                end
                
            else
                error('Filepath does not point to a supported sequence file.')
            end
            
            obj.FilePath = fullfile(folderPath, fileName);
        end
        
        function getFileInfo(obj)
        %getFileInfo Get file info from metadata and assign to properties
        
            obj.createMemoryMap()
            info = obj.SequenceObject.getinfo();

            if ~isempty(info)
                obj.MetaData.Size = [info.height, info.width, info.numFrames];
                if info.imageBitDepth == 8
                    obj.MetaData.Class = 'uint8';
                else
                    error('Not implemented')
                end
            end
            
            if ischar(obj.MetaData.Size) % Temp fix
                obj.MetaData.Size = str2num(obj.MetaData.Size); %#ok<ST2NM>
            end
    
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
                    obj.DataDimensionArrangement = 'YXCZT';
                elseif numel(obj.DataSize) == 4
                    obj.DataDimensionArrangement = 'YXCT';
                elseif numel(obj.DataSize) == 3
                    obj.DataDimensionArrangement = 'YXT';
                end
            end
        end
        
        function assignDataType(obj)
            obj.DataType = obj.MetaData.Class;
        end
            
        function createMemoryMap(obj)
        %createMemoryMap Create a memory map for the seq file.
            if isempty(obj.SequenceObject)
                obj.SequenceObject = seqIo(obj.FilePath, 'reader');
            end
        end
    end
    
    methods % Implementation of abstract methods
        
        function data = readData(obj, subs)
            frameInd = subs{end};
            data = obj.readFrames(frameInd);
            data = data(subs{1:end-1}, :);
        end
        
        function data = readFrames(obj, frameInd) 	% defined in nansen.stack.data.VirtualArray
            data = zeros([obj.DataSize(1:2), numel(frameInd)], obj.DataType);

            for i = 1:numel(frameInd)
                obj.SequenceObject.seek( frameInd(i)-1 );
                im = obj.SequenceObject.getframe();
                if isempty(im)
                    keyboard
                else
                    data(:,:,i) = im;
                end
            end
        end

        function writeFrames(obj, frameInd, data)
            error('Not implemented')
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
end
