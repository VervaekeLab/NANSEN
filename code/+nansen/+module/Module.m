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

%   This class is used for accessing and managing the relevant files for a 
%   module. There are methods for listing all items of a specific type, and
%   methods for initializing new items from templates.

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
        ModuleUpdated
    end

    methods
        function obj = Module(configFilePath, options)

% %             arguments
% %                 configFilePath
% %                 options.IsInternal
% %             end

            if ~nargin; return; end
            
            fileStr = fileread(configFilePath);
            moduleSpecification = jsondecode(fileStr);

            obj.Name = moduleSpecification.attributes.moduleLabel;
            obj.FolderPath = fileparts(configFilePath);
            obj.PackageName = utility.path.pathstr2packagename(obj.FolderPath);

            obj.CachedFilePaths = containers.Map();
            obj.ItemTables = containers.Map();
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

        function tableVariables = get.TableVariables(obj)
            tableVariables = "N/A";
        end

        function dataVariables = get.DataVariables(obj)
            dataVariables = "N/A";
        end      

        function pipelines = get.Pipelines(obj)
            pipelines = "N/A";
        end

    end

    methods (Access = private)
        
        
    end
    
    methods % Methods for listing items.

        function fileAdapterList = listFileAdapters(obj)
        %listFileAdapters List all file adapters associated with this project

            fileAdapterRootPath = obj.getFileAdapterFolder();
            fileAdapterList = nansen.dataio.listFileAdapters({fileAdapterRootPath});
            fileAdapterList = struct2table(fileAdapterList);
        end

    end

    methods (Access = public)

        function fileAdapterFolder = getFileAdapterFolder(obj)
            fileAdapterFolder = fullfile(obj.FolderPath, '+fileadapter');
        end

        function sessionMethodFolder = getSessionMethodFolder(obj)
            sessionMethodFolder = fullfile(obj.FolderPath, '+sessionmethod');
        end

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

        function fileList = listFiles(obj, itemType)
        %listFiles List files in a folder hierarchy for given item type
            rootFolder = obj.getItemRootFolder(itemType);
            switch itemType
                case {'SessionMethod', 'TableVariable', 'FileAdapter'}
                    fileList = obj.listMFiles(rootFolder);
                case {'DataVariable', 'Pipeline'}
                    fileList = obj.listJsonFiles(rootFolder);
            end
        end

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
            switch itemType
                case 'FileAdapter'
                    itemTable = buildFileAdapterTable(obj, fileList);
                case 'SessionMethod'
                    itemTable = buildSessionMethodTable(obj, fileList);
                case 'TableVariable'
                    itemTable = [];
                case 'DataVariable'
                    itemTable = [];
                case 'Pipeline'
                    itemTable = [];
            end
            obj.ItemTables(itemType) = itemTable;
        end
    end

    methods (Access = private)
        
        function fileAdapterTable = buildFileAdapterTable(obj, fileList)
            
            fileAdapterList = struct(...
                'FileAdapterName', {},...
                'FunctionName', {}, ...
                'SupportedFileTypes', {}, ...
                'DataType', {});

            count = 1;
                        
            % Loop through m-files and add to file adapter list if this 
            for i = 1:numel(fileList)

                thisFilePath = utility.dir.abspath(fileList(i));
                thisFcnName = utility.path.abspath2funcname(thisFilePath);
                try
                    mc = meta.class.fromName(thisFcnName);
                
                    if ~isempty(mc) && isa(mc, 'meta.class') && isFileAdapterClass(mc)
                    
                        [~, fileName] = fileparts(thisFilePath);
                    
                        fileAdapterList(count).FileAdapterName = fileName;
                        fileAdapterList(count).FunctionName = thisFcnName;
                        isProp = strcmp({mc.PropertyList.Name}, 'SUPPORTED_FILE_TYPES');
                        fileAdapterList(count).SupportedFileTypes = mc.PropertyList(isProp).DefaultValue;
                        isProp = strcmp({mc.PropertyList.Name}, 'DataType');
                        fileAdapterList(count).DataType = mc.PropertyList(isProp).DefaultValue;
                        count = count + 1;
                    end
                catch ME
                    warning(ME.message)
                end
            end

            fileAdapterTable = struct2table(fileAdapterList);

            function tf = isFileAdapterClass(mc)
                tf = contains('nansen.dataio.FileAdapter', {mc.SuperclassList.Name});
            end
        end
        
        function sessionMethodTable = buildSessionMethodTable(obj, fileList)
            % Todo: Also find functions...
            sessionMethodList = struct(...
                'Name', {},...
                'FunctionName', {});

            count = 1;
                        
            % Loop through m-files and add to file adapter list if this 
            for i = 1:numel(fileList)
                mFilePath = utility.dir.abspath(fileList(i));
                thisFcnName = utility.path.abspath2funcname(mFilePath);                
                
                [~, fileName] = fileparts(mFilePath);
                
                sessionMethodList(count).Name = fileName;
                sessionMethodList(count).FunctionName = thisFcnName;
                count = count + 1;
            end

            sessionMethodTable = struct2table(sessionMethodList);

            function tf = isSessionMethodClass(mc)
                tf = contains('nansen.dataio.FileAdapter', {mc.SuperclassList.Name});
            end
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