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

    properties (SetAccess = protected)% (SetAccess = immutable)
        Name
        Description
    end

    properties (Dependent, SetAccess = private)
        SessionMethods
        TableVariables
        FileAdapters
        DataVariables
        Pipelines
    end
    
    properties (Access = private)
        FolderPath
        PackageName
    end

    properties (Access = private)
        ItemTables
        CachedFilePaths
    end

    events
        ModuleUpdated % Todo
    end

    methods % Constructor
        function obj = Module(configFilePath, options)

% %             arguments
% %                 configFilePath
% %                 options.IsInternal
% %             end

            if ~nargin; return; end
            
            fileStr = fileread(configFilePath);
            moduleSpecification = jsondecode(fileStr);

            obj.Name = moduleSpecification.attributes.moduleLabel;
            obj.Description = moduleSpecification.attributes.moduleDescription;
            obj.FolderPath = fileparts(configFilePath);
            obj.PackageName = utility.path.pathstr2packagename(obj.FolderPath);

            obj.CachedFilePaths = containers.Map();
            obj.ItemTables = containers.Map();
        end
    end

    methods (Access = public)

        function fileAdapterFolder = getFileAdapterFolder(obj)
            fileAdapterFolder = fullfile(obj.FolderPath, '+fileadapter');
        end

        function sessionMethodFolder = getSessionMethodFolder(obj)
            sessionMethodFolder = fullfile(obj.FolderPath, '+sessionmethod');
        end

        function tableVariableFolder = getTableVariableFolder(obj)
            %tableVariableFolder = fullfile(obj.FolderPath, '+tablevariable');
            tableVariableFolder = obj.getItemRootFolder('TableVariable');
        end

        function itemTable = getTable(obj, itemType)
            itemType = validatestring(itemType, {'SessionMethod', 'TableVariable', 'FileAdapter'}, 1);
            itemTable = obj.rehash(itemType);
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

        function dataVariables = get.DataVariables(obj)
            dataVariables = "N/A";
        end      

        function pipelines = get.Pipelines(obj)
            pipelines = "N/A";
        end

    end

    methods (Access = protected)
        
        function rootPath = getItemRootFolder(obj, itemType)
        %getItemRootFolder Get root folder for files of specified item

            itemType = lower(itemType);

            switch itemType
                case {'sessionmethod', 'tablevariable', 'fileadapter'}
                    rootPath = fullfile(obj.FolderPath, ['+', itemType]);

                case {'datavariable', 'pipeline'}
                    rootPath = fullfile(obj.FolderPath, 'resources', itemType);
            end
        end

        function [fileList, relativePaths] = listFiles(obj, itemType)
        %listFiles List files in a folder hierarchy for given item type
            rootFolder = obj.getItemRootFolder(itemType);
            switch itemType
                case {'SessionMethod', 'TableVariable', 'FileAdapter'}
                    fileList = obj.listMFiles(rootFolder);
                case {'DataVariable', 'Pipeline'}
                    fileList = obj.listJsonFiles(rootFolder);
            end
            if nargout > 1
                filePaths = utility.dir.abspath(fileList);
                relativePaths = strrep(filePaths, [rootFolder, filesep], '');
            end
        end
        
    end

    methods (Access = private)
        
        function itemTable = rehash(obj, itemType)
        %rehash Check for changes to modulefiles and perform update if necessary    
            fileList = obj.listFiles(itemType);

            if ~isKey(obj.CachedFilePaths, itemType)
                itemTable = obj.updateItemList(itemType, fileList);
            else
                oldFileList = obj.CachedFilePaths(itemType);
                if obj.isFileListModified(oldFileList, fileList)
                    itemTable = obj.updateItemList(itemType, fileList);
                else
                    itemTable = obj.ItemTables(itemType);
                end
            end
            obj.CachedFilePaths(itemType) = fileList;
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
                case 'DataVariable'
                    itemTable = [];
                case 'Pipeline'
                    itemTable = [];
            end
            obj.ItemTables(itemType) = itemTable;
        end
        
    end

    methods (Static)

        function fileList = listMFiles(rootFolder)
            
            import utility.dir.listClassdefFilesInClassFolder

            % List all class definition files that are located in a class folder
            fileListA = listClassdefFilesInClassFolder(rootFolder);
            
            % List all m-files that are not located in a class folder
            fileListB = utility.dir.recursiveDir(rootFolder, ...
                'IgnoreList', "@", 'Type', 'file', 'FileType', 'm');
            
            fileList = cat(1, fileListA, fileListB);
        end

        function fileList = listJsonFiles(rootFolder)
            % List all json-files in a folder hierarchy
            import utility.dir.recursiveDir
            fileList = recursiveDir(rootFolder, 'Type', 'file', 'FileType', 'json');
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
    
    end

end