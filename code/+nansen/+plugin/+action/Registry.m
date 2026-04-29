classdef Registry < nansen.plugin.base.Registry
%Registry Registry for entity/action plugins.

    properties (Constant, Access = protected)
        PluginType = 'action'
        SidecarFilename = 'action.plugin.json'
    end

    properties (Access = private)
        AdditionalRootPaths cell = {}
    end

    methods (Static)

        function registry = getInstance(forceRefresh)
        %getInstance Return shared action registry instance.
            persistent registryInstance

            if nargin < 1
                forceRefresh = false;
            end

            if isempty(registryInstance) || ~isvalid(registryInstance)
                registryInstance = nansen.plugin.action.Registry();
            end

            if forceRefresh
                registryInstance.refresh()
            end

            registry = registryInstance;
        end

    end

    methods

        function addRootPath(obj, rootPath)
        %addRootPath Add a root path for action discovery.
            obj.AdditionalRootPaths{end+1} = rootPath;
            obj.clear()
        end

        function taskAttributes = getTaskAttributes(obj, actionId)
        %getTaskAttributes Return SessionTaskMenu-compatible attributes.
            spec = obj.get(actionId);
            spec = nansen.plugin.action.ActionSpec.fromPluginSpec(spec);
            taskAttributes = spec.toTaskAttributes();
        end

        function paths = listSessionMethodPaths(obj)
        %listSessionMethodPaths Return discovered session method file paths.
            specs = obj.list('EntityType', 'session');
            paths = transpose({specs.SourcePath});
        end

    end

    methods (Access = protected)

        function rootPaths = getRootPaths(obj)
        %getRootPaths Return roots where action plugins are defined.
            projectPath = obj.getProjectSessionMethodPath();
            if isempty(projectPath)
                rootPaths = {};
            else
                rootPaths = {projectPath};
            end
            rootPaths = [rootPaths, obj.AdditionalRootPaths, ...
                obj.getSessionMethodModuleRoots()];
        end

        function specs = discoverCompatibilitySpecs(obj)
        %discoverCompatibilitySpecs Import existing session method plugins.
            specs = obj.emptySpecArray();
            mFiles = obj.listMatlabFiles(obj.getRootPaths());

            for i = 1:numel(mFiles)
                try
                    spec = obj.createSpecFromSessionMethodFile(mFiles{i});
                    if ~isempty(spec)
                        specs(end+1) = spec; %#ok<AGROW>
                    end
                catch ME
                    obj.addIssue('error', ME.message, mFiles{i});
                end
            end
        end

        function spec = readSidecarSpec(~, filePath)
        %readSidecarSpec Read sidecar and convert to ActionSpec.
            baseSpec = nansen.plugin.base.PluginSpec.fromJsonFile(filePath);
            spec = nansen.plugin.action.ActionSpec.fromPluginSpec(baseSpec);

            for i = 1:numel(spec)
                if isempty(spec(i).Id)
                    [~, folderName] = fileparts(fileparts(filePath));
                    spec(i).Id = folderName;
                end
                if isempty(spec(i).DisplayName)
                    spec(i).DisplayName = spec(i).Id;
                end
                if isempty(spec(i).Source)
                    spec(i).Source = 'sidecar';
                end
            end
        end

        function spec = normalizeSpec(obj, spec)
        %normalizeSpec Fill action defaults.
            spec = normalizeSpec@nansen.plugin.base.Registry(obj, spec);
            spec.PluginType = obj.PluginType;

            if isempty(spec.DisplayName)
                spec.DisplayName = spec.Id;
            end
        end

        function specs = emptySpecArray(~)
        %emptySpecArray Return an empty action spec array.
            specs = nansen.plugin.action.ActionSpec.empty;
        end

    end

    methods (Access = private)

        function spec = createSpecFromSessionMethodFile(obj, filePath)
        %createSpecFromSessionMethodFile Infer an action spec from a method.
            functionName = utility.path.abspath2funcname(filePath);
            mc = meta.class.fromName(functionName);

            if ~isempty(mc)
                if ~nansen.plugin.action.Registry.isSessionMethodClass(mc)
                    spec = nansen.plugin.action.ActionSpec.empty;
                    return
                end
                attributes = nansen.plugin.action.Registry.getClassAttributes(mc);
                taskType = 'class';
                source = 'class';
            else
                functionHandle = str2func(functionName);
                attributes = functionHandle();
                taskType = 'function';
                source = 'function';
            end

            [~, fileName] = fileparts(filePath);
            spec = nansen.plugin.action.ActionSpec();
            spec.Id = functionName;
            spec.DisplayName = nansen.plugin.base.PluginSpec.getField( ...
                attributes, {'MethodName'}, utility.string.varname2label(fileName));
            spec.Description = nansen.plugin.base.PluginSpec.getField( ...
                attributes, {'Description'}, '');
            spec.Source = source;
            spec.SourcePath = filePath;
            spec.Implementation = struct('language', 'matlab', ...
                'kind', taskType, 'entrypoint', functionName);
            spec.TypeData = attributes;
            spec.TypeData.TaskType = taskType;
            spec.TypeData.EntityType = 'session';
            spec.TypeData.MenuLocation = ...
                nansen.plugin.action.Registry.getMenuLocation( ...
                filePath, obj.getRootPaths());
        end

    end

    methods (Static, Access = private)

        function rootPaths = getSessionMethodModuleRoots()
        %getSessionMethodModuleRoots Return package roots for method modules.
            rootPaths = {};
            sessionMethodRoot = nansen.localpath('sessionmethods');
            if ~isfolder(sessionMethodRoot)
                return
            end

            firstLevel = dir(fullfile(sessionMethodRoot, '+*'));
            firstLevel = firstLevel([firstLevel.isdir]);

            for i = 1:numel(firstLevel)
                firstPath = fullfile(firstLevel(i).folder, firstLevel(i).name);
                secondLevel = dir(fullfile(firstPath, '+*'));
                secondLevel = secondLevel([secondLevel.isdir]);

                if isempty(secondLevel)
                    rootPaths{end+1} = firstPath; %#ok<AGROW>
                else
                    rootPaths = [rootPaths, ...
                        fullfile({secondLevel.folder}, {secondLevel.name})]; %#ok<AGROW>
                end
            end
        end

        function rootPath = getProjectSessionMethodPath()
        %getProjectSessionMethodPath Return current project's method package.
            rootPath = '';
            try
                projectRootPath = nansen.localpath('project');
                [~, projectName] = fileparts(projectRootPath);
                rootPath = fullfile(projectRootPath, ...
                    'Session Methods', ['+', projectName]);
            catch
                rootPath = '';
            end
        end

        function files = listMatlabFiles(rootPaths)
        %listMatlabFiles Return MATLAB code files under root paths.
            files = {};
            if ~iscell(rootPaths)
                rootPaths = {rootPaths};
            end

            for i = 1:numel(rootPaths)
                if ~isfolder(rootPaths{i})
                    continue
                end

                L = [dir(fullfile(rootPaths{i}, '**', '*.m')); ...
                    dir(fullfile(rootPaths{i}, '**', '*.mlx'))];
                files = [files, fullfile({L.folder}, {L.name})]; %#ok<AGROW>
            end

            isTemplate = contains(files, [filesep, '+template', filesep]) | ...
                contains(files, [filesep, '+abstract', filesep]);
            files = files(~isTemplate);
        end

        function attributes = getClassAttributes(mc)
        %getClassAttributes Read known SessionMethod constant properties.
            attributes = struct();
            propertyNames = {'MethodName', 'BatchMode', 'IsManual', ...
                'IsQueueable', 'OptionsManager'};
            classPropertyNames = {mc.PropertyList.Name};

            for i = 1:numel(propertyNames)
                isMatch = strcmp(classPropertyNames, propertyNames{i});
                if any(isMatch)
                    attributes.(propertyNames{i}) = ...
                        mc.PropertyList(isMatch).DefaultValue;
                end
            end

            if ~isfield(attributes, 'MethodName')
                classNameParts = strsplit(mc.Name, '.');
                attributes.MethodName = utility.string.varname2label(classNameParts{end});
            end
            if ~isfield(attributes, 'BatchMode')
                attributes.BatchMode = 'serial';
            end
            if ~isfield(attributes, 'IsQueueable')
                attributes.IsQueueable = true;
            end
            if ~isfield(attributes, 'Alternatives')
                attributes.Alternatives = {};
            end
        end

        function tf = isSessionMethodClass(mc)
        %isSessionMethodClass True for SessionMethod subclasses.
            tf = nansen.plugin.action.Registry.hasSuperclass( ...
                mc, 'nansen.session.SessionMethod');
        end

        function tf = hasSuperclass(mc, superclassName)
        %hasSuperclass True if metaclass inherits from superclassName.
            tf = false;
            for i = 1:numel(mc.SuperclassList)
                if strcmp(mc.SuperclassList(i).Name, superclassName) || ...
                        nansen.plugin.action.Registry.hasSuperclass( ...
                        mc.SuperclassList(i), superclassName)
                    tf = true;
                    return
                end
            end
        end

        function menuLocation = getMenuLocation(filePath, rootPaths)
        %getMenuLocation Infer menu location from package folders.
            [folderPath, ~] = fileparts(filePath);

            if ~iscell(rootPaths)
                rootPaths = {rootPaths};
            end

            rootPath = '';
            for i = 1:numel(rootPaths)
                if startsWith(folderPath, rootPaths{i})
                    rootPath = rootPaths{i};
                    break
                end
            end

            if isempty(rootPath)
                packageName = utility.path.pathstr2packagename(folderPath);
            else
                relativePath = erase(folderPath, rootPath);
                relativePath = regexprep(relativePath, ['^', filesep], '');
                packageName = strrep(relativePath, filesep, '.');
            end

            menuLocation = strsplit(strrep(packageName, '+', ''), '.');
            menuLocation = menuLocation(~cellfun(@isempty, menuLocation));
        end

    end

end
