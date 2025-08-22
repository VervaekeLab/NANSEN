classdef Module < handle
%Module This class encapsulates a module in NANSEN
%
%   A module is a collection of configurable methods and definitions that
%   can be included in a project. More specifically, a module may include
%   the following items:
%
%         - Session methods
%         - Table variables
%         - File adapters
%         - Data variable definitions
%         - Option sets and customizable options.
%         - Pipelines
%
%   This class is used for accessing and managing the relevant files for a
%   module. There are methods for listing all items of a specific type, and
%   methods for initializing new items from templates.
%
%   See also: nansen.dataio.FileAdapter
%             nansen.session.SessionMethod
%             nansen.metadata.abstract.TableVariable

    properties (Constant, Hidden) % Todo: Include or not?
        DEFAULT_SESSION_METHOD_CATEGORIES = {'data', 'processing', 'analysis', 'plot'};
    end

    properties (SetAccess = protected)
        Name
        Description
    end

    properties (Dependent, SetAccess = private)
        SessionMethods
        TableVariables
        FileAdapters
        DataVariables % Rename to preset data variables.
        Pipelines
    end

    properties (Dependent)
        ID
    end
    
    properties (Access = private)
        FolderPath
        PackageName
    end

    properties (Access = private)
        ItemTables
        CachedFilePaths
        % LastItemTableUpdateTime - Map where key is the name of an item table
        % and value is a the tic count for when the table was last updated.
        LastUpdateTimeForItemTable containers.Map
    end

    properties (Constant, Hidden)
        MODULE_CONFIG_FILENAME = "module.nansen.json"
    end

    events
        ModuleUpdated % Todo
    end

    methods % Constructor
        function obj = Module(pathStr, options)
        % Module - Create a module instance
        %
        %   Syntax:
        %       nansen.module.Module(filePath) creates a module given the
        %       path of a module config file given by filePath.
        %
        %       nansen.module.Module(folderPath) creates a module given the
        %       path of a folder containing a module config file.
        %

% %             arguments
% %                 configFilePath
% %                 options.IsInternal
% %             end

            if ~nargin; return; end
            
            % Check if the given path is a folder
            if isfolder(pathStr)
                pathStr = fullfile(pathStr, obj.MODULE_CONFIG_FILENAME);
            end
            
            % Read the configuration file
            obj.readConfigurationFile(pathStr)
            
            obj.FolderPath = fileparts(pathStr);
            obj.PackageName = utility.path.pathstr2packagename(obj.FolderPath);

            obj.CachedFilePaths = containers.Map();
            obj.ItemTables = containers.Map();

            % NB: Explicitly assigning a new containers.Map instance to 
            % avoid the default empty value assigned by the property type 
            % validator. This prevents multiple objects from 
            % unintentionally sharing the same handle object.
            obj.LastUpdateTimeForItemTable = containers.Map();
        end
    end

    methods (Access = public)
        
        function names = listMixins(obj, mixinType)
            arguments
                obj
                mixinType
            end
            rootPath = fullfile(obj.FolderPath, '+mixin', ['+', mixinType]);
            filePaths = utility.dir.recursiveDir(rootPath, 'OutputType', 'FilePath', 'FileType', 'm');
            names = cellfun(@(c) utility.path.abspath2funcname(c), filePaths, 'uni', 0);
        end

        function pathName = getMixinFolder(obj, mixinType)
            pathName = obj.getItemRootFolder(mixinType);
        end

        function fileAdapterFolder = getFileAdapterFolder(obj)
            fileAdapterFolder = fullfile(obj.FolderPath, '+fileadapter');
        end
        
        function objectMethodFolder = getObjectMethodFolder(obj, itemType)
            
            if strcmpi(itemType, 'session') % Todo: Consolidate
                objectMethodFolder = fullfile(obj.FolderPath, '+sessionmethod');
            else
                itemTypeNamespace = sprintf('+%s', lower(itemType));
                objectMethodFolder = fullfile(obj.FolderPath, '+objectmethod', itemTypeNamespace);
            end
        end

        function tableVariableFolder = getTableVariableFolder(obj)
            %tableVariableFolder = fullfile(obj.FolderPath, '+tablevariable');
            tableVariableFolder = obj.getItemRootFolder('TableVariable');
        end

        function itemTable = getTable(obj, itemType, forceRefresh)
            if nargin < 3; forceRefresh = false; end
            itemType = validatestring(itemType, {'SessionMethod', ...
                'TableVariable', 'FileAdapter', 'DataVariables', ...
                'DataLocations'}, 1);
            itemTable = obj.rehash(itemType, forceRefresh);
        end

        function filePaths = getFilePaths(obj, itemType)
            fileList = obj.listFiles(itemType);
            filePaths = utility.dir.abspath(fileList);
        end
    end

    methods % Get dependent properties
        
        % Todo: get from cache? Or do the following:
        % - rehash
        % - update if necessary

        function id = get.ID(obj)
            id = obj.PackageName;
        end

        function fileAdapterList = get.FileAdapters(obj)
            itemTable = obj.rehash('FileAdapter');
            fileAdapterList = itemTable.FileAdapterName;
            fileAdapterList = string(fileAdapterList)';
        end

        function sessionMethodList = get.SessionMethods(obj)
            itemTable = obj.rehash('SessionMethod');
            sessionMethodList = itemTable.Name;
            sessionMethodList = string(sessionMethodList)';
        end

        function tableVariableList = get.TableVariables(obj)
            itemTable = obj.rehash('TableVariable');
            tableVariableList = itemTable.Name;
            tableVariableList = string(tableVariableList)';
        end

        function dataVariableList = get.DataVariables(obj)
            itemTable = obj.rehash('DataVariables');
            dataVariableList = itemTable.VariableName;
            dataVariableList = string(dataVariableList)';
        end

        function pipelines = get.Pipelines(obj)
            pipelines = "N/A";
        end
    end
    
    methods % Set methods for configuration properties

        function set.Name(obj, newValue)
            obj.Name = newValue;
            obj.onNameSet()
        end

        function set.Description(obj, newValue)
            obj.Description = newValue;
            obj.onDescriptionSet()
        end
    end

    methods (Access = protected) % Callback for property set
        function onNameSet(obj)
            % Todo: Update the name in the configuration file
        end

        function onDescriptionSet(obj)
            % Todo: Update the description in the configuration file
        end
    end

    methods (Access = protected)
        
        function rootPath = getItemRootFolder(obj, itemType)
        %getItemRootFolder Get root folder for files of specified item

            itemType = lower(itemType);

            switch itemType
                case {'sessionmethod', 'tablevariable', 'fileadapter'}
                    rootPath = fullfile(obj.FolderPath, ['+', itemType]);

                case {'datavariables', 'pipeline', 'datalocations'}
                    rootPath = fullfile(obj.FolderPath, 'resources', itemType);
                
                otherwise % Assume mixin
                    rootPath = fullfile(obj.FolderPath, '+mixin', ['+', itemType]);

            end
        end

        function [fileList, relativePaths] = listFiles(obj, itemType)
        %listFiles List files in a folder hierarchy for given item type
            rootFolder = obj.getItemRootFolder(itemType);
            switch itemType
                case {'SessionMethod', 'TableVariable', 'FileAdapter'}
                    fileList = obj.listMFiles(rootFolder);
                    if strcmp(itemType, 'FileAdapter')
                        fileList = [fileList; obj.listJsonFiles(rootFolder, 'fileadapter')];
                    end
                case {'DataVariables', 'Pipeline', 'DataLocations'}
                    fileList = obj.listJsonFiles(rootFolder);
                otherwise
                    fileList = obj.listMFiles(rootFolder);
            end
            if nargout > 1
                filePaths = utility.dir.abspath(fileList);
                if ~isempty(filePaths)
                    relativePaths = strrep(filePaths, rootFolder+filesep, '');
                else
                    relativePaths = cell(size(filePaths));
                end
            end
        end
        
        function readConfigurationFile(obj, filePath)
        % readConfigFile - Read a module config file and assign properties
            fileStr = fileread(filePath);
            moduleSpecification = jsondecode(fileStr);
            
            obj.Name = moduleSpecification.Properties.Name;
            obj.Description = moduleSpecification.Properties.Description;
        end
    end

    methods (Access = private)
        
        function itemTable = rehash(obj, itemType, forceRefresh)
        %rehash Check for changes to modulefiles and perform update if necessary
            if nargin < 3; forceRefresh = false; end

            if isKey(obj.LastUpdateTimeForItemTable, itemType);
                lastTic = obj.LastUpdateTimeForItemTable(itemType);
            else
                lastTic = uint64(0);
            end

            deltaT = 1; % Update interval in seconds for checking file system for changes.

            if toc(lastTic) > deltaT
            
                fileList = obj.listFiles(itemType);
    
                if ~isKey(obj.CachedFilePaths, itemType)
                    itemTable = obj.updateItemList(itemType, fileList);
                else
                    oldFileList = obj.CachedFilePaths(itemType);
                    if obj.isFileListModified(oldFileList, fileList) || forceRefresh
                        itemTable = obj.updateItemList(itemType, fileList);
                    else
                        itemTable = obj.ItemTables(itemType);
                    end
                end
                obj.CachedFilePaths(itemType) = fileList;
                obj.LastUpdateTimeForItemTable(itemType) = tic();
            else
                itemTable = obj.ItemTables(itemType);
            end
        end

        function itemTable = updateItemList(obj, itemType, fileList)

            import nansen.dataio.FileAdapter.buildFileAdapterTable
            import nansen.session.SessionMethod.buildSessionMethodTable
            import nansen.metadata.abstract.TableVariable.buildTableVariableTable

            switch itemType
                case 'FileAdapter'
                    itemTable = buildFileAdapterTable(fileList);
                case 'SessionMethod'
                    itemTable = buildSessionMethodTable(fileList);
                case 'TableVariable'
                    itemTable = buildTableVariableTable(fileList);
                case 'DataVariables'
                    filePaths = utility.dir.abspath(fileList);
                    itemTable = obj.buildTableFromJsonFiles(filePaths);
                case 'DataLocations'
                    filePaths = utility.dir.abspath(fileList);
                    itemTable = obj.buildTableFromJsonFiles(filePaths);
                case 'Pipeline'
                    itemTable = [];
            end
            obj.ItemTables(itemType) = itemTable;
        end
    
        function resultTable = buildTableFromJsonFiles(~, filePaths)
            
            % Initialize an empty table
            resultTable = table.empty;
        
            % Loop over all file paths
            for i = 1:length(filePaths)
                % Read the JSON file
                jsonData = jsondecode(fileread(filePaths{i}));
        
                % Convert the JSON data to a table
                try
                    tempTable = struct2table(jsonData.Properties, 'AsArray', true);
                catch
                    tempTable = struct2table(jsonData, 'AsArray', true);
                end
                % Append the table to the result
                resultTable = [resultTable; tempTable]; %#ok<AGROW>
            end
        end
    end

    methods (Static)

        function module = fromName(moduleName)
        %fromName - Get a module instance from name
            
            % Build the folder path
            moduleRootFolder = nansen.common.constant.ModuleRootDirectory;
            modulePackageFolder = utility.path.packagename2pathstr(moduleName);
            moduleFolder = fullfile(moduleRootFolder, modulePackageFolder);
            
            % Get the filename and build the full filepath
            configFileName = nansen.module.Module.MODULE_CONFIG_FILENAME;
            moduleConfigFilePath = fullfile(moduleFolder, configFileName);
            
            if isfile(moduleConfigFilePath)
                module = nansen.module.Module(moduleConfigFilePath);
            else
                try
                    % Alternative (If module is external to nansen):
                    S = what( strrep(moduleName, '.', filesep));
                    moduleConfigFilePath = fullfile(S.path, configFileName);
                    if isfile(moduleConfigFilePath)
                        module = nansen.module.Module(moduleConfigFilePath);
                    else
                        error() %#ok<LTARG>
                    end
                catch
                    error('Nansen:ModuleConfigurationNotFound', ...
                        'Module configuration file was not found for module ''%s''.', moduleName)
                end
            end
        end

        function fileList = listMFiles(rootFolder)
            
            import utility.dir.listClassdefFilesInClassFolder

            % List all class definition files that are located in a class folder
            fileListA = listClassdefFilesInClassFolder(rootFolder);
            
            % List all m-files that are not located in a class folder
            % fileListB = utility.dir.recursiveDir(rootFolder, ...
            %     'IgnoreList', "@", 'Type', 'file', 'FileType', 'm', ...
            %     'RecursionDepth', 2, 'IsCumulative', false, ...
            %     'OutputType', 'FilePath');
            
            fileListB = utility.dir.recursiveDir(rootFolder, ...
                'IgnoreList', ["@", "+", 'deprecated'], 'Type', 'file', 'FileType', 'm');
            
            fileList = cat(1, fileListA, fileListB);
        end

        function fileList = listJsonFiles(rootFolder, expression)
            % List all json-files in a folder hierarchy

            arguments
                rootFolder (1,1) string
                expression (1,1) string = ""
            end

            import utility.dir.recursiveDir

            fileList = recursiveDir(rootFolder, ...
                'Type', 'file', ...
                'FileType', 'json', ...
                'Expression', expression);
        end
        
        function tf = isFileListModified(oldFileList, newFileList)
            
            tf = true; % Assume list is modified.

            [oldFilePathList, indOld] = sort( utility.dir.abspath(oldFileList) );
            [newFilePathList, indNew] = sort( utility.dir.abspath(newFileList) );
            
            if ~isequal(oldFilePathList, newFilePathList)
                return
            end

            % Go through each element and compare datenums.
            oldFileList = oldFileList(indOld);
            newFileList = newFileList(indNew);

            for i = 1:numel(oldFileList)
                if ~isequal(oldFileList(i).datenum, newFileList(i).datenum)
                    return
                end
            end

            % If we got here, the file lists are identical
            tf = false;
        end
    
        function moduleTemplateFolder = getModuleTemplateDirectory()
        % getModuleTemplateDirectory - Get pathstring for template folder
            rootFolder = fileparts( mfilename('fullpath') );
            moduleTemplateFolder = fullfile(rootFolder, "resources", ...
                "module_folder_template", "+nansen", "+module", "+category", "+name");
        end
    end
end
