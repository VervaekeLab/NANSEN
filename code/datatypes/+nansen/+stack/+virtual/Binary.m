% Class for indexing data from a binary file in the same manner that data 
% is indexed from matlab arrays.

classdef Binary < nansen.stack.data.VirtualArray
%Binary Create a virtual data adapter for a binary file.
%
% NOTE: Currently assumes that data in binary file is a 3d stack. This
% should be changed to full support for 5D stacks
    
    % Todo: 
    %   [ ] Generalize.
    %   [ ] Open input dialog to enter info about how to open data (format)
    %       if ini file is not available
    %   [ ] Implement data write functionality.
    %   [x] Add methods for writing ini variables...
    %   [ ] Add more fileformats?    
    
properties (Constant, Hidden)
    FILE_PERMISSION = 'write'       % Binary files have write permission
    FILE_FORMATS = {'RAW', 'BIN'}   % Supported file formats
end

properties (Access = private, Hidden)
    MemMap                          % A matlab memorymap for a binary file
end

methods % Structors
    
    function obj = Binary(filePath, varargin)
       
        % Open folder browser if there are no inputs.
        if nargin < 1; filePath = uigetdir; end
        
        if isa(filePath, 'char')
            filePath = {filePath};
        end
        
        % Create a virtual stack object
        obj@nansen.stack.data.VirtualArray(filePath, varargin{:})
    end
     
    function delete(obj)
        
        obj.writeMetadata()

        % If both ini- and yaml file exists, delete the ini file.
        iniPath = nansen.stack.virtual.Binary.getIniFilepath(obj.FilePath);
        if isfile(iniPath); delete(iniPath); end
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
            
        elseif contains(filePath, '.ini')
            [folderPath, fileName, ~] = fileparts(filePath);
            fileName = strcat(fileName, '.raw');
            
        elseif isfolder(filePath)
            folderPath = filePath;
            listing = dir(fullfile(folderPath, '*.raw'));
            fileName = listing(1).name;
            if isempty(fileName) 
                error('Did not find raw file in the specified folder')
            end
            
        else
            error('Filepath does not point to a supported Binary file.')
        end
        
        obj.FilePath = fullfile(folderPath, fileName);
    end
    
    function getFileInfo(obj)
    %getFileInfo Get file info from metadata and assign to properties
    
        S = obj.readinifile(obj.FilePath);
        if ~isempty(S)
            obj.MetaData.Size = S.Size;
            obj.MetaData.Class = S.Class;
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
    %createMemoryMap Create a memory map for the binary file.
    
        mapFormat = {obj.DataType, obj.DataSize, 'ImageArray'};
        
        % Memory map the file (newly created or already existing)
        obj.MemMap = memmapfile( obj.FilePath, 'Writable', true, ...
            'Format', mapFormat );
    end
    
end

methods % Implementation of abstract methods
    
    function data = readData(obj, subs)
        data = obj.MemMap.Data.ImageArray(subs{:});
    end
    
    function writeData(obj, subs, data)
        obj.MemMap.Data.ImageArray(subs{:}) = data;
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

methods (Static, Access = protected)
    
    function iniFilepath = getIniFilepath(filepath)
        [folder, filename, ~] = fileparts(filepath);
        iniFilepath = fullfile(folder, [filename, '.ini']);
    end
        
    function S = readinifile(filepath)
        
        S = struct.empty; % Initialize output.
        
        % Get name of inifile
        iniPath = nansen.stack.virtual.Binary.getIniFilepath(filepath);
        
        if ~isfile(iniPath)
            return
        else
            S = struct; % Initialize a struct which is not empty
        end
        
        % Read inifile
        iniString = fileread(iniPath);

        % Determine start of and end of lines
        endOfLine = cat(2, regexp(iniString, '\n') );
        startOfLine = cat(2, 1, endOfLine(1:end-1)+1);

        for i = 1:numel(startOfLine)

            varLine = iniString(startOfLine(i):endOfLine(i)-1);
            varLineSplit = regexp(varLine, '\ = |\"', 'split');
            varName = strtrim(varLineSplit{1});

            switch varName
                case 'Size'
                    varVal = varLineSplit{2};
                    varVal = strsplit(varVal, ' ');
                    varVal = arrayfun(@(x) str2double(x), varVal);
                case 'Class'
                    varVal = strtrim(varLineSplit{2});
                otherwise
                    varVal = strtrim(varLineSplit{2});
            end

            S.(varName) = varVal;

        end
    end

    function TF = writeinifile(filepath, S)
    %writeinifile Write Size and Class to a inifile.
    
    % Note: This file is written on creation of a binary file. It will be
    % replaced with a yaml "metadata" file when the binary file is read as
    % a virtual array.
    
        % Todo: replace with FEX struct2ini?
    
        assert(isfield(S, 'Size'), 'Size input is missing')
        assert(isfield(S, 'Class'), 'Class input is missing')

        % Get name of inifile
        iniPath = nansen.stack.virtual.Binary.getIniFilepath(filepath);

        if ispc
            fid = fopen(iniPath, 'wt');
        else
            fid = fopen(iniPath, 'w');
        end

        fieldNames = fieldnames(S);

        for i = 1:numel(fieldNames)
            switch fieldNames{i}
                case 'Size'
                    fprintf(fid, '%s = %s\n', 'Size', num2str(S.Size));
                case 'Class'
                    fprintf(fid, '%s = %s\n', 'Class', S.Class);
            end
        end
        
        % Todo: Add some error handling here.
        TF = true;

        fclose(fid);

        if ~nargout 
            clear TF
        end
        
    end
    
end

methods (Static)
    
    function createFile(filePath, arraySize, arrayClass)
        if ndims(arraySize) > 2 %#ok<ISMAT>
            % Binary file can be initialized with a size input, but not an
            % array
            error('Writing of data to binary file is not supported yet')
        end
        nansen.stack.virtual.Binary.initializeFile(filePath, arraySize, arrayClass)
    end
    
    function initializeFile(filePath, arraySize, arrayClass)
    
        S = struct('Size', arraySize, 'Class', arrayClass);

        % Create file if it does not exist
        if ~exist(filePath, 'file')
            assert(isfield(S, 'Size'), 'Size input is missing')
            assert(isfield(S, 'Class'), 'Class input is missing')
            
            % Todo: Make this function part of the utility package?
            nansen.stack.virtual.Binary.writeinifile(filePath, S)

            numBytes = nansen.stack.ImageStack.getImageDataByteSize(...
                arraySize, arrayClass);

            if ispc
                [status, ~] = system(sprintf('cmd /C fsutil file createnew %s %i', filePath, numBytes));
            elseif ismac
                status = 1;
            end

            if status % Backup solution
                fileId = fopen(filePath, 'w');
                fwrite(fileId, 0, 'uint8', numBytes-1); % 4th arg: skip
                fclose(fileId);
            end

        else
            fprintf('Binary file already exists: %s\n', filePath)
        end

    end
    
end 

end