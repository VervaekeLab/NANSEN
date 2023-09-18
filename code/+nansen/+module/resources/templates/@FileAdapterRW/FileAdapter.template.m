classdef {{Name}} < nansen.dataio.FileAdapter

    properties (Constant, Hidden, Access = protected)
        SUPPORTED_FILE_TYPES = {{SupportedFileTypes}}
    end

    properties (Constant)
        DataType = {{DataType}}
    end

    methods (Access = protected)
        function data = readData(obj, varargin)
            data = obj.read(obj.Filename, varargin{:});
        end

        function writeData(obj, data, varargin)
            obj.write(obj.Filename, data, varargin{:})
        end
    end

    methods (Static)
        
        data = read(filePath, varargin)

        write(filePath, data, varargin)
    
    end


end