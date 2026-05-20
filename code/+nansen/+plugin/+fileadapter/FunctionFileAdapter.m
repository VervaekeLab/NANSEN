classdef FunctionFileAdapter < nansen.dataio.FileAdapter
%FunctionFileAdapter Runtime wrapper for sidecar-defined function adapters.
%
%   Implements nansen.dataio.FileAdapter on top of a FileAdapterSpec whose
%   implementation.kind is "function" or "function-set". Resolves read,
%   write, and view entry points from the spec's Implementation struct at
%   call time.
%
%   See also: nansen.plugin.fileadapter.FileAdapterSpec, nansen.dataio.FileAdapter

    properties (SetAccess = protected)
        DataType = 'N/A'
    end

    properties (Constant)
        Description = 'Function-based file adapter'
    end

    properties (Constant, Hidden, Access = protected)
        SUPPORTED_FILE_TYPES = {'*'}
    end

    properties (SetAccess = private)
        % Spec - Metadata for this adapter instance.
        Spec nansen.plugin.fileadapter.FileAdapterSpec
    end

    methods

        function obj = FunctionFileAdapter(filename, spec, varargin)
        %FunctionFileAdapter Construct an adapter from a file path and spec.
            arguments
                filename (1,1) string
                spec     (1,1) nansen.plugin.fileadapter.FileAdapterSpec
            end
            arguments (Repeating)
                varargin
            end
            obj@nansen.dataio.FileAdapter(filename, varargin{:})
            obj.Spec = spec;
        end

        function open(obj)
        %open Open or view the data.
            obj.view()
        end

        function view(obj)
        %view Invoke the sidecar view function if one is defined.
            viewFcn = obj.resolveImplementationFunction({'view', 'viewFunction'});
            if isempty(viewFcn)
                view@nansen.dataio.FileAdapter(obj)
                return
            end
            viewFcn(obj.Filename);
        end

    end

    methods (Access = protected)

        function data = readData(obj, varargin)
        %readData Invoke the sidecar read function.
            readFcn = obj.resolveImplementationFunction({'read', 'readFunction', 'entrypoint'});
            if isempty(readFcn)
                error('nansen:plugin:fileadapter:FunctionFileAdapter:ReadFunctionMissing', ...
                    'File adapter "%s" does not define a read function.', ...
                    obj.Spec.DisplayName)
            end
            data = readFcn(obj.Filename, varargin{:});
        end

        function writeData(obj, data, varargin)
        %writeData Invoke the sidecar write function if one is defined.
            writeFcn = obj.resolveImplementationFunction({'write', 'writeFunction'});
            if isempty(writeFcn)
                writeData@nansen.dataio.FileAdapter(obj, data, varargin{:})
                return
            end
            writeFcn(obj.Filename, data, varargin{:});
        end

    end

    methods (Access = private)

        function fcn = resolveImplementationFunction(obj, fieldNames)
        %resolveImplementationFunction Resolve a named function from the sidecar Implementation.
            fcn = [];
            implementation = obj.Spec.Implementation;

            if ischar(fieldNames)
                fieldNames = {fieldNames};
            end

            functionName = '';
            for i = 1:numel(fieldNames)
                if isfield(implementation, fieldNames{i})
                    functionName = implementation.(fieldNames{i});
                    break
                end
            end

            if isempty(functionName)
                return
            end

            % Relative .m paths are resolved relative to the sidecar's folder
            if endsWith(functionName, '.m')
                sidecarFolder = fileparts(obj.Spec.SourcePath);
                functionPath  = fullfile(sidecarFolder, functionName);
                functionName  = utility.path.abspath2funcname(functionPath);
            end

            fcn = str2func(functionName);
        end

    end

end
