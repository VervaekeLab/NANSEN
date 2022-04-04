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
            
            virtualDataFcn = obj.getVirtualDataFunctionHandle();
            
            switch obj.FileType
                case 'h5'
                    % For h5 files, a dataset name might be supplied
                    virtualData = virtualDataFcn(obj.Filename, varargin{:});
                otherwise
                    virtualData = virtualDataFcn(obj.Filename);
            end
            
            imageStack = nansen.stack.ImageStack(virtualData);

        end
        
    end
    
    methods
    
        function create(obj, dataSize, dataType)
            % todo
        end
        
        function save(obj, data)
            % Todo:
            virtualDataFcn = obj.getVirtualDataFunctionHandle();

            name = strsplit( builtin('class', obj), '.');
            error('Saving is not yet implemented for the file adapter %s', class(obj))
        end

        function open(obj)
            imageStack = obj.load();
            imviewer(imageStack)
        end
        
        function view(obj)
            imageStack = obj.load();
            imviewer(imageStack)
        end
        
    end
    
    methods (Access = private)
        
        function fcnHandle = getVirtualDataFunctionHandle(obj)
        %getVirtualDataFunctionHandle Get function handle for virtual data
        %
        %   The function handle to be used for creating a virtual data
        %   object depends on the filetype of the file adapter
        
            switch obj.FileType

                case 'h5'
                    fcnHandle = @nansen.stack.virtual.HDF5;
                
                case {'avi', 'mov', 'mpg', 'mp4'}
                    fcnHandle = @nansen.stack.virtual.Video;
                    
                case 'raw'
                    fcnHandle = @nansen.stack.virtual.Binary;
                
                otherwise
                    error('Nansen:DataIO:FileTypeNotSupported', ...
                        'File type "%s" can not be opened as an ImageStack', ...
                        obj.FileType)
            end
            
        end
        
    end
    
end

