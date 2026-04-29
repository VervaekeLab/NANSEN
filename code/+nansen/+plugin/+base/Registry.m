classdef (Abstract) Registry < handle
%Registry Base class for discovering and caching plugin specs.
%
%   Subclasses define plugin type, roots, sidecar naming and compatibility
%   importers. The base class keeps the registry lifecycle consistent.

    properties (SetAccess = private)
        Specs = nansen.plugin.base.PluginSpec.empty
        Issues = struct('Severity', {}, 'Message', {}, 'SourcePath', {})
        IsLoaded = false
    end

    methods

        function specs = list(obj, varargin)
        %list Return plugin specs, refreshing on first use.
            [includeDisabled, varargin] = obj.parseListOptions(varargin{:});

            if ~obj.IsLoaded
                obj.refresh()
            end

            specs = obj.Specs;

            if ~includeDisabled
                specs = obj.removeDisabledSpecs(specs);
            end

            if ~isempty(varargin)
                specs = obj.filterSpecs(specs, varargin{:});
            end
        end

        function refresh(obj)
        %refresh Rebuild specs and validation issues from all sources.
            obj.Issues = obj.getEmptyIssues();
            specs = obj.emptySpecArray();

            sidecarSpecs = obj.discoverSidecarSpecs();
            compatibilitySpecs = obj.discoverCompatibilitySpecs();

            specs = [specs, sidecarSpecs, compatibilitySpecs];
            [specs, issues] = obj.postprocessSpecs(specs);

            obj.Specs = specs;
            obj.Issues = [obj.Issues, issues];
            obj.IsLoaded = true;
        end

        function clear(obj)
        %clear Clear cached specs so the next list call refreshes.
            obj.Specs = obj.emptySpecArray();
            obj.Issues = obj.getEmptyIssues();
            obj.IsLoaded = false;
        end

        function spec = get(obj, pluginId)
        %get Return the resolved spec by stable id or display name.
            spec = obj.resolve(pluginId);
        end

        function spec = resolve(obj, pluginId, varargin)
        %resolve Return the highest-priority matching plugin spec.
            [includeDisabled, varargin] = obj.parseListOptions(varargin{:});
            specs = obj.list('IncludeDisabled', includeDisabled);
            if ~isempty(varargin)
                specs = obj.filterSpecs(specs, varargin{:});
            end

            if isempty(specs)
                error('Nansen:PluginRegistry:PluginNotFound', ...
                    'Plugin "%s" was not found.', pluginId)
            end

            isMatch = strcmp({specs.Id}, pluginId) | ...
                strcmp({specs.DisplayName}, pluginId);

            if ~any(isMatch)
                error('Nansen:PluginRegistry:PluginNotFound', ...
                    'Plugin "%s" was not found.', pluginId)
            end

            spec = specs(find(isMatch, 1, 'first'));
        end

        function disable(obj, pluginId)
        %disable Disable a plugin by stable id.
            specs = obj.list('IncludeDisabled', true);
            isMatch = strcmp({specs.Id}, pluginId) | ...
                strcmp({specs.DisplayName}, pluginId);

            if ~any(isMatch)
                error('Nansen:PluginRegistry:PluginNotFound', ...
                    'Plugin "%s" was not found.', pluginId)
            end

            pluginId = specs(find(isMatch, 1, 'first')).Id;
            disabledIds = obj.getDisabledPluginIds();
            if ~any(strcmp(disabledIds, pluginId))
                disabledIds{end+1} = pluginId;
                obj.setDisabledPluginIds(disabledIds)
            end
        end

        function enable(obj, pluginId)
        %enable Enable a plugin by stable id.
            disabledIds = obj.getDisabledPluginIds();
            keep = ~strcmp(disabledIds, pluginId);
            obj.setDisabledPluginIds(disabledIds(keep))
        end

        function tf = isEnabled(obj, pluginId)
        %isEnabled Return true if a plugin id is not disabled.
            disabledIds = obj.getDisabledPluginIds();
            tf = ~any(strcmp(disabledIds, pluginId));
        end

        function report = validate(obj)
        %validate Return discovery and validation issues.
            if ~obj.IsLoaded
                obj.refresh()
            end

            report = obj.Issues;
        end

    end

    methods (Access = protected)

        function specs = discoverSidecarSpecs(obj)
        %discoverSidecarSpecs Read all sidecar specs for this registry.
            specs = obj.emptySpecArray();
            sidecarFiles = obj.listSidecarFiles();

            for i = 1:numel(sidecarFiles)
                try
                    spec = obj.readSidecarSpec(sidecarFiles{i});
                    if isempty(spec.PluginType)
                        spec.PluginType = obj.PluginType;
                    end
                    specs(end+1) = spec; %#ok<AGROW>
                catch ME
                    obj.addIssue('error', ME.message, sidecarFiles{i});
                end
            end
        end

        function specs = discoverCompatibilitySpecs(obj)
        %discoverCompatibilitySpecs Hook for legacy class/function plugins.
            specs = obj.emptySpecArray();
        end

        function spec = readSidecarSpec(~, filePath)
        %readSidecarSpec Read a sidecar file into a PluginSpec.
            spec = nansen.plugin.base.PluginSpec.fromJsonFile(filePath);
        end

        function sidecarFiles = listSidecarFiles(obj)
        %listSidecarFiles Find sidecar files matching this registry's name.
            roots = obj.getRootPaths();
            sidecarFiles = {};

            if isempty(roots)
                return
            end

            if ~iscell(roots)
                roots = {roots};
            end

            for i = 1:numel(roots)
                if ~isfolder(roots{i})
                    continue
                end

                L = dir(fullfile(roots{i}, '**', obj.SidecarFilename));
                sidecarFiles = [sidecarFiles, fullfile({L.folder}, {L.name})]; %#ok<AGROW>
            end
        end

        function [specs, issues] = postprocessSpecs(obj, specs)
        %postprocessSpecs Normalize, validate and de-duplicate specs.
            issues = obj.getEmptyIssues();

            for i = 1:numel(specs)
                specs(i) = obj.normalizeSpec(specs(i));
            end

            specs = obj.sortSpecsByPriority(specs);
            ids = {specs.Id};
            missingId = cellfun(@isempty, ids);
            for i = find(missingId)
                issues(end+1) = obj.makeIssue('error', ...
                    'Plugin spec is missing a stable id.', specs(i).SourcePath); %#ok<AGROW>
            end

            duplicateIds = unique(ids(~missingId));
            for i = 1:numel(duplicateIds)
                if sum(strcmp(ids, duplicateIds{i})) > 1
                    issues(end+1) = obj.makeIssue('warning', ...
                        sprintf(['Duplicate plugin id "%s". The first ', ...
                        'entry by registry precedence will be used.'], ...
                        duplicateIds{i}), ''); %#ok<AGROW>
                end
            end
        end

        function spec = normalizeSpec(obj, spec)
        %normalizeSpec Fill common defaults.
            if isempty(spec.PluginType)
                spec.PluginType = obj.PluginType;
            end
        end

        function specs = emptySpecArray(~)
        %emptySpecArray Return an empty spec array for this registry.
            specs = nansen.plugin.base.PluginSpec.empty;
        end

        function specs = filterSpecs(~, specs, varargin)
        %filterSpecs Apply simple name-value filters to specs.
            for i = 1:2:numel(varargin)
                fieldName = varargin{i};
                expectedValue = varargin{i+1};

                keep = false(1, numel(specs));
                for j = 1:numel(specs)
                    if isprop(specs(j), fieldName)
                        keep(j) = isequal(specs(j).(fieldName), expectedValue);
                    elseif isfield(specs(j).TypeData, fieldName)
                        keep(j) = isequal(specs(j).TypeData.(fieldName), expectedValue);
                    end
                end
                specs = specs(keep);
            end
        end

        function addIssue(obj, severity, message, sourcePath)
        %addIssue Add a validation/discovery issue.
            obj.Issues(end+1) = obj.makeIssue(severity, message, sourcePath);
        end

        function priority = getSpecPriority(obj, spec)
        %getSpecPriority Return precedence for a plugin spec. Lower wins.
            rootPriority = obj.getSpecRootPriority(spec);

            switch lower(spec.Source)
                case 'project'
                    sourcePriority = 10;
                case 'sidecar'
                    sourcePriority = 20;
                case {'class', 'function'}
                    sourcePriority = 30;
                case 'builtin'
                    sourcePriority = 40;
                otherwise
                    sourcePriority = 50;
            end

            priority = rootPriority * 100 + sourcePriority;
        end

        function specs = sortSpecsByPriority(obj, specs)
        %sortSpecsByPriority Sort specs according to registry precedence.
            if isempty(specs)
                return
            end

            priority = arrayfun(@(s) obj.getSpecPriority(s), specs);
            [~, sortIdx] = sort(priority);
            specs = specs(sortIdx);
        end

        function priority = getSpecRootPriority(obj, spec)
        %getSpecRootPriority Return root-order priority. Lower wins.
            roots = obj.getRootPaths();
            if ~iscell(roots)
                roots = {roots};
            end

            priority = numel(roots) + 1;
            for i = 1:numel(roots)
                if ~isempty(roots{i}) && startsWith(spec.SourcePath, roots{i})
                    priority = i;
                    return
                end
            end
        end

        function specs = removeDisabledSpecs(obj, specs)
        %removeDisabledSpecs Remove specs disabled by the user.
            if isempty(specs)
                return
            end

            disabledIds = obj.getDisabledPluginIds();
            if isempty(disabledIds)
                return
            end

            keep = ~ismember({specs.Id}, disabledIds);
            specs = specs(keep);
        end

        function disabledIds = getDisabledPluginIds(obj)
        %getDisabledPluginIds Return disabled ids for this plugin type.
            prefGroup = obj.getPreferenceGroup();
            prefName = obj.getDisabledPreferenceName();
            if ispref(prefGroup, prefName)
                disabledIds = getpref(prefGroup, prefName);
            else
                disabledIds = {};
            end

            if ischar(disabledIds)
                disabledIds = {disabledIds};
            elseif isstring(disabledIds)
                disabledIds = cellstr(disabledIds);
            end
        end

        function setDisabledPluginIds(obj, disabledIds)
        %setDisabledPluginIds Persist disabled ids for this plugin type.
            setpref(obj.getPreferenceGroup(), ...
                obj.getDisabledPreferenceName(), disabledIds)
        end

        function prefName = getDisabledPreferenceName(obj)
        %getDisabledPreferenceName Return preference key for disabled ids.
            prefName = matlab.lang.makeValidName( ...
                [obj.PluginType, '_DisabledPluginIds']);
        end

    end

    methods (Static, Access = protected)

        function [includeDisabled, args] = parseListOptions(varargin)
        %parseListOptions Extract registry list options from name-value pairs.
            includeDisabled = false;
            args = varargin;

            if isempty(args)
                return
            end

            removeIdx = false(1, numel(args));
            for i = 1:2:numel(args)
                if strcmpi(args{i}, 'IncludeDisabled')
                    includeDisabled = logical(args{i+1});
                    removeIdx([i, i+1]) = true;
                end
            end

            args(removeIdx) = [];
        end

        function prefGroup = getPreferenceGroup()
        %getPreferenceGroup Return preference group for plugin registry state.
            prefGroup = 'NansenPluginRegistry';
        end

    end

    methods (Static, Access = protected)

        function issue = makeIssue(severity, message, sourcePath)
            issue = struct( ...
                'Severity', severity, ...
                'Message', message, ...
                'SourcePath', sourcePath);
        end

        function issues = getEmptyIssues()
            issues = struct('Severity', {}, 'Message', {}, 'SourcePath', {});
        end

    end

    properties (Abstract, Constant, Access = protected)
        PluginType
        SidecarFilename
    end

    methods (Abstract, Access = protected)
        rootPaths = getRootPaths(obj)
    end

end
