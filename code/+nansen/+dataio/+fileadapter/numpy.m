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
            matFileName = obj.convertToMatfile();
            S = load(matFileName);
            data = S.data;
        end
    end
end
