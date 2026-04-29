classdef PluginSpec
%PluginSpec Platform-neutral metadata for a NANSEN plugin.
%
%   Plugin specs are intentionally plain data objects. Specific plugin
%   registries may add fields to TypeData, but the top-level identity and
%   implementation fields should stay stable across plugin types.

    properties
        SchemaVersion char = '1.0'
        Id char = ''
        PluginType char = ''
        DisplayName char = ''
        Description char = ''
        Version char = ''
        Source char = ''
        SourcePath char = ''
        Provider struct = struct()
        Implementation struct = struct()
        Capabilities cell = {}
        TypeData struct = struct()
    end

    methods

        function obj = PluginSpec(S)
        %PluginSpec Construct spec from a struct, if provided.
            if nargin == 0 || isempty(S)
                return
            end

            obj = obj.assignFromStruct(S);
        end

        function S = struct(obj)
        %struct Convert plugin spec to a struct.
            S = struct();
            S.SchemaVersion = obj.SchemaVersion;
            S.Id = obj.Id;
            S.PluginType = obj.PluginType;
            S.DisplayName = obj.DisplayName;
            S.Description = obj.Description;
            S.Version = obj.Version;
            S.Source = obj.Source;
            S.SourcePath = obj.SourcePath;
            S.Provider = obj.Provider;
            S.Implementation = obj.Implementation;
            S.Capabilities = obj.Capabilities;
            S.TypeData = obj.TypeData;
        end

    end

    methods (Access = private)

        function obj = assignFromStruct(obj, S)
            propNames = properties(obj);
            inputNames = fieldnames(S);

            for i = 1:numel(inputNames)
                propName = obj.matchPropertyName(inputNames{i}, propNames);
                if ~isempty(propName)
                    obj.(propName) = S.(inputNames{i});
                end
            end
        end

    end

    methods (Static)

        function obj = fromJsonFile(filePath)
        %fromJsonFile Read a plugin spec from a JSON sidecar file.
            S = nansen.plugin.base.PluginSpec.readJsonFile(filePath);
            obj = nansen.plugin.base.PluginSpec.fromSidecarStruct(S, filePath);
        end

        function obj = fromSidecarStruct(S, sourcePath)
        %fromSidecarStruct Normalize sidecar JSON field names to PluginSpec.
            if nargin < 2
                sourcePath = '';
            end

            N = struct();
            N.SchemaVersion = nansen.plugin.base.PluginSpec.getField(S, ...
                {'schemaVersion', 'SchemaVersion'}, '1.0');
            N.Id = nansen.plugin.base.PluginSpec.getField(S, ...
                {'id', 'Id'}, '');
            N.PluginType = nansen.plugin.base.PluginSpec.getField(S, ...
                {'pluginType', 'PluginType'}, '');
            N.DisplayName = nansen.plugin.base.PluginSpec.getField(S, ...
                {'displayName', 'DisplayName', 'name', 'Name'}, '');
            N.Description = nansen.plugin.base.PluginSpec.getField(S, ...
                {'description', 'Description'}, '');
            N.Version = nansen.plugin.base.PluginSpec.getField(S, ...
                {'version', 'Version'}, '');
            N.Source = nansen.plugin.base.PluginSpec.getField(S, ...
                {'source', 'Source'}, '');
            N.SourcePath = sourcePath;
            N.Provider = nansen.plugin.base.PluginSpec.getField(S, ...
                {'provider', 'Provider'}, struct());
            N.Implementation = nansen.plugin.base.PluginSpec.getField(S, ...
                {'implementation', 'Implementation'}, struct());
            N.Capabilities = nansen.plugin.base.PluginSpec.getField(S, ...
                {'capabilities', 'Capabilities'}, {});
            N.TypeData = S;

            obj = nansen.plugin.base.PluginSpec(N);
        end

        function S = readJsonFile(filePath)
        %readJsonFile Decode JSON file into a struct.
            fid = fopen(filePath, 'r');
            if fid == -1
                error('Nansen:PluginSpec:FileOpenFailed', ...
                    'Could not open plugin sidecar "%s".', filePath)
            end
            cleanupObj = onCleanup(@() fclose(fid));
            jsonText = fread(fid, '*char')';
            S = jsondecode(jsonText);
        end

        function value = getField(S, fieldNames, defaultValue)
        %getField Get first matching field from a struct.
            value = defaultValue;

            if ischar(fieldNames)
                fieldNames = {fieldNames};
            end

            for i = 1:numel(fieldNames)
                if isfield(S, fieldNames{i})
                    value = S.(fieldNames{i});
                    return
                end
            end
        end

        function propName = matchPropertyName(inputName, propNames)
        %matchPropertyName Match property by exact or case-insensitive name.
            propName = '';
            isMatch = strcmp(propNames, inputName);
            if ~any(isMatch)
                isMatch = strcmpi(propNames, inputName);
            end

            if any(isMatch)
                propName = propNames{find(isMatch, 1, 'first')};
            end
        end

    end

end
