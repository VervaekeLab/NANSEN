classdef Registry < nansen.plugin.base.Registry
%Registry Registry for NANSEN imviewer plugins.
%
%   Discovers ImviewerPluginSpec instances from sidecar JSON files and from
%   compatibility introspection of ImviewerPlugin subclasses.
%
%   Root priority (highest first):
%     1. Project plugin folder (constructor argument, if any)
%     2. code/apps/+imviewer/+plugin/ (app-scoped @ClassName class folders)
%     3. code/wrappers/+nansen/+plugin/+imviewer/ (wrapper flat .m files)
%
%   Thin-wrapper classes (imviewer.plugin.* that simply delegate to
%   nansen.plugin.imviewer.*) are detected and skipped during compat
%   discovery to avoid duplicate entries.
%
%   Usage:
%     registry = nansen.plugin.imviewer.Registry();
%     registry = nansen.plugin.imviewer.Registry(projectPluginFolder);
%     specs    = registry.list();
%     spec     = registry.resolve('imviewer.plugin.RoiManager');
%     spec     = registry.findPlugin('RoiManager');   % by name
%
%   See also: nansen.plugin.base.Registry, nansen.plugin.imviewer.ImviewerPluginSpec

    properties (Constant, Access = protected)
        PluginType      = nansen.plugin.enum.PluginType.ImviewerPlugin
        SidecarFilename = "imviewerplugin.plugin.json"
    end

    % ------------------------------------------------------------------ %
    methods (Static)

        function registry = getInstance(projectFolder)
        %getInstance Return a registry for the given project folder.
            arguments
                projectFolder (1,1) string = ""
            end
            persistent cachedRegistry
            if isempty(cachedRegistry) || ~isvalid(cachedRegistry) ...
                    || cachedRegistry.ProjectFolder ~= projectFolder
                cachedRegistry = nansen.plugin.imviewer.Registry(projectFolder);
            end
            registry = cachedRegistry;
        end

    end

    % ------------------------------------------------------------------ %
    % Public API extensions
    % ------------------------------------------------------------------ %
    methods

        function spec = findPlugin(obj, pluginName)
        %findPlugin Return a spec by stable Id or display name.
        %
        %   Tries resolve(id) first; falls back to findByDisplayName (exact,
        %   case-insensitive). Errors if no match is found.
            arguments
                obj
                pluginName (1,1) string
            end

            try
                spec = obj.resolve(pluginName);
                return
            catch
                % Not found by Id — try display name
            end

            specs = obj.findByDisplayName(pluginName);
            if isempty(specs)
                % Case-insensitive fallback
                all = obj.list();
                if ~isempty(all)
                    match = strcmpi(pluginName, arrayfun(@(s) char(s.DisplayName), all, 'uni', false));
                    if any(match)
                        spec = all(find(match, 1));
                        return
                    end
                end
                error('nansen:plugin:imviewer:Registry:NotFound', ...
                    'Imviewer plugin "%s" was not found.', pluginName)
            end
            spec = specs(1);
        end

    end

    % ------------------------------------------------------------------ %
    % Required abstract implementations
    % ------------------------------------------------------------------ %
    methods (Access = protected)

        function rootPaths = getRootPaths(obj)
        %getRootPaths Return ordered discovery roots.
            thisDir  = fileparts(mfilename('fullpath'));
            % thisDir = .../code/+nansen/+plugin/+imviewer
            codeRoot = fileparts(fileparts(fileparts(thisDir)));

            appPluginRoot     = fullfile(codeRoot, 'apps', '+imviewer', '+plugin');
            wrapperPluginRoot = fullfile(codeRoot, 'wrappers', '+nansen', '+plugin', '+imviewer');

            rootPaths = {};

            if obj.ProjectFolder ~= ""
                rootPaths{end+1} = char(obj.ProjectFolder);
            end

            if isfolder(appPluginRoot)
                rootPaths{end+1} = appPluginRoot;
            end

            if isfolder(wrapperPluginRoot)
                rootPaths{end+1} = wrapperPluginRoot;
            end
        end

        function specs = parseSidecarFile(~, filePath)
        %parseSidecarFile Parse an imviewer plugin sidecar into a spec array.
            specs = nansen.plugin.imviewer.ImviewerPluginSpec.fromJsonFile(filePath);
        end

        function specs = discoverCompatibilitySpecs(obj)
        %discoverCompatibilitySpecs Discover ImviewerPlugin subclasses without sidecars.
        %
        %   Scans each root path for .m files implementing ImviewerPlugin
        %   subclasses. Thin-wrapper classes (those that simply delegate to
        %   another package's class with the same Name) are skipped.
            specs = nansen.plugin.imviewer.ImviewerPluginSpec.empty;
            rootPaths = obj.getRootPaths();

            for r = 1:numel(rootPaths)
                rootPath = rootPaths{r};
                if ~isfolder(rootPath); continue; end

                % Collect: @ClassName/ClassName.m class folders + flat .m files
                mFiles = nansen.plugin.imviewer.Registry.listMatlabFiles_(rootPath);

                for i = 1:numel(mFiles)
                    filePath = mFiles{i};
                    if obj.hasSidecarForSourcePath(filePath); continue; end

                    try
                        spec = obj.createSpecFromMFile_(filePath);
                        if ~isempty(spec)
                            specs(end+1) = spec; %#ok<AGROW>
                        end
                    catch ME
                        obj.addIssue('warning', ME.message, filePath);
                    end
                end
            end
        end

        function specs = emptySpecArray(~)
        %emptySpecArray Return an empty typed array for concatenation.
            specs = nansen.plugin.imviewer.ImviewerPluginSpec.empty;
        end

    end

    % ------------------------------------------------------------------ %
    % Private helpers
    % ------------------------------------------------------------------ %
    methods (Access = private)

        function tf = hasSidecarForSourcePath(obj, mFilePath)
        %hasSidecarForSourcePath True when a sidecar exists alongside the .m file.
            sidecarPath = fullfile(fileparts(mFilePath), obj.SidecarFilename);
            tf = isfile(sidecarPath);
        end

        function spec = createSpecFromMFile_(~, filePath)
        %createSpecFromMFile_ Build an ImviewerPluginSpec from a discovered .m file.
            functionName = utility.path.abspath2funcname(filePath);
            mc = meta.class.fromName(functionName);

            if isempty(mc)
                spec = nansen.plugin.imviewer.ImviewerPluginSpec.empty;
                return
            end

            % Skip classes that are not ImviewerPlugin subclasses
            if ~nansen.plugin.imviewer.Registry.isImviewerPluginClass_(mc)
                spec = nansen.plugin.imviewer.ImviewerPluginSpec.empty;
                return
            end

            % Skip thin wrappers that delegate to nansen.plugin.imviewer.*
            if nansen.plugin.imviewer.Registry.isThinWrapper_(mc)
                spec = nansen.plugin.imviewer.ImviewerPluginSpec.empty;
                return
            end

            displayName = nansen.plugin.imviewer.Registry.readName_(mc, functionName);

            opts = struct( ...
                'Id',             string(functionName), ...
                'DisplayName',    string(displayName), ...
                'Source',         "class", ...
                'SourcePath',     string(filePath), ...
                'Implementation', struct('language', 'matlab', 'kind', 'class', ...
                    'entrypoint', functionName));

            spec = nansen.plugin.imviewer.ImviewerPluginSpec(opts);
        end

    end

    % ------------------------------------------------------------------ %
    methods (Static, Access = private)

        function files = listMatlabFiles_(rootPath)
        %listMatlabFiles_ Return .m files from @ClassName/ folders and flat files.
            files = {};
            if ~isfolder(rootPath); return; end

            entries = dir(rootPath);
            for i = 1:numel(entries)
                name = entries(i).name;
                if strncmp(name, '.', 1); continue; end

                fullEntry = fullfile(rootPath, name);
                if entries(i).isdir && strncmp(name, '@', 1)
                    % @ClassName/ class folder — look for ClassName.m inside
                    className = name(2:end);
                    mFile = fullfile(fullEntry, [className, '.m']);
                    if isfile(mFile)
                        files{end+1} = mFile; %#ok<AGROW>
                    end
                elseif ~entries(i).isdir
                    [~, ~, ext] = fileparts(name);
                    if strcmp(ext, '.m')
                        files{end+1} = fullfile(rootPath, name); %#ok<AGROW>
                    end
                end
            end
        end

        function tf = isImviewerPluginClass_(mc)
        %isImviewerPluginClass_ True when the metaclass inherits from ImviewerPlugin.
            tf = nansen.plugin.imviewer.Registry.hasSuperclass_( ...
                mc, 'imviewer.ImviewerPlugin') || ...
                 nansen.plugin.imviewer.Registry.hasSuperclass_( ...
                mc, 'applify.mixin.AppPlugin');
        end

        function tf = isThinWrapper_(mc)
        %isThinWrapper_ True when the class directly inherits from nansen.plugin.imviewer.*.
        %
        %   Thin wrappers in imviewer.plugin.* exist only for backward
        %   compatibility and delegate completely to the authoritative
        %   implementation in nansen.plugin.imviewer.*. Skipping them avoids
        %   duplicate entries in the registry.
            for i = 1:numel(mc.SuperclassList)
                supName = mc.SuperclassList(i).Name;
                if strncmp(supName, 'nansen.plugin.imviewer.', 23)
                    tf = true;
                    return
                end
            end
            tf = false;
        end

        function tf = hasSuperclass_(mc, superclassName)
        %hasSuperclass_ Recursive superclass check.
            tf = false;
            for i = 1:numel(mc.SuperclassList)
                if strcmp(mc.SuperclassList(i).Name, superclassName) || ...
                        nansen.plugin.imviewer.Registry.hasSuperclass_( ...
                        mc.SuperclassList(i), superclassName)
                    tf = true;
                    return
                end
            end
        end

        function name = readName_(mc, fallback)
        %readName_ Read the Name constant from a metaclass, falling back to class name.
            nameProp = strcmp({mc.PropertyList.Name}, 'Name');
            if any(nameProp)
                prop = mc.PropertyList(find(nameProp, 1));
                if prop.Constant && ~prop.Abstract
                    name = char(prop.DefaultValue);
                    if ~isempty(name); return; end
                end
            end
            parts = strsplit(fallback, '.');
            name = parts{end};
        end

    end

end
