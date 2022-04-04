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
            
            if isempty(varargin)
                return; 
            else
                
                if any( cellfun(@(c) isequal(c, '-w'), varargin) ) ...
                    || any( cellfun(@(c) isequal(c, 'writable'), varargin) )
                    obj.Writable = true;
                end
            
                try
                    obj.Filename = varargin{1};
                    varargin(1) = [];
                catch
                    % Pass
                end
            end
            
            
            % Todo: Accept name value pair specifying writable...
            [nvPairs, varargin] = utility.getnvpairs(varargin{:});
            
            
        end
        
    end
    
    methods (Access = protected) % writeData (not implemented)
        
        function writeData(obj, data, varargin)
        %writeData Write (save) data to file 
            error('The file adapter "%s" does not support saving of data to file')
            % Subclass can implement
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
        
        function uifind(obj, initFolderPath)
        %uifind Open file browser to let user select a file
        
        % Todo: Implement selection mode. Property?
        
            if nargin < 2
                initFolderPath = '';
            end
            
            fileFilter = obj.getFileFilter();
            titleStr = sprintf( 'Select a "%s" file:', class(obj) );
            
            [filename, folderPath] = uigetfile(fileFilter, titleStr, ...
                initFolderPath);

            if ~filename == 0
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
        
        function fileFilter = getFileFilter(obj)
        %getFileFilter Get file filter for use in uigetfile    
            fileFilter = strcat('*.', obj.SUPPORTED_FILE_TYPES );
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
    end
    
    methods (Hidden)
        function cls = class(obj)
            className = strsplit(builtin('class', obj), '.');
            cls = sprintf('FileAdapter (%s)', className{end});
        end
    end

end