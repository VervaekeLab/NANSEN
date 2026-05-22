classdef (Abstract) PluginSpec < nansen.common.abstract.Specification
%PluginSpec Abstract base class for NANSEN plugin metadata.
%
%   Each plugin type subclasses PluginSpec to define its own typed
%   properties and required fields. The base provides common identity
%   fields, camelCase JSON serialization, and schema validation.
%
%   Subclasses must implement:
%     - Constant TYPE    — string label, e.g. 'fileadapter'
%     - Constant VERSION — schema version, e.g. '1.0'
%     - Constant PluginType (nansen.plugin.enum.PluginType)
%     - Protected property RequiredProperties (1,:) string
%     - Static fromJsonFile(filePath) → spec array
%     - Static fromSidecarStruct(S, sourcePath) → spec instance

    properties (Abstract, Constant)
        PluginType (1,1) nansen.plugin.enum.PluginType
    end

    properties
        Id          (1,1) string = missing
        DisplayName (1,1) string = missing
        Description (1,1) string = ""
        PluginVersion (1,1) string = ""
        Source      (1,1) string = ""
        SourcePath  (1,1) string = ""
        Provider    (1,1) struct = struct()
        Implementation (1,1) struct = struct()
        Capabilities   (1,:) string = string.empty
    end

    methods
        function obj = PluginSpec(options)
        %PluginSpec Construct a plugin spec from a property-name struct.
            arguments
                options (1,1) struct = struct
            end
            obj@nansen.common.abstract.Specification(options)
        end

        function S = toStruct(obj)
        %toStruct Serialize to a flat camelCase struct matching sidecar format.
        %
        %   Overrides Specification.toStruct to produce the flat camelCase JSON
        %   used by sidecar files rather than the tagged envelope format.
            S = struct();
            S.schemaVersion  = obj.VERSION;
            S.id             = obj.Id;
            S.pluginType     = lower(char(obj.PluginType));
            S.displayName    = obj.DisplayName;
            S.description    = obj.Description;
            S.version        = obj.PluginVersion;
            S.source         = obj.Source;
            S.sourcePath     = obj.SourcePath;
            S.provider       = obj.Provider;
            S.implementation = obj.Implementation;
            if isempty(obj.Capabilities)
                S.capabilities = {};
            else
                S.capabilities = cellstr(obj.Capabilities);
            end
        end
    end

    methods (Access = protected)
        function name = resolveEntrypoint(obj)
        %resolveEntrypoint Return the MATLAB callable name from Implementation.
        %
        %   Checks Implementation.entrypoint, then .class, then falls back to Id.
            name = '';
            if ~isstruct(obj.Implementation); return; end
            if isfield(obj.Implementation, 'entrypoint')
                name = char(string(obj.Implementation.entrypoint));
            elseif isfield(obj.Implementation, 'class')
                name = char(string(obj.Implementation.class));
            else
                name = char(obj.Id);
            end
        end
    end

    methods (Static, Access = protected)
        function S = readJsonFile(filePath)
        %readJsonFile Decode a JSON sidecar file into a struct.
            S = jsondecode(fileread(filePath));
        end

        function opts = parseBaseFields(S, sourcePath)
        %parseBaseFields Extract common PluginSpec fields from a sidecar struct.
        %
        %   Returns an opts struct with all base fields populated. Concrete
        %   fromSidecarStruct implementations call this first, then add their
        %   type-specific fields.
            arguments
                S          (1,1) struct
                sourcePath (1,1) string = ""
            end
            opts = struct();
            if isfield(S, 'id');             opts.Id             = string(S.id);          end
            if isfield(S, 'displayName');    opts.DisplayName    = string(S.displayName); end
            if isfield(S, 'description');    opts.Description    = string(S.description); end
            if isfield(S, 'version');        opts.PluginVersion  = string(S.version);     end
            if isfield(S, 'source');         opts.Source         = string(S.source);      end
            if isfield(S, 'provider');       opts.Provider       = S.provider;            end
            if isfield(S, 'implementation'); opts.Implementation = S.implementation;      end
            if isfield(S, 'capabilities') && ~isempty(S.capabilities)
                opts.Capabilities = string(S.capabilities);
            end
            opts.SourcePath = sourcePath;
        end
    end

    methods (Static)
        function issues = validateSidecarFields(S)
        %validateSidecarFields Check JSON struct for schema conformance.
        %
        %   Returns a struct array with Severity, Message, and Field fields.
        %   Validates: camelCase key naming, schemaVersion, implementation.kind.
            issues = struct('Severity', {}, 'Message', {}, 'Field', {});
            if ~isstruct(S)
                return
            end

            allowedKinds = {'class', 'function', 'function-set', 'builtin', 'script'};

            for f = fieldnames(S)'
                name = f{1};
                if ~isempty(name) && (name(1) < 'a' || name(1) > 'z')
                    issues(end+1) = struct( ...          %#ok<AGROW>
                        'Severity', 'warning', ...
                        'Message',  sprintf('Field "%s" uses PascalCase; camelCase is required.', name), ...
                        'Field',    name);
                end
            end

            if isfield(S, 'schemaVersion') && ~strcmp(S.schemaVersion, '1.0')
                issues(end+1) = struct( ...
                    'Severity', 'warning', ...
                    'Message',  sprintf('Unknown schemaVersion "%s".', S.schemaVersion), ...
                    'Field',    'schemaVersion');
            end

            if isfield(S, 'implementation') && isstruct(S.implementation) ...
                    && isfield(S.implementation, 'kind')
                kind = lower(S.implementation.kind);
                if ~ismember(kind, allowedKinds)
                    issues(end+1) = struct( ...
                        'Severity', 'error', ...
                        'Message',  sprintf('Unknown implementation.kind "%s".', S.implementation.kind), ...
                        'Field',    'implementation.kind');
                end
            end
        end
    end
end
