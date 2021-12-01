classdef ImageStackData < uim.mixin.assignProperties
%AbstractData Abstract wrapper for multi-dimensional image stack data
%
%
%   ABSTRACT METHODS
%       assignDataSize(obj)
%       assignDataType(obj)
%       getData(obj, subs)              % Get data specified by subs
%       setData(obj, data, subs)        % Set data specified by subs


%   TODO
%       [ ] Add reshape functionality, so that number of data dimensions
%           and number of stack dimensions can be different
%       
%       

% - - - - - - - - - - - - PROPERTIES - - - - - - - - - - - - - - - - - - - 

    properties (Constant, Hidden) % Default values and names for dimensions
        DEFAULT_DIMENSION_ARRANGEMENT = 'YXCZT'
        DIMENSION_NAMES = {'Height', 'Width', 'Channel', 'Plane', 'Time'}
    end
       
    properties (SetAccess = protected) % Size and type of original data
        DataSize                        % Length of each dimension of the original data array
        DataType                        % Data type for the original data array
    end
    
    properties % Specification of data dimension arrangement
        DataDimensionArrangement char   % Letter sequence describing the arrangement of dimensions in the data, i.e 'YXCT'
        StackDimensionArrangement char  % Letter sequence describing the arrangement of dimensions in the stack (output layer)
    end

    properties (SetAccess = private)
        StackSize                       % Length of each dimension according to the stack-centric dimension ordering
    end
    
    properties (Access = protected)
        DataDimensionOrder              % Numeric vector describing the order of dimensions in the data
        StackDimensionOrder             % Numeric vector describing the order of dimensions in the stack
    end
    
    
% - - - - - - - - - - - - - METHODS - - - - - - - - - - - - - - - - - - - 

    methods (Abstract, Access = protected) % ABSTRACT METHODS
        
        assignDataSize(obj)
        
        assignDataType(obj)
        
        getData(obj, subs)
        
        setData(obj, data, subs)
        
        data = getLinearizedData(obj)
    end
    
    methods (Sealed) % Override size, class, ndims, subsref & subsasgn
    % These methods should not be redefined in subclasses
    
        function varargout = size(obj, dim)
        %SIZE Implement size function to mimick array functionality.
        
            stackSize = obj.StackSize;
            
            % Return length of each dimension in a row vector
            if nargin == 1 && (nargout == 1 || ~nargout)
                varargout{1} = stackSize;
            
            % Return length of specified dimension, dim
            elseif nargin == 2 && (nargout == 1 || ~nargout)
                
                if numel(dim) > numel(stackSize)
                    stackSize(end+1:numel(dim)) = 1;
                    varargout{1} = stackSize;
                else
                    varargout{1} = stackSize(dim);
                end
                    
            % Return length of each dimension separately
            elseif nargin == 1 && nargout > 1
                varargout = cell(1, nargout);
                for i = 1:nargout
                    if i <= numel(stackSize)
                        varargout{i} = stackSize(i);
                    else
                        varargout{i} = 1;
                    end
                end
            end
            
        end
        
        function ndim = ndims(obj)
        %NDIMS Implement ndims function to mimick array functionality.
            ndim = numel(obj.DataSize);
        end
        
        function dataType = class(obj)
        %CLASS Implement class function to mimick array functionality.
            dataType = sprintf('%s (%s ImageStackData)', obj.DataType, obj.StackDimensionArrangement);
        end
                
        function varargout = subsref(obj, s, varargin)
            
            % Preallocate cell array of output.
            varargout = cell(1, nargout);

            switch s(1).type

                % Use builtin if a property/method is requested.
                case '.'
                    if nargout > 0
                        [varargout{:}] = builtin('subsref', obj, s);
                    else
                        try
                            varargout{1} = builtin('subsref', obj, s);
                        catch ME
                            switch ME.identifier
                                case {'MATLAB:TooManyOutputs', 'MATLAB:maxlhs'}
                                    try
                                        builtin('subsref', obj, s)
                                    catch ME
                                        throwAsCaller(ME)
                                    end
                                otherwise
                                    throwAsCaller(ME)
                            end
                        end
                    end
                    return
                    
                % Return image data if using ()-style referencing
                case '()'
                    
                    numRequestedDim = numel(s.subs);
                    
                    if isequal(s.subs, {':'})
                        varargout{1} = obj.getLinearizedData();
                        return
                    elseif numRequestedDim == ndims(obj)
                        subs = obj.rearrangeSubs(s.subs);
                    else
                        error('Requested number of dimensions does not match number of data dimensions')
                        % Todo: If there are too many dimensions in subs,
                        % it is fine if they are singletons. Same, if there
                        % are too few, treat the leftout dimensions as
                        % one.?
                    end
                    
                    % Todo: check that subs are not exceeding data/array bounds 
                    
                    
                    % Are any of these frames found in the cache?
%                     if false %obj.HasCachedData
%                         data = obj.getDataFromCache(subs);
%                     else
                    data = obj.getData(subs);
%                     end

%                     % Todo: Test this. Get cropped data if requested... 
%                     % Note: this should only be part of subclasses where
%                     whole images are read, i.e Tiff or Image
%                     data = data(subs{1:end-1}, ':');
                    
                    % Squeeze if possible
                    data = permute(data, obj.StackDimensionOrder);
                    
                    [varargout{:}] = data;

            end
        
        end
        
        function obj = subsasgn(obj, s, data)
                        
            switch s(1).type

                % Use builtin if a property is requested.
                case '.'
                    try
                        obj = builtin('subsasgn', obj, s, data);
                        return
                    catch ME
                        rethrow(ME)
                    end
                    
                % Set image data if using ()-style referencing
                case '()'
                
                    numRequestedDim = numel(s.subs);
                    
                    if numRequestedDim == ndims(obj)
                        subs = obj.rearrangeSubs(s.subs);
                    else
                        error('Indexing does not match stack size')
                    end

                    % permute data before adding...?
                    data = permute(data, obj.StackDimensionOrder);
                    obj.setData(subs, data)
            
            end
            
            
            if ~nargout
                clear obj
            end
            
        end
                
    end
    
    methods % Set methods for properties
        
        function set.DataSize(obj, newValue)
            obj.DataSize = newValue;
            obj.onDataSizeChanged()
        end
        
        function set.DataDimensionArrangement(obj, newValue)
            obj.validateDimensionArrangement(newValue)
            oldValue = obj.DataDimensionArrangement;
            
            if ~strcmp(newValue, oldValue)
                obj.DataDimensionArrangement = newValue;
                obj.onDataDimensionArrangementChanged(oldValue, newValue)
            end
        end
        
        function set.StackDimensionArrangement(obj, newValue)
            refValue = obj.DataDimensionArrangement; %#ok<MCSUP>
            obj.validateDimensionArrangement(newValue, refValue)
            
            obj.StackDimensionArrangement = newValue;
            obj.updateDimensionOrders()
        end
        
        function set.StackDimensionOrder(obj, newValue)
            obj.StackDimensionOrder = newValue;
            obj.onStackDimensionOrderChanged()
        end
        
    end
    
    methods (Access = protected) % Internal updating (change to private?)
        
        function setDefaultDataDimensionArrangement(obj)
        %setDefaultDataDimensionArrangement Assign default property value
        %
        %   Set data dimension arrangement based on default assumptions.
        
            % Return if data dimension arrangement is already set
            if ~isempty(obj.DataDimensionArrangement)
                return
            end
            
            % Count dimensions
            nDim = numel(obj.DataSize);

            % Single image frame
            if nDim == 2
                defaultDimensionArrangement = 'YX';

            % Assume a 3D array with 3 frames is a multichannel (RGB) image
            elseif nDim == 3 && obj.DataSize(3) == 3 
                defaultDimensionArrangement = 'YXC';

            % Assume a 3D array with N frames is a timeseries stack
            elseif nDim == 3 && obj.DataSize(3) ~= 3
                defaultDimensionArrangement = 'YXT';

            % Assume a 4D array is a multichannel timeseries stack
            elseif nDim == 4
                defaultDimensionArrangement = 'YXCT';

            % Assume a 5D array is a multichannel volumetric timeseries stack
            elseif nDim == 5
                defaultDimensionArrangement = 'YXCZT';
            end

            % Set the property value
            obj.DataDimensionArrangement = defaultDimensionArrangement;

        end
        
        function setDefaultStackDimensionArrangement(obj)
                
            % Return if stack/output dimension arrangement is already set
            if ~isempty(obj.StackDimensionArrangement)
                return
            end
            
            if isempty(obj.DataDimensionArrangement)
                return
            end

            % Find the dimensions that are present in the data, arranged in
            % the same order as the default dimension arrangement.
            C = intersect( obj.DEFAULT_DIMENSION_ARRANGEMENT, ...
                           obj.DataDimensionArrangement, 'stable' );
            
            % Set the property value
            obj.StackDimensionArrangement = C;
            
        end
        
        function onDataDimensionArrangementChanged(obj, oldValue, newValue)
            
            % Check if any dimensions were redefined
            if ~isempty(oldValue) && ~isempty(obj.StackDimensionArrangement)
                        
                oldDim = setdiff(oldValue, newValue);
                newDim = setdiff(newValue, oldValue);
                
                if numel(oldDim) == 1 && numel(newDim) == 1
                    % A data dimension was exchanged for another. Update
                    obj.StackDimensionArrangement = strrep(obj.StackDimensionArrangement, oldDim, newDim);
                elseif ~isempty(newDim) && isempty(oldDim)
                    % A data dimension was added
                    % Note: This assumes the dimension was added at the end
                    % I dont know if thats a valid assumption.
                    obj.StackDimensionArrangement = strcat(obj.StackDimensionArrangement, newDim);
                else
                    error('Something went wrong')
                end

            end
            
            obj.updateDimensionOrders()
            obj.StackSize = obj.DataSize(obj.StackDimensionOrder);
        end
        
        function updateDimensionOrders(obj)
            
            [Lia, Locb] = ismember(obj.StackDimensionArrangement, ...
                obj.DataDimensionArrangement);
            
            obj.StackDimensionOrder = Locb(Lia);
            
        end
        
        function subs = rearrangeSubs(obj, subs)
            subs = subs(obj.StackDimensionOrder);
        end
        
        function onDataSizeChanged(obj)
            obj.updateStackSize()
        end
        
        function onStackDimensionOrderChanged(obj)
            obj.updateStackSize()
        end
        
        function updateStackSize(obj)
            obj.StackSize = obj.DataSize(obj.StackDimensionOrder);
        end
        
    end
    
    methods (Static, Access = private)
        
        function validateDimensionArrangement(dimArrangement, refArrangement)
            
            % Check that dimension arrangement is a char
            msg1 = 'Dimension arrangement must be a character vector';
            assert(ischar(dimArrangement), msg1)
            
            % Check that dimension arrangement is compatible with defaults
            A = nansen.stack.data.abstract.ImageStackData.DEFAULT_DIMENSION_ARRANGEMENT;
            msg2 = sprintf('Dimension arrangement can only contain the letters %s', ...
                strjoin( arrayfun(@(c) sprintf('''%s''',c), A, 'uni', 0), ', ') );
            assert(all(ismember(dimArrangement, A)), msg2)
            
            % Check that the dimension arrangement is a permutation of
            % reference dimensions (if reference dimension are given)
            if nargin == 2 && ~isempty(refArrangement)
                isSameLength = numel(dimArrangement) == numel(refArrangement);
                isSameDims = isempty(setdiff(dimArrangement, refArrangement));

                msg3 = sprintf('Dimension arrangement must be a permutation of the reference dimensions: %s', refArrangement);
                assert(isSameLength && isSameDims, msg3)
            end
            
        end
        
    end
    
    methods (Static)
        
        function byteSize = getImageDataByteSize(imageSize, dataType)
            
            switch dataType
                case {'uint8', 'int8', 'logical'}
                    bytesPerPixel = 1;
                case {'uint16', 'int16'}
                    bytesPerPixel = 2;
                case {'uint32', 'int32', 'single'}
                    bytesPerPixel = 4;
                case {'uint64', 'int64', 'double'}
                    bytesPerPixel = 8;
            end
            
            byteSize = prod(imageSize) .* bytesPerPixel;
            
        end
        
        function limits = getImageIntensityLimits(dataType)
            
            switch dataType
                case 'uint8'
                    limits = [0, 2^8-1];
                case 'uint16'
                    limits = [0, 2^16-1];
                case 'uint32'
                    limits = [0, 2^32-1];
                case 'int8'
                    limits = [-2^7, 2^7-1];
                case 'int16'
                    limits = [-2^15, 2^15-1];
                case 'int32'
                    limits = [-2^31, 2^31-1];
                case {'single', 'double'}
                    limits = [0, 1];
            end
            
        end
        
    end
    
end
     