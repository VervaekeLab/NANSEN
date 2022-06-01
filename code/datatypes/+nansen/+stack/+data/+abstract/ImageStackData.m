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
%           - i.e data dimension is : YXN and stack dimension is YX[CT]
%           - Use Deinterleaver class...

%       [ ] Should both DataDimensionArrangement and
%           StackDimensionArrangement be added to metadata?


% - - - - - - - - - - - - PROPERTIES - - - - - - - - - - - - - - - - - - - 

    properties (Constant, Hidden) % Default values and names for dimensions
        DEFAULT_DIMENSION_ARRANGEMENT = 'YXCZT'
        DIMENSION_NAMES = {'Height', 'Width', 'Channel', 'Plane', 'Time'}
    end
       
    properties (SetAccess = protected) % Size and type of original data
        MetaData nansen.stack.metadata.StackMetadata
        DataSize                        % Length of each dimension of the original data array
        DataType                        % Data type for the original data array
    end
    
    properties % Specification of data dimension arrangement
        DataDimensionArrangement char   % Letter sequence describing the arrangement of dimensions in the data (input layer), i.e 'YXCT'
        StackDimensionArrangement char  % Letter sequence describing the arrangement of dimensions in the stack (output layer)
    end

    properties (SetAccess = private)
        StackSize                       % Length of each dimension according to the stack-centric dimension ordering
    end
    
    properties (GetAccess = protected, SetAccess = private)
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
                
                if max(dim) > numel(stackSize)
                    stackSize(end+1:max(dim)) = 1;
                end
                
                varargout{1} = stackSize(dim);
                
            % Make sure the number of dimensions requested matches the
            % number of outputs requested
            elseif nargin >= 2 && nargout > 1
                msg = 'Incorrect number of output arguments. Number of output arguments must equal the number of input dimension arguments.';
                assert(numel(dim) == nargout, msg)
                
                varargout = cell(1, nargout);
                for i = 1:numel(dim)
                    varargout{i} = stackSize(dim(i));
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
            
            %ndim = numel(obj.DataSize);
            % Use dataDimensionArrangement instead because trailing
            % singleton dimensions are automatically removed, and in some
            % cases the stack will have a singleton dimension as the
            % last dimension:
            ndim = numel(obj.DataDimensionArrangement);
        end
        
        function dataType = class(obj)
        %CLASS Implement class function to mimick array functionality.
            dataType = sprintf('%s (%s ImageStackData)', obj.DataType, obj.StackDimensionArrangement);
        end
                
        function varargout = subsref(obj, s, varargin)
            
            % Preallocate cell array of output.
            varargout = cell(1, nargout);
            
            % Todo: use numArgumentsFromSubscript instead of try catch
            % blocks below.

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
                    elseif numRequestedDim == 1
                        % todo:
                        [subs{1:ndims(obj)}] = ind2sub(obj.DataSize, s.subs{1});
                    else
                        error('Requested number of dimensions does not match number of data dimensions')
                        % Todo: If there are too many dimensions in subs,
                        % it is fine if they are singletons. Same, if there
                        % are too few, treat the leftout dimensions as
                        % one.?
                    end
                    
                    % Todo: check that subs are not exceeding data/array bounds 
                    % obj.validateSubs() % Todo: make this method...
                    
                    data = obj.getData(subs);
                    
                    % Permute data according to the stack dimension order
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

                    % Permute data according to the stack dimension order
                    data = permute(data, obj.StackDimensionOrder);
                    obj.setData(subs, data)
            end
            
            if ~nargout
                clear obj
            end
        end
        
        function name = getDataAdapterClass(obj)
            fullClassName = builtin('class', obj);
            splitClassName = strsplit(fullClassName, '.');
            name = splitClassName{end};
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
            obj.updateStackDimensionOrder()
            obj.updateStackSize()
        end
        
        function set.StackDimensionOrder(obj, newValue)
            obj.StackDimensionOrder = newValue;
            obj.onStackDimensionOrderChanged()
        end
        
    end
    
    methods
        function enablePreprocessing(~)
            % Subclasses may override
        end
        function disablePreprocessing(~)
            % Subclasses may override
        end
    end
    
    methods (Access = protected) % Internal updating (change to private?) onDataSizeChanged must be protected...
        
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
            
            obj.MetaData.DimensionArrangement = obj.DataDimensionArrangement;
                        
            % If the last dimension has length 1, matlab automatically
            % squeezes, but its important that the last dimension is
            % represented in DataSize, even if it has length 1
            if numel(obj.DataSize) < numel(obj.DataDimensionArrangement)
                nDims = numel(obj.DataDimensionArrangement);
                obj.DataSize(nDims) = 1;
                obj.DataSize(obj.DataSize==0) = 1;             
            end

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
                    % Todo: This need more development for special cases
                    obj.StackDimensionArrangement = strcat(obj.StackDimensionArrangement, newDim);
                elseif isempty(newDim) && isempty(oldDim)
                    % Data dimensions were rearranged
                    obj.StackDimensionArrangement = newValue;
                else
                    error('Something went wrong')
                end
            end
            
            % If data dimension arrangement is set on construction
            if isempty(obj.StackDimensionOrder); return; end
            
            % Todo: Remove (these should be redundant since there is a
            % callback when the StackDimensionArrangement is set.
            stackDimensionOrderPre = obj.StackDimensionOrder;
            obj.updateStackDimensionOrder()
            if ~isequal(stackDimensionOrderPre, obj.StackDimensionOrder)
                error('Unexpected behavior. Debug/report!')
            end
            % Todo: remove. This is also redundant 
            %obj.updateStackSize();
        end
        
        function updateStackDimensionOrder(obj)
        %updateStackDimensionOrder Update the StackDimensionOrder property
        %
        %   Update the StackDimensionOrder to reflect the mapping from
        %   DataDimensionArrangement to StackDimensionArrangement
        
            [Lia, Locb] = ismember(obj.StackDimensionArrangement, ...
                obj.DataDimensionArrangement);
            
            obj.StackDimensionOrder = Locb(Lia);
            
            %obj.MetaData.DimensionArrangement = obj.StackDimensionArrangement;
        end
        
        function dim = getDataDimensionNumber(obj, dimensionName)
            dim = strfind(obj.DataDimensionArrangement, dimensionName);
        end
        
        function dimLength = getDimLength(obj, dimensionName)
        %getDimLength Get length of dimension given by letter
        %
        %   dimLength = getDimLength(obj, dimensionName) where
        %   dimensionName is 'X', 'Y', 'C', 'Z' or 'T'.
        
            ind = obj.getDataDimensionNumber(dimensionName);
            
            if isempty(ind)
                dimLength = 1;
            elseif ind > numel(obj.DataSize)
                dimLength = 1;
            else
                dimLength = obj.DataSize(ind);
            end
        end
        
        function dim = getFrameIndexingDimension(obj)
            
            if contains(obj.DataDimensionArrangement, 'Z')
                if contains(obj.DataDimensionArrangement, 'T')
                    dim = strfind(obj.DataDimensionArrangement, 'T');
                else
                    dim = strfind(obj.DataDimensionArrangement, 'Z');
                end
            else
                dim = strfind(obj.DataDimensionArrangement, 'T');
            end
            
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
        %updateStackSize Update StackSize based on StackDimensionArrangement
        
            % Since Matlab squeezes singleton dimensions if they are at the
            % end of an array, it might occur that the StackDimensionOrder
            % has more elements than the DataSize. Make sure this does not
            % case an error:
            nd = numel(obj.DataSize);
            if numel(obj.StackDimensionOrder) > nd
                obj.StackSize = obj.DataSize(obj.StackDimensionOrder(1:nd));
            else 
                obj.StackSize = obj.DataSize(obj.StackDimensionOrder);
            end
        end
        
    end
    
    methods (Static, Access = private)
        
        function validateDimensionArrangement(dimArrangement, refArrangement)
            
            % Check that dimension arrangement is a char
            msg1 = 'Dimension arrangement must be a character vector';
            assert(ischar(dimArrangement), msg1)
            
            % Check that dimension arrangement is compatible with defaults
            A = nansen.stack.data.abstract.ImageStackData.DEFAULT_DIMENSION_ARRANGEMENT;
            
            if ~all( ismember(dimArrangement, A) )
                msg2 = sprintf('Dimension arrangement can only contain the letters %s', ...
                strjoin( arrayfun(@(c) sprintf('''%s''',c), A, 'uni', 0), ', ') );
                error('Nansen:ImageStackData:WrongDimensionLetter', msg2) %#ok<SPERR>
            end
            
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
     