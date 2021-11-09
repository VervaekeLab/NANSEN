classdef MatlabArray < nansen.stack.data.abstract.ImageStackData
%MatlabArray ImageStackData implementation for in-memory matlab array
%
%   This class applies the logic for the ImageStackData to a matlab array.

%   Todo:
%    [ ] Implement varargin.

    properties
        DataArray   % Reference to the array in matlab's memory
    end
    
    methods % Constructor
        
        function obj = MatlabArray(dataArray, varargin)
            obj.DataArray = dataArray;
            
            obj.assignDataSize()
            obj.assignDataType()
            
            obj.setDefaultDataDimensionArrangement()
            obj.setDefaultStackDimensionArrangement()
        end
        
    end
    
    methods (Access = protected) % Implement abstract ImageStackData methods
        
        function assignDataSize(obj)
            obj.DataSize = size(obj.DataArray);
        end
           
        function assignDataType(obj)
            obj.DataType = class(obj.DataArray);
        end
        
        function data = getData(obj, subs)
        % Get data directly if indexing whole array
            if all(cellfun(@(s) isequal(s, ':'), subs))
                data = obj.DataArray;
            else
                data = obj.DataArray(subs{:});
            end
        end
        
        function setData(obj, subs, data)
        % Set data directly if indexing whole array
            if all(cellfun(@(s) isequal(s, ':'), subs))
                obj.DataArray = data;
            else
                obj.DataArray(subs{:}) = data;
            end
        end
        
    end
    
end