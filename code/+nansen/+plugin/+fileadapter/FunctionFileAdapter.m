classdef FunctionFileAdapter < nansen.dataio.FileAdapter
%FunctionFileAdapter Runtime wrapper for sidecar-defined function adapters.

    properties (Constant)
        DataType = 'N/A'
        Description = 'Function-based file adapter'
    end

    properties (Constant, Hidden, Access = protected)
        SUPPORTED_FILE_TYPES = {'*'}
    end

    properties (SetAccess = private)
        Spec nansen.plugin.fileadapter.FileAdapterSpec
    end

    methods

        function obj = FunctionFileAdapter(filename, spec, varargin)
        %FunctionFileAdapter Construct adapter from file path and spec.
            obj@nansen.dataio.FileAdapter(filename, varargin{:})

            if nargin < 2
                error('Nansen:FunctionFileAdapter:SpecMissing', ...
                    'A FileAdapterSpec is required for function adapters.')
            end

            obj.Spec = spec;
        end

        function open(obj)
        %open Open or view data if a view function is defined.
            obj.view()
        end

        function view(obj)
        %view Invoke sidecar view function if available.
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
        %readData Invoke sidecar read function.
            readFcn = obj.resolveImplementationFunction({'read', 'readFunction', 'entrypoint'});
            if isempty(readFcn)
                error('Nansen:FunctionFileAdapter:ReadFunctionMissing', ...
                    'File adapter "%s" does not define a read function.', ...
                    obj.Spec.DisplayName)
            end

            data = readFcn(obj.Filename, varargin{:});
        end

        function writeData(obj, data, varargin)
        %writeData Invoke sidecar write function if available.
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
        %resolveImplementationFunction Resolve implementation function handle.
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

            if endsWith(functionName, '.m')
                sidecarFolder = fileparts(obj.Spec.SourcePath);
                functionPath = fullfile(sidecarFolder, functionName);
                functionName = utility.path.abspath2funcname(functionPath);
            end

            fcn = str2func(functionName);
        end

    end

end
