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
    
    methods 
        function insertImageData(obj, imageData, insertInd)
            
            % Assume imageData should be inserted along last dimension
            
            stackSize = size(obj.DataArray);
            nDim = max([3, numel(stackSize)]);
            
            subs = repmat({':'}, 1, nDim);
            
            msg = 'Image can not be inserted into this stack because sizes does not match';
            assert( isequal(stackSize(1:nDim-1), size(imageData)), msg)
            
            if insertInd == 1
                obj.DataArray = cat(nDim, imageData, ...
                    obj.DataArray(subs{:}));
            else
                
                % Todo: Use insert into array function... Todo:
                [subsPre, subsPost] = deal(subs);
                subsPre{dim} = 1:insertInd(1)-1;
                subsPost{dim} = insertInd(1):subsPost{dim}(end);

                obj.DataArray = cat(dim, obj.DataArray(subsPre{:}), ...
                    imageData, obj.DataArray(subsPost{:}) );
            end
            
            obj.assignDataSize()
            
            % Temp fix of dimension orders if stack changes size.
            % (Should only happen if stack is 1 frame long and a new image
            % is added)
            if numel(stackSize) ~= ndims(obj.DataArray)
                if strcmp(obj.DataDimensionArrangement, 'YX')
                    obj.DataDimensionArrangement = 'YXT';
                end
            end
            
        end
        
        function removeImageData(obj, frameIdx)
            
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