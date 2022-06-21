classdef ImageStack < nansen.dataio.FileAdapter
%IMAGESTACK File adapter for a file that can be opened as an ImageStack
%
%   This file adapter provides methods to load the data from files that
%   contains multidimensional image data as virtual ImageStack objects. 
%
%   Supported file formats: 
%       binary files (raw/bin)
%       tiff files (tif/tiff)
%       movie files (avi)
%       hdf5 files (h5)
    
    % Note 1: Saving data will always overwrite the existing data.
    % Note 2: Saving of data is only supported for tiff files.


    properties (Constant)
        DataType = 'ImageStack'
        Description = 'This file contains image stack / video data';
    end
    
    properties (Constant, Hidden, Access = protected)
        SUPPORTED_FILE_TYPES = {'ini', 'raw', 'tif', 'tiff', 'avi', 'h5'}
    end
    
    methods (Access = protected)
        
        function imageStack = readData(obj, varargin)
        %readData Read image data as a virtual ImageStack
            
            virtualDataFcn = str2func( obj.getVirtualDataClassName() );
            
            switch obj.FileType
                case 'h5'
                    % For h5 files, a dataset name might be supplied
                    virtualData = virtualDataFcn(obj.Filename, varargin{:});
                otherwise
                    virtualData = virtualDataFcn(obj.Filename);
            end
            
            imageStack = nansen.stack.ImageStack(virtualData);
        end
        
        function writeData(obj, data, varargin)
        %writeData Write image data to a file using virtual adapter
            virtualDataClassName = obj.getVirtualDataClassName();
            saveFcn = str2func( [virtualDataClassName, '.createFile'] );
            
            try
                saveFcn(obj.Filename, data);
            catch
                writeData@nansen.dataio.FileAdapter(obj)
            end
        end
        
    end
    
    methods
    
        function create(obj, dataSize, dataType)
            % todo
        end
        
        function open(obj)
            imageStack = obj.load();
            imviewer(imageStack)
        end
        
        function view(obj)
            imageStack = obj.load();
            imviewer(imageStack)
        end
        
        function uifind(obj, varargin)
            %obj.FileSelectionMode = 'multiple';
            uifind@nansen.dataio.FileAdapter(obj, varargin{:})
        end
        
    end
    
    methods (Access = private)
        
        function className = getVirtualDataClassName(obj)
        %getVirtualDataClassName Get full name of class for virtual data
        %
        %   Name of the class to be used for creating a virtual data
        %   object depends on the filetype of the file adapter
        
            % Check if a virtual data class exists based on the filename
            className = obj.getVirtualDataClassNameFromFilename(obj.Filename);
            if ~isempty(className); return; end
            
            % Otherwise, get a "generic" data adapter based on the filetype
            switch obj.FileType

                case 'h5'
                    className = 'nansen.stack.virtual.HDF5';
                
                case {'avi', 'mov', 'mpg', 'mp4'}
                    className = 'nansen.stack.virtual.Video';
                    
                case 'raw'
                    className = 'nansen.stack.virtual.Binary';
                    
                case {'tif', 'tiff'}
                    className = 'nansen.stack.virtual.TiffMultiPart';

                case 'mdf'
                    className = 'nansen.stack.virtual.MDF';

                otherwise
                    error('Nansen:DataIO:FileTypeNotSupported', ...
                        'File type "%s" can not be opened as an ImageStack', ...
                        obj.FileType)
            end
        end
    end 
        
    methods (Static)
        
        function className = getVirtualDataClassNameFromFilename(filename)

            className = '';
            
            % Todo: Make function for getting list of virtual data classes
            
            virtualDataClasses = { ...
                'nansen.stack.virtual.SciScanRaw', ...
                'nansen.stack.virtual.PrairieViewTiffs', ...
                'nansen.stack.virtual.TiffMultiPartMultiChannel', ...
                'nansen.stack.virtual.Suite2pCorrected' ...
                };
            
            for i = 1:numel(virtualDataClasses)
                
                thisClassName = virtualDataClasses{i};
                fileNameExpression = eval([thisClassName, '.FilenameExpression']);
                
                if ~isempty( regexp(filename, fileNameExpression, 'once') )
                    className = thisClassName;
                end
            
            end
        end
        
    end
    
end

