classdef RoiGroupStruct < nansen.dataio.FileAdapter
    
    properties (Constant)
        DataType = 'struct'
    end
    
    properties (Constant, Hidden, Access = protected)
        SUPPORTED_FILE_TYPES = {'mat'}
    end
    


    methods (Access = protected)
        
        function roiGroup = readData(obj, varargin)

            S = load(obj.Filename);
            
            if isfield(S, 'roiArray') && iscell(S.roiArray)
                roiGroup = obj.makeNonScalarStruct(S);
            else
                error('...')
            end
        end
    end

    methods (Static)

        function nonScalarStruct = makeNonScalarStruct(scalarStruct)
            fieldNames = fieldnames(scalarStruct);
            fieldValues = struct2cell(scalarStruct);

            fieldValuePairs = [fieldNames'; fieldValues'];
            nonScalarStruct = struct(fieldValuePairs{:});
        end

    end
end
