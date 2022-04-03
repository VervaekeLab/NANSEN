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
            
            obj.MetaData = nansen.stack.metadata.StackMetadata();
            
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
            
            subs = arrayfun(@(l) 1:l, stackSize, 'uni', 0);
            
            msg = 'Image can not be inserted into this stack because sizes does not match';
            assert( isequal(stackSize(1:nDim-1), size(imageData)), msg)
            
            if insertInd == 1
                obj.DataArray = cat(nDim, imageData, ...
                    obj.DataArray(subs{:}));
            else
                
                % Todo: Use insert into array function... Todo:
                [subsPre, subsPost] = deal(subs);
                subsPre{nDim} = 1:insertInd(1)-1;
                subsPost{nDim} = insertInd(1):subsPost{nDim}(end);

                obj.DataArray = cat(nDim, obj.DataArray(subsPre{:}), ...
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
                data = obj.DataArray; % Quicker than subsindexing
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
        
        function data = getLinearizedData(obj)
            data = obj.DataArray(:);
        end
        
    end
    
    methods % Implementation of matlab functions
        
        function varargout = max(obj, varargin)
            
            if nargout == 0
                max(obj.DataArray, varargin{:})
            else
                varargout = cell(1, nargout);
                [varargout{:}] = max(obj.DataArray, varargin{:});
            end
        end
        
        
    end
        
    
end