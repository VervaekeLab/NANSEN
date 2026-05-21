classdef Registry < nansen.plugin.base.Registry
%Registry Registry for NANSEN table variable plugins.
%
%   Discovers TableVariableSpec instances from sidecar JSON files and from
%   compatibility introspection of TableVariable subclasses.
%
%   Root paths are the +tablevariable folders provided at construction time.
%   They are scanned for:
%     - tablevariable.plugin.json sidecar files
%     - *.m files in +session/ and +subject/ subfolders that implement
%       nansen.metadata.abstract.TableVariable subclasses
%
%   Root path ordering determines precedence: the first root path that
%   contributes a spec for a given VariableName+TableType combination takes
%   priority. Callers should pass the project folder first, then module
%   folders.
%
%   Usage:
%     rootPaths = [project.getTableVariableFolder(), ...
%                  arrayfun(@(m) m.getTableVariableFolder(), ...
%                           project.IncludedModules, 'uni', false)];
%     registry  = nansen.plugin.tablevariable.Registry(rootPaths);
%     specs     = registry.list();
%     specs     = registry.listByTableType('session');
%     attrs     = registry.getVariableAttributes('session');
%
%   See also: nansen.plugin.base.Registry, nansen.plugin.tablevariable.TableVariableSpec

    properties (Constant, Access = protected)
        PluginType      = nansen.plugin.enum.PluginType.TableVariable
        SidecarFilename = "tablevariable.plugin.json"
    end

    % ------------------------------------------------------------------ %
    methods

        function obj = Registry(rootPaths, projectFolder)
        %Registry Construct a table variable registry from a set of root paths.
        %
        %   obj = Registry(rootPaths) where rootPaths is a cell array of
        %   absolute +tablevariable folder paths.
        %
        %   obj = Registry(rootPaths, projectFolder) additionally scopes the
        %   disabled-plugin state to the given project folder.
            arguments
                rootPaths     = {}
                projectFolder (1,1) string = ""
            end
            obj@nansen.plugin.base.Registry(rootPaths, projectFolder);
        end

    end

    % ------------------------------------------------------------------ %
    methods (Static)

        function registry = getInstance(projectFolder)
        %getInstance Return a registry scoped to the given project folder.
        %
        %   This form has no root paths — it returns an empty registry
        %   suitable for API access (validate, diagnose) without project context.
        %   For a populated registry, construct directly:
        %     registry = nansen.plugin.tablevariable.Registry(rootPaths, projectFolder)
            arguments
                projectFolder (1,1) string = ""
            end
            persistent cachedRegistry
            if isempty(cachedRegistry) || ~isvalid(cachedRegistry) ...
                    || cachedRegistry.ProjectFolder ~= projectFolder
                cachedRegistry = nansen.plugin.tablevariable.Registry({}, projectFolder);
            end
            registry = cachedRegistry;
        end

    end

    % ------------------------------------------------------------------ %
    % Public API extensions
    % ------------------------------------------------------------------ %
    methods

        function specs = listByTableType(obj, tableType)
        %listByTableType Return specs matching the given table type, deduped by VariableName.
        %
        %   When multiple root paths provide a spec with the same VariableName and
        %   TableType, the first root path's spec wins (project-first precedence).
            arguments
                obj
                tableType (1,1) string = "session"
            end
            all = obj.list();
            if isempty(all)
                specs = nansen.plugin.tablevariable.TableVariableSpec.empty;
                return
            end

            keep = arrayfun(@(s) strcmpi(char(s.TableType), char(tableType)), all);
            typeSpecs = all(keep);

            if isempty(typeSpecs)
                specs = nansen.plugin.tablevariable.TableVariableSpec.empty;
                return
            end

            % Deduplicate by VariableName, preserving discovery order (project first).
            names = arrayfun(@(s) lower(char(s.VariableName)), typeSpecs, 'uni', false);
            [~, firstIdx] = unique(names, 'stable');
            specs = typeSpecs(firstIdx);
        end

        function attrTable = getVariableAttributes(obj, tableType)
        %getVariableAttributes Return a table of variable attributes for use by the metatable viewer.
        %
        %   Returns a MATLAB table with the same schema as the output of
        %   nansen.metadata.abstract.TableVariable.buildTableVariableTable.
            arguments
                obj
                tableType (1,1) string = "session"
            end
            specs = obj.listByTableType(tableType);
            if isempty(specs)
                attrTable = table();
                return
            end

            nSpecs = numel(specs);
            S = repmat(nansen.metadata.abstract.TableVariable.getDefaultTableVariableAttribute(), ...
                1, nSpecs);

            for i = 1:nSpecs
                try
                    iS = specs(i).toVariableAttributes();
                    fields = fieldnames(iS);
                    for f = 1:numel(fields)
                        S(i).(fields{f}) = iS.(fields{f});
                    end
                catch ME
                    obj.addIssue('warning', ME.message, char(specs(i).Id));
                end
            end

            attrTable = struct2table(S);
            if ismember('TableType', attrTable.Properties.VariableNames)
                attrTable.TableType = string(attrTable.TableType);
            end
        end

    end

    % ------------------------------------------------------------------ %
    % Required abstract implementations
    % ------------------------------------------------------------------ %
    methods (Access = protected)

        function specs = parseSidecarFile(~, filePath)
        %parseSidecarFile Parse a table variable sidecar file into a spec array.
            specs = nansen.plugin.tablevariable.TableVariableSpec.fromJsonFile(filePath);
        end

        function specs = discoverCompatibilitySpecs(obj)
        %discoverCompatibilitySpecs Discover table variable classes without sidecars.
        %
        %   Scans +session/ and +subject/ subfolders within each root path
        %   for .m files implementing TableVariable subclasses.
            specs = nansen.plugin.tablevariable.TableVariableSpec.empty;
            rootPaths = obj.getRootPaths();

            tableTypes = {'session', 'subject'};

            for r = 1:numel(rootPaths)
                rootPath = rootPaths{r};
                if ~isfolder(rootPath); continue; end

                for t = 1:numel(tableTypes)
                    typeFolder = fullfile(rootPath, ['+', tableTypes{t}]);
                    if ~isfolder(typeFolder); continue; end

                    L = dir(fullfile(typeFolder, '*.m'));
                    for i = 1:numel(L)
                        filePath = fullfile(L(i).folder, L(i).name);
                        if obj.hasSidecarForSourcePath(filePath); continue; end

                        try
                            spec = obj.createSpecFromMFile_(filePath, tableTypes{t});
                            if ~isempty(spec)
                                specs(end+1) = spec; %#ok<AGROW>
                            end
                        catch ME
                            obj.addIssue('warning', ME.message, filePath);
                        end
                    end
                end
            end
        end

        function specs = emptySpecArray(~)
        %emptySpecArray Return an empty typed array for concatenation.
            specs = nansen.plugin.tablevariable.TableVariableSpec.empty;
        end

    end

    % ------------------------------------------------------------------ %
    % Private helpers
    % ------------------------------------------------------------------ %
    methods (Access = private)

        function spec = createSpecFromMFile_(~, filePath, tableType)
        %createSpecFromMFile_ Build a TableVariableSpec from a discovered .m file.
            functionName = utility.path.abspath2funcname(filePath);
            mc = meta.class.fromName(functionName);

            if isempty(mc)
                spec = nansen.plugin.tablevariable.TableVariableSpec.empty;
                return
            end

            if ~nansen.plugin.tablevariable.Registry.isTableVariableClass_(mc)
                spec = nansen.plugin.tablevariable.TableVariableSpec.empty;
                return
            end

            attrs = nansen.plugin.tablevariable.Registry.readClassAttributes_(mc);

            [~, fileName] = fileparts(filePath);

            opts = struct( ...
                'Id',             string(functionName), ...
                'DisplayName',    string(fileName), ...
                'Source',         "class", ...
                'SourcePath',     string(filePath), ...
                'Implementation', struct('language', 'matlab', 'kind', 'class', 'entrypoint', functionName), ...
                'VariableName',   string(fileName), ...
                'TableType',      string(tableType), ...
                'IsEditable',     logical(nansen.plugin.base.Registry.getAttr_(attrs, 'IS_EDITABLE', false)), ...
                'DefaultValue',   nansen.plugin.base.Registry.getAttr_(attrs, 'DEFAULT_VALUE', []));

            if isfield(attrs, 'LIST_ALTERNATIVES') && ~isempty(attrs.LIST_ALTERNATIVES)
                opts.Alternatives = string(attrs.LIST_ALTERNATIVES(:)');
            end

            spec = nansen.plugin.tablevariable.TableVariableSpec(opts);
        end

    end

    % ------------------------------------------------------------------ %
    % ------------------------------------------------------------------ %
    methods (Static)

        function rootPaths = collectRootPaths(project)
        %collectRootPaths Gather +tablevariable folder paths from a project and its modules.
        %
        %   Returns a cell array of absolute paths suitable for passing to
        %   the Registry constructor. The project's own folder comes first,
        %   followed by each included module's folder.
            rootPaths = {};
            try
                projectPath = project.getTableVariableFolder();
                if isfolder(projectPath)
                    rootPaths{end+1} = projectPath;
                end
            catch
            end
            if isprop(project, 'IncludedModules') && ~isempty(project.IncludedModules)
                for i = 1:numel(project.IncludedModules)
                    try
                        modPath = project.IncludedModules(i).getTableVariableFolder();
                        if isfolder(modPath)
                            rootPaths{end+1} = modPath; %#ok<AGROW>
                        end
                    catch
                    end
                end
            end
        end

    end

    % ------------------------------------------------------------------ %
    methods (Static, Access = private)

        function tf = isTableVariableClass_(mc)
        %isTableVariableClass_ True when the metaclass inherits from TableVariable.
            tf = nansen.plugin.base.Registry.hasSuperclass_(mc, ...
                'nansen.metadata.abstract.TableVariable');
        end

        function attributes = readClassAttributes_(mc)
        %readClassAttributes_ Read constant property values from a TableVariable metaclass.
            attributes = struct();
            constantProps = {'IS_EDITABLE', 'DEFAULT_VALUE', 'LIST_ALTERNATIVES'};
            classPropertyNames = {mc.PropertyList.Name};
            for i = 1:numel(constantProps)
                isMatch = strcmp(classPropertyNames, constantProps{i});
                if any(isMatch)
                    prop = mc.PropertyList(isMatch);
                    if prop.Constant && ~prop.Abstract
                        attributes.(constantProps{i}) = prop.DefaultValue;
                    end
                end
            end
        end

    end

end
