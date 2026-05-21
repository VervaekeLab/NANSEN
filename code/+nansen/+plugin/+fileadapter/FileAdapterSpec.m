classdef FileAdapterSpec < nansen.plugin.base.PluginSpec
%FileAdapterSpec Metadata for a NANSEN file adapter plugin.
%
%   Concrete PluginSpec subclass that adds file-adapter–specific typed
%   properties: the file extensions the adapter handles and the data type
%   it returns on load.
%
%   Sidecar JSON format (camelCase only):
%     schemaVersion   "1.0"
%     id              Stable plugin identifier
%     displayName     Human-readable name
%     implementation  { language, kind, entrypoint, class }
%     match           { extensions: [...] }
%     outputs         { dataType: "..." }
%
%   See also: nansen.plugin.base.PluginSpec, nansen.plugin.fileadapter.Registry

    properties (Constant)
        TYPE    = 'fileadapter'
        VERSION = '1.0'
        PluginType = nansen.plugin.enum.PluginType.FileAdapter
    end

    properties (Access = protected)
        RequiredProperties = ["Id", "DisplayName", "SupportedFileTypes", "DataType"]
    end

    properties
        % SupportedFileTypes - File extensions this adapter handles (no leading dot).
        SupportedFileTypes (1,:) string = string.empty

        % DataType - MATLAB class or type label returned by readData.
        DataType (1,1) string = ""

        % FileExpression - Optional glob pattern for finer file matching.
        FileExpression (1,1) string = ""

        % IsGeneral - True when this adapter accepts any file of the extension.
        IsGeneral (1,1) logical = false
    end

    methods

        function obj = FileAdapterSpec(options)
        %FileAdapterSpec Construct a file adapter spec from a property struct.
            arguments
                options (1,1) struct = struct
            end
            obj@nansen.plugin.base.PluginSpec(options)
        end

        function S = toStruct(obj)
        %toStruct Serialize to a flat camelCase struct matching the sidecar format.
            S = toStruct@nansen.plugin.base.PluginSpec(obj);
            S.match   = struct('extensions', cellstr(obj.SupportedFileTypes));
            S.outputs = struct('dataType',   char(obj.DataType));
        end

        function S = toLegacyStruct(obj)
        %toLegacyStruct Convert to the struct shape returned by nansen.dataio.listFileAdapters.
            S = struct( ...
                'AdapterId',          char(obj.Id), ...
                'DisplayName',        char(obj.DisplayName), ...
                'FileAdapterName',    char(obj.fileAdapterName_()), ...
                'FunctionName',       char(obj.functionName_()), ...
                'SupportedFileTypes', {cellstr(obj.SupportedFileTypes)}, ...
                'DataType',           char(obj.DataType), ...
                'SourcePath',         char(obj.SourcePath), ...
                'Implementation',     obj.Implementation);
        end

    end

    methods (Access = private)

        function name = fileAdapterName_(obj)
        %fileAdapterName_ Human-readable adapter name (DisplayName or Id fallback).
            name = obj.DisplayName;
            if strlength(name) == 0
                name = obj.Id;
            end
        end

        function name = functionName_(obj)
        %functionName_ MATLAB function name for constructing an adapter instance.
            kind = "";
            if isstruct(obj.Implementation) && isfield(obj.Implementation, 'kind')
                kind = string(obj.Implementation.kind);
            end
            switch lower(char(kind))
                case {'function', 'function-set'}
                    name = "nansen.plugin.fileadapter.FunctionFileAdapter";
                otherwise
                    if isstruct(obj.Implementation) && isfield(obj.Implementation, 'class')
                        name = string(obj.Implementation.class);
                    elseif isstruct(obj.Implementation) && isfield(obj.Implementation, 'entrypoint')
                        name = string(obj.Implementation.entrypoint);
                    else
                        name = "";
                    end
            end
        end

    end

    methods (Static)

        function specs = fromJsonFile(filePath)
        %fromJsonFile Read one or more FileAdapterSpecs from a sidecar file.
        %
        %   Handles both single-plugin sidecars and legacy grouped-array format
        %   (top-level "plugins" array). Always returns a typed array.
            S = nansen.plugin.base.PluginSpec.readJsonFile(filePath);
            if isfield(S, 'plugins')
                specs = nansen.plugin.fileadapter.FileAdapterSpec.empty;
                for i = 1:numel(S.plugins)
                    specs(end+1) = nansen.plugin.fileadapter.FileAdapterSpec.fromSidecarStruct( ...
                        S.plugins(i), filePath); %#ok<AGROW>
                end
            else
                specs = nansen.plugin.fileadapter.FileAdapterSpec.fromSidecarStruct(S, filePath);
            end
        end

        function spec = fromSidecarStruct(S, sourcePath)
        %fromSidecarStruct Build a FileAdapterSpec from a decoded sidecar struct.
            arguments
                S          (1,1) struct
                sourcePath (1,1) string = ""
            end

            opts = nansen.plugin.base.PluginSpec.parseBaseFields(S, sourcePath);

            % SupportedFileTypes from match.extensions or direct field
            if isfield(S, 'match') && isstruct(S.match) && isfield(S.match, 'extensions')
                opts.SupportedFileTypes = string(S.match.extensions(:)');
            elseif isfield(S, 'supportedFileTypes') && ~isempty(S.supportedFileTypes)
                opts.SupportedFileTypes = string(S.supportedFileTypes(:)');
            else
                opts.SupportedFileTypes = string.empty;
            end

            % DataType from outputs.dataType or direct field
            if isfield(S, 'outputs') && isstruct(S.outputs) && isfield(S.outputs, 'dataType')
                opts.DataType = string(S.outputs.dataType);
            elseif isfield(S, 'dataType')
                opts.DataType = string(S.dataType);
            else
                opts.DataType = "";
            end

            if isfield(S, 'fileExpression'); opts.FileExpression = string(S.fileExpression); end
            if isfield(S, 'isGeneral');      opts.IsGeneral      = logical(S.isGeneral);     end

            spec = nansen.plugin.fileadapter.FileAdapterSpec(opts);
        end

    end
end
