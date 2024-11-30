classdef RoiArray < nansen.dataio.FileAdapter
%ROIARRAY Fileadapter for loading array of RoI objects
    
%   This class is very specific for getting a roi array. In most (all?)
%   cases it is better to use the roiGroup adapter.
%
    properties (Constant)
        DataType = 'RoI'
    end
    
    properties (Constant, Hidden, Access = protected)
        SUPPORTED_FILE_TYPES = {'mat'}
    end
    
    methods (Access = protected)
        
        function roiArray = readData(obj, varargin)
            
            % Todo: Check all variables in file, to see if any are of type
            % RoI or struct, and try to resolve...
            
            % Keep backwards compatibility (Todo: remove at some point):
            refVariableNames = {'roi_arr', 'RoiArray', 'roiArray'};
            varInfo = whos('-file', obj.Filename);
            varNames = {varInfo.name};

            refVariableNames = intersect(refVariableNames, varNames);
            if ~isempty(refVariableNames)
                varName = refVariableNames{1};
                S = load(obj.Filename, varName);
                roiArray = S.(varName);
                if numel(refVariableNames) > 1
                    warning('Multiple roi variables were detected in file, selected first one')
                end
            else
                error('This file does not contain a variable named roiArray');
            end
        end
        
        function writeData(obj, data, varargin)
        %writeData Write data to a roi array file.
        
            % Check that data is a roi array. Convert to struct if needed.
            if isa(data, 'RoI')
                data = roimanager.utilities.roiarray2struct(data);
            elseif isa(data, 'struct')
                requiredFields = {'uid', 'coordinates', 'pixelweights'};
                assert(all(ismember(requiredFields, fieldnames(data))), ...
                    'The provided struct does not have the required fields for a roi array')
            else
                error('Can not save data of type "%s" to a RoiArray file.', class(data))
            end
            
            S = struct;
            S.roiArray = data;
            
            % Use superclass method to write to mat...
            obj.writeDataToMat(S);
        end
    end
end
