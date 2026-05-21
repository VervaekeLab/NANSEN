classdef ImviewerPluginSpec < nansen.plugin.base.PluginSpec
%ImviewerPluginSpec Metadata for a NANSEN imviewer plugin.
%
%   Concrete PluginSpec subclass that adds imviewer-specific typed
%   properties: menu placement, icon, and an optional keyboard shortcut.
%
%   Sidecar JSON format (camelCase only):
%     schemaVersion   "1.0"
%     id              Stable plugin identifier (full class name)
%     displayName     Human-readable label (from AppPlugin.Name)
%     implementation  { language, kind, entrypoint }
%     menuLocation    [string, ...]   (optional, empty → root level)
%     iconName        ""              (optional)
%     shortcutKey     ""              (optional)
%
%   See also: nansen.plugin.base.PluginSpec, nansen.plugin.imviewer.Registry

    properties (Constant)
        TYPE    = 'imviewer'
        VERSION = '1.0'
        PluginType = nansen.plugin.enum.PluginType.ImviewerPlugin
    end

    properties (Access = protected)
        RequiredProperties = ["Id", "DisplayName"]
    end

    properties
        % MenuLocation - Ordered segments giving the submenu path for this plugin.
        %   Empty means the plugin is placed directly in the top-level plugin section.
        MenuLocation (1,:) string = string.empty

        % IconName - Optional icon identifier used by the toolbar button.
        IconName (1,1) string = ""

        % ShortcutKey - Optional keyboard shortcut key character.
        ShortcutKey (1,1) string = ""
    end

    methods

        function obj = ImviewerPluginSpec(options)
        %ImviewerPluginSpec Construct an imviewer plugin spec from a property struct.
            arguments
                options (1,1) struct = struct
            end
            obj@nansen.plugin.base.PluginSpec(options)
        end

        function S = toStruct(obj)
        %toStruct Serialize to a flat camelCase struct matching the sidecar format.
            S = toStruct@nansen.plugin.base.PluginSpec(obj);
            S.menuLocation = cellstr(obj.MenuLocation);
            S.iconName     = char(obj.IconName);
            S.shortcutKey  = char(obj.ShortcutKey);
        end

        function fcn = toFunctionHandle(obj)
        %toFunctionHandle Return a constructor function handle for this plugin.
            entrypoint = obj.resolveEntrypoint_();
            if isempty(entrypoint)
                error('nansen:plugin:imviewer:ImviewerPluginSpec:MissingEntrypoint', ...
                    'Plugin "%s" has no entrypoint in Implementation.', char(obj.Id))
            end
            fcn = str2func(entrypoint);
        end

    end

    methods (Static)

        function specs = fromJsonFile(filePath)
        %fromJsonFile Read one or more ImviewerPluginSpecs from a sidecar JSON file.
            S = nansen.plugin.base.PluginSpec.readJsonFile(filePath);
            if isfield(S, 'plugins')
                specs = nansen.plugin.imviewer.ImviewerPluginSpec.empty;
                for i = 1:numel(S.plugins)
                    specs(end+1) = nansen.plugin.imviewer.ImviewerPluginSpec.fromSidecarStruct( ...
                        S.plugins(i), filePath); %#ok<AGROW>
                end
            else
                specs = nansen.plugin.imviewer.ImviewerPluginSpec.fromSidecarStruct(S, filePath);
            end
        end

        function spec = fromSidecarStruct(S, sourcePath)
        %fromSidecarStruct Build an ImviewerPluginSpec from a decoded sidecar struct.
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

            if isfield(S, 'menuLocation') && ~isempty(S.menuLocation)
                opts.MenuLocation = string(S.menuLocation(:)');
            end
            if isfield(S, 'iconName') && ~isempty(S.iconName)
                opts.IconName = string(S.iconName);
            end
            if isfield(S, 'shortcutKey') && ~isempty(S.shortcutKey)
                opts.ShortcutKey = string(S.shortcutKey);
            end

            spec = nansen.plugin.imviewer.ImviewerPluginSpec(opts);
        end

    end

    methods (Access = private)

        function name = resolveEntrypoint_(obj)
        %resolveEntrypoint_ Return the MATLAB callable name from Implementation.
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

end
