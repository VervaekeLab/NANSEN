classdef (Abstract) FileAdapter < handle & matlab.mixin.CustomDisplay
%FileAdapter Interface for loading, saving and viewing data in a file.
%
%   The file adapter superclass defines a template for creating specific
%   file adapters for loading and saving data to and from different file
%   formats that may or may not be supported in matlab.
%
%   A subclass must at minimum implement the properties DataType and
%   SUPPORTED_FILE_TYPES and the method readData. It may also implement
%   writeData, view and open.
%
%   SIMPLE USAGE:
%       fileAdapterObj = fileAdapter(filename) creates a fileadapter object
%           for the given file. filename is the absolute path including
%           filepath, filename and file extension.
%
%       fileAdapterObj = fileAdapter(filename, 'writable') creates the file
%           adapter object with write permission to the file.
%
%       data = fileAdapter.load() will load data from the file and return
%           in the variable data. Some existing subclasses returns a memory
%           mapped representation of the data, so in practice the data is 
%           not actually loaded, but for simplicity of usage, the load
%           method can present the user with both in-memory and with virtal
%           data.
%
%       The filadapter gives an object oriented strategy to load, modify 
%       and save data:
%
%       fileAdapterObj = fileAdapter(filename);
%       data = fileAdapterObj.load()
%       modifiedData = someFunction(data);
%       fileAdapterObj.save(modifiedData)
%
%   Subclasses may implement a view method, which purpose is to open the
%   data in a custom dislay or viewer.
%
% ABSTRACT PROPERTIES:
%   DataType             : Which data type does the file adapter return
%   Description          : Description of the data in the file
%   SUPPORTED_FILE_TYPES : Which file types are supported for the file adapter?
%
% ABSTRACT METHODS:
%   readData             : Method that reads data from file
%
%   A note on the abstract properties: These might be useful for external
%   packages in order to determine what file adapters to use as as default
%   for specific data types and what data to expect.


% Todo: Add generic write2mat for subclasses to use...
%   [ ] implement selection of multiple files..

% - - - - - - - - - - - - PROPERTIES - - - - - - - - - - - - - - - - - - - 

    properties (Dependent)
        Filename char
        Metadata nansen.dataio.metadata.AbstractMetadata
        Name char
    end

    properties (Abstract, Constant)
        DataType
    end
    
    properties %(SetAccess = immutable) ??
        Writable = false;   % Does the file adapter have write permission?
    end
    
    properties (SetAccess = private, Hidden)
        DiscardConvertedMatfile = false % Should we store matfile copy if data is converted from a different file format. false = delete file, true = keep file
        RedoFileConversion = false
    end
    
    properties (Access = protected)
        FileSelectionMode = 'single'; % 'single' | 'multiple'
    end
    
    properties (Abstract, Constant, Hidden, Access = protected)
        % Todo?: Support grouping of filetypes for similar files in nested
        % cell arrays, i.e { {tif, tiff}, {'png, 'jpg'}, {'mov', 'avi',
        % 'mp4'} }
        SUPPORTED_FILE_TYPES cell
    end
    
    properties (Dependent, Access = protected)
        FileType % The file type as described by the file extension
    end

    properties (Access = private)
        Filename_  % Internal store for the filename
        Metadata_
        CachedData % Todo: Implement a global cache and make sure it is not overfilled.
        FileCleanupList % list with paths of files to clean.
    end
    
