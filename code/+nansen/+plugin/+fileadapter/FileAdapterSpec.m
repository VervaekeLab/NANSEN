classdef FileAdapterSpec < nansen.plugin.base.PluginSpec
%FileAdapterSpec Metadata for a file adapter plugin.

    properties (Dependent)
        SupportedFileTypes
        DataType
        FunctionName
        FileAdapterName
    end

    methods

        function obj = FileAdapterSpec(S)
            if nargin == 0
                S = struct();
            end

            obj@nansen.plugin.base.PluginSpec(S);
            obj.PluginType = 'fileadapter';
        end

        function value = get.SupportedFileTypes(obj)
            value = nansen.plugin.fileadapter.FileAdapterSpec.getTypeField( ...
                obj.TypeData, {'SupportedFileTypes', 'extensions'}, {});
            if isempty(value) && isfield(obj.TypeData, 'match') && ...
                    isfield(obj.TypeData.match, 'extensions')
                value = obj.TypeData.match.extensions;
            end
            value = nansen.plugin.fileadapter.FileAdapterSpec.normalizeFileTypes(value);
        end

        function value = get.DataType(obj)
            value = nansen.plugin.fileadapter.FileAdapterSpec.getTypeField( ...
                obj.TypeData, {'DataType', 'dataType'}, '');
            if isempty(value) && isfield(obj.TypeData, 'outputs') && ...
                    isfield(obj.TypeData.outputs, 'dataType')
                value = obj.TypeData.outputs.dataType;
            end
        end

        function value = get.FunctionName(obj)
            kind = nansen.plugin.fileadapter.FileAdapterSpec.getImplementationField( ...
                obj.Implementation, {'kind'}, '');

            switch lower(kind)
                case {'function', 'function-set'}
                    value = 'nansen.plugin.fileadapter.FunctionFileAdapter';
                otherwise
                    value = nansen.plugin.fileadapter.FileAdapterSpec.getImplementationField( ...
                        obj.Implementation, {'class', 'entrypoint'}, '');
                    if isempty(value)
                        value = nansen.plugin.fileadapter.FileAdapterSpec.getImplementationField( ...
                            obj.Implementation, {'read', 'readFunction'}, '');
                    end
            end
        end

        function value = get.FileAdapterName(obj)
            value = obj.DisplayName;
            if isempty(value)
                value = obj.Id;
            end
        end

        function S = toLegacyStruct(obj)
        %toLegacyStruct Convert to nansen.dataio.listFileAdapters shape.
            S = struct( ...
                'AdapterId', obj.Id, ...
                'DisplayName', obj.DisplayName, ...
                'FileAdapterName', obj.FileAdapterName, ...
                'FunctionName', obj.FunctionName, ...
                'SupportedFileTypes', {obj.SupportedFileTypes}, ...
                'DataType', obj.DataType, ...
                'SourcePath', obj.SourcePath, ...
                'Implementation', obj.Implementation);
        end

    end

    methods (Static)

        function spec = fromPluginSpec(pluginSpec)
        %fromPluginSpec Convert base PluginSpec to FileAdapterSpec.
            spec = nansen.plugin.fileadapter.FileAdapterSpec(pluginSpec.struct());
            spec.TypeData = pluginSpec.TypeData;
        end

        function fileTypes = normalizeFileTypes(fileTypes)
        %normalizeFileTypes Normalize extension strings for comparisons.
            if ischar(fileTypes)
                fileTypes = {fileTypes};
            elseif isstring(fileTypes)
                fileTypes = cellstr(fileTypes);
            end

            fileTypes = cellfun(@(s) lower(strrep(char(s), '.', '')), ...
                fileTypes, 'UniformOutput', false);
        end

    end

    methods (Static, Access = private)

        function value = getTypeField(S, names, defaultValue)
            value = nansen.plugin.base.PluginSpec.getField(S, names, defaultValue);
        end

        function value = getImplementationField(S, names, defaultValue)
            value = nansen.plugin.base.PluginSpec.getField(S, names, defaultValue);
        end

    end

end
