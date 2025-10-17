classdef numpy < nansen.dataio.FileAdapter
%numpy File adapter for a numpy file
    
    properties (Constant)
        DataType = 'struct'
    end
    
    properties (Constant, Hidden, Access = protected)
        SUPPORTED_FILE_TYPES = {'npy'}
    end
    
    methods % Constructor
        function obj = numpy(varargin)
            varargin{end+1} = '-tempmat'; % Todo...Override this from inputs
            obj@nansen.dataio.FileAdapter(varargin{:})
        end
    end
    
    methods (Access = protected)
        function data = readData(obj, varargin)
            fileInfo = dir(obj.Filename);
            fileSize = fileInfo.bytes;
            if fileSize < 4 * 1e9 % 4GB
                matFileName = obj.convertToMatfile();
                S = load(matFileName);
                data = S.data;
            else
                % Can not convert files larger than 4GB to .mat
                npObj = py.numpy.load(obj.Filename); data = single(npObj);
            end
        end
    end
end