% - - - - - - - - - - - - - METHODS - - - - - - - - - - - - - - - - - - - 

    methods (Abstract, Access = protected)

        % Method for reading data from file
        data = readData(obj, varargin)
        
    end
    
    methods (Static, Access = protected)
        
        function S = getDefaultMetadata()
        %getDefaultMetadata Get default metadata for class
            S = struct(); 
            % Subclasses may override
        end
        
    end
    
    methods % Constructor
        
        function obj = FileAdapter(varargin)
        %FileAdapter Constructor of file adapter object.
        
            if isempty(varargin); return; end % uninitialized file adapter
            
    
            flagProps = {...
                'Writable', 'DiscardConvertedMatfile', ...
                'RedoFileConversion' };

            % Need to set these in constructor because of set access
            for i = 1:numel(flagProps)
                if obj.containsFlag(varargin, flagProps{i})
                    obj.(flagProps{i}) = true;
                end
            end

            try
                obj.Filename = varargin{1};
                varargin(1) = [];
            catch
                % Pass
            end
            
            % Todo: Accept name/value pairs specifying property values
            [nvPairs, varargin] = utility.getnvpairs(varargin{:}); %#ok<ASGLU>
            
        end
        
        function delete(obj)
            if ~isempty(obj.FileCleanupList)
                obj.deleteTemporaryFiles(); % File should be deleted when this is cleared
            end
        end
    end
    
    methods (Access = private)
        
        function tf = containsFlag(~, C, flagName)
        %containsFlag Check is cell array contains a specified flag
        %
        %   tf = obj.containsFlag(C, flag) returns true (1) if cell array C
        %   contains the specified flag. Flag is a character vector
        %
        %   Flag names:
        %       Writable
        %       SaveMatfileOnConversion
        
            tf = false;
            
            containsflag = @(str) any(cellfun(@(c) isequal(c, str), C));
            
            switch flagName
                case 'Writable'
                    tf = containsflag('-w') || containsflag('writable');
                    
                case 'DiscardConvertedMatfile'
                    tf = containsflag('-tempmat');
                    
                case 'RedoFileConversion'
                    tf = containsflag('-u');
                    
            end
            
        end
        
        function deleteTemporaryFiles(obj)
        %deleteTemporaryFiles Delete temporary files in file cleanup list.    
            for i = 1:numel(obj.FileCleanupList)
                if isfile(obj.FileCleanupList{i})
                    delete(obj.FileCleanupList{i})
                end
            end
        end
    end
    
    methods (Access = protected) % writeData (not implemented)
        
        function writeData(obj, data, varargin) % Subclass can override
        %writeData Write (save) data to file 
            name = strsplit( builtin('class', obj), '.');
            error('The file adapter "%s" does not support saving of data to file.', name{end})
        end
        
        function writeDataToMat(obj, S, varargin)
        %writeDataToMat General method to write data to matfile
        
            % Todo: Test/debug this...
            
            % Use v7.3 is variable is large...
            varInfo = whos('S');
            byteSize = varInfo.bytes;

            if byteSize > 2^31
                versionFlag = '-v7.3';
            else
                versionFlag = '-v7';
            end
            
            
            if isfile(obj.Filename)
                save(obj.Filename, '-struct', 'S', '-append', versionFlag)
            else
                save(obj.Filename, '-struct', 'S', versionFlag)
            end
            
        end
        
    end
    
    methods % View/open (not implemented)
        
        % Method for opening data
        function open(obj)
            % Subclass can implement
            error('View is not implemented for file adapter "%s"', class(obj))
        end
        
        % Method for viewing data
        function view(obj)
            % Subclass can implement
            error('View is not implemented for file adapter "%s"', class(obj))
        end
        
    end
    
    methods % Set/get methods
        
        function set.Filename(obj, newValue)
        %SET.FILENAME Set method for Filename property
            if ~isempty(obj.Filename_) && ~isequal(obj.Filename_, newValue)
                error('Filename is already set for this FileAdapter')
            elseif isequal(obj.Filename_, newValue)
                return
            end
            
            assert(ischar(newValue), ...
                'Nansen:FileIO:InvalidInput', ...
                'Filename must be a character vector')
            
            % Todo: Loosen this?
            if ~obj.Writable
                assert(isfile(newValue), ...
                    'Nansen:FileIO:FileDoesNotExist', ...
                    'Filename must point to an existing file')
            else
                [~, filename, ext] = fileparts(newValue);
                assert(~isempty(filename) && ~isempty(ext), ...
                    'Nansen:FileIO:InvalidFilename', ...
                    'Filename must be a valid filename' )
            end
            
            % Todo: Assert that file is a supported filetype
            
            obj.Filename_ = newValue;
            
            obj.initializeMetadata()
        end
        
        function filename = get.Filename(obj)
        %GET.FILENAME Get method for Filename property
            filename = obj.Filename_;
        end
        
        function name = get.Name(obj)
            [~, name, ~] = fileparts(obj.Filename);
        end
        
        function fileType = get.FileType(obj)
            [~, ~, fileExt] = fileparts(obj.Filename);
            fileType = strrep(fileExt, '.', '');
        end
        
        function metadata = get.Metadata(obj)
            obj.readMetadata();
            metadata = obj.Metadata_.MetadataStruct;
        end
    end
    
    methods % Load/save
                
        function data = load(obj, varargin)
            
            obj.validateFilepath('load');
                       
            if obj.isCached()
                data = obj.getCachedData(); 
                if ~isempty(data); return; end
            end
            
            data = obj.readData(varargin{:});
            
            obj.setCachedData(data)

        end
        
        function save(obj, data, varargin)
            obj.assertIsWritable()
            obj.validateFilepath('save');
            
            obj.writeData(data, varargin{:})
            obj.setCachedData(data)
        end
        
        function setMetadata(obj, name, value, groupName)
            obj.validateFilepath('write meta')
            obj.readMetadata();
            obj.Metadata_.set(name, value, groupName);
            obj.writeMetadata();
        end
        
    end
    
    methods % Utility methods
        
        function uiopen(obj, initFolderPath)
            if nargin < 2; initFolderPath = ''; end
            obj.uifind(initFolderPath)
        end
        
        function uifind(obj, initFolderPath)
        %uifind Open file browser to let user select a file
        
        % Todo: Implement selection mode. Property?
        
            if nargin < 2
                initFolderPath = '';
            end

            fileFilter = obj.getFileFilter();
            fileFilter = ['*.*'; fileFilter];
            titleStr = sprintf( 'Select a "%s" file:', class(obj) );
            
            [filename, folderPath] = uigetfile(fileFilter, titleStr, ...
                initFolderPath, 'MultiSelect', 'off'); %obj.getMultiSelectionMode());

            if ~isequal(filename, 0)
                obj.Filename_ = fullfile(folderPath, filename);
            end
            
        end
        
        function fileTypes = getFileTypes(obj)
            fileTypes = obj.SUPPORTED_FILE_TYPES;
        end
        
    end
    
    methods (Access = protected) % Internal methods
        
        function assertIsWritable(obj)
            assertMsg = 'This file adapter does not have write permission';
            assert(obj.Writable, assertMsg)
        end
        
        function validateFilepath(obj, action)
                        
            if isempty(obj.Filename)
                error('Nansen:FileIO:FilenameMissing', ...
                    'Can not %s data because Filename is not set.', action)
            end
            
            switch action
                case 'load'
                    if ~isfile(obj.Filename)
                        error('Nansen:FileIO:FilenameDoesNotExist', ...
                            'Can not %s data because file does not exist.', action)
                    end
            end

        end
        
        function mode = getMultiSelectionMode(obj)
            if strcmp(obj.FileSelectionMode, 'single')
                mode = 'off';
            else
                mode = 'on';
            end
        end
        
        function fileFilter = getFileFilter(obj)
        %getFileFilter Get file filter for use in uigetfile    
            fileFilter = strcat('*.', obj.SUPPORTED_FILE_TYPES );
            if isrow(fileFilter); fileFilter = fileFilter'; end
            % Note: If file filter is a cell array, its N rows x 2 columns
            % where the second colum is an optional description.
        end
        
        function str = getHeader(obj) % < matlab.mixin.CustomDisplay 
            str = getHeader@matlab.mixin.CustomDisplay(obj);
            className = strsplit(builtin('class', obj), '.');
            
            displayName = sprintf('FileAdapter (%s)', className{end});
            str = strrep(str, className{end}, displayName);
        end
        
        % % Caching of data.
        
        function tf = isCached(obj)
            tf = false;
            %tf = ~isempty(obj.CachedData);
        end
        
        function data = getCachedData(obj)
            data = obj.CachedData;
            if isa(data, 'handle') && ~isvalid(data)
                data = [];
            end
        end
        
        function setCachedData(obj, data)
            obj.CachedData = data;
        end
                
        % % Metadata (Should these be part of another class?)
        
        function S = getMetadataHeader(obj) % Todo: Make metadata plugin...
        %getMetadataHeader Get human readable header for the metadata file 
            [filepath, name, ext] = fileparts(obj.Filename);
            
            S = struct();
            S.File = struct;
            
            S.File.Description = obj.Description;
            S.File.FileAdapter = builtin('class', obj);
            S.File.Filepath = filepath;
            S.File.Filename = strcat(name, ext);
            S.File.Details = {''};
        end 
        
        function writeMetadata(obj, S)
        %writeMetadata Write struct to a yaml metadata file
            if isempty(obj.Metadata_); return; end
            if ~isfile(obj.Filename); return; end
            if nargin >=2 && ~isempty(S)
                obj.Metadata_.writeToFile(S);
            else
                obj.Metadata_.writeToFile();
            end
        end
        
        function readMetadata(obj)
        %readMetadata Read struct from a yaml metadata file
            if isempty(obj.Metadata_); return; end
            obj.Metadata_.readFromFile();
        end
        
        function initializeMetadata(obj)
            % Subclasses may override
            S = obj.getMetadataHeader();
            S.Data = obj.getDefaultMetadata;
            obj.Metadata_ = nansen.dataio.metadata.GenericMetadata(obj.Filename, S);
        end
        
        function matFileName = convertToMatfile(obj)
        %convertToMatfile Convert file to matfile using default converters
            
            [folderpath, name, ext] = fileparts(obj.Filename);
            
            matFileName = fullfile(folderpath, [name, '.mat']);
            
            
            if isfile(matFileName) && obj.RedoFileConversion
                delete(matFileName)
            elseif isfile(matFileName) && ~obj.RedoFileConversion
                return
            else
                % pass, mat file does not exist, conversion is needed
            end
            
            switch ext
                case '.npy'
                    filepathMat = obj.convertNumpyFile(obj.Filename);
                    
                otherwise
                    error('Conversion is not available for files with the "%s" extension', ext)
                        
            end
            
            if obj.DiscardConvertedMatfile
                obj.FileCleanupList = [obj.FileCleanupList, {filepathMat}];
            end
                        
        end
        
    end
    
    methods (Hidden)
        function cls = class(obj)
            className = strsplit(builtin('class', obj), '.');
            cls = sprintf('FileAdapter (%s)', className{end});
        end
    end
    
    methods (Static)
        
        function filepathMat = convertNumpyFile(filepathNpy)
        %convertNumpyFile Convert numpy to matfile
        
            thisFolderPath = fileparts(mfilename('fullpath'));
            filepathPyScript = fullfile(thisFolderPath, '+fileconvert', ...
                'numpy2mat.py');
            
            % Convert file in place:
            filepathMat = strrep(filepathNpy, '.npy', '.mat');
            
            if ispc
                commandStrTemplate = 'python.exe "%s" "%s" "%s"'; % pyFile, sourceFile, targetFile
            elseif ismac
                commandStrTemplate = 'python "%s" "%s" "%s"'; % pyFile, sourceFile, targetFile
            elseif isunix
                commandStrTemplate = 'python "%s" "%s" "%s"'; % Todo: Is this correct?
            else
                error('Unknown operating system')
            end
            
            commandStr = sprintf(commandStrTemplate, filepathPyScript, filepathNpy, filepathMat);
            
            % Run conversion using system
            [status, cmdout] = system(commandStr);
            
            if not( status == 0 )
                error('File conversion from .npy to .mat failed with following message:\n%s\n', cmdout)
            end
            
        end
        
        function filepathMat = convertTdmsFile(filepathTdms)
            error('not implemented yet')
        end
        
    end

end