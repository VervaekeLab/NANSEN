function fileAdapterList = listFileAdapters()
%listFileAdapters Create a list of file adapters
%
%   fileAdapterList = nansen.dataio.listFileAdapters() returns a struct
%   array containing information about file adapters.
%
%   The fileAdapterList struct array contains the following fields:
%       FileAdapterName     (char) : Name of fileadapter 
%       FunctionName        (char) : Name of function for file adapter
%       SupportedFileTypes  (cell) : File types that are supported with this fileadapter
%       DataType            (char) : Name of datatype returned by this file adapter
    
    
    % Todo: Ignore file adapters with a name that are already in the list
    % Todo: Start adding from project dir, then watchfolder, then internal?
    
    rootPath = {};

    % Get folder containing file adapters from nansen core package, ...
    rootPath{end+1} = fullfile(nansen.rootpath, '+dataio', '+fileadapter');
    rootPath{end+1} = fullfile(nansen.localpath('integrations'), 'fileadapters');
    
    % ... from project folder
    
    
    % ... and from watch folders.
    
    
    % Find all subfolders and list m files.
    fileAdapterFolders = utility.path.listSubDir(rootPath, '', {}, inf);
    fileAdapterMfiles = utility.path.listFiles(fileAdapterFolders, '.m');
    
    fileAdapterList = struct('FileAdapterName', 'Default', 'FunctionName', 'load', ...
        'SupportedFileTypes', {{'mat'}}, 'DataType', 'N/A');
    
    count = 2;
    
    % Loop through m-files and add to file adapter list if this 
    for i = 1:numel(fileAdapterMfiles)
        
        thisFcnName = utility.path.abspath2funcname(fileAdapterMfiles{i});
        mc = meta.class.fromName(thisFcnName);
        
        if ~isempty(mc) && isa(mc, 'meta.class') && ...
                contains('nansen.dataio.FileAdapter', {mc.SuperclassList.Name} )
        
            [~, fileName] = fileparts(fileAdapterMfiles{i});
        
            fileAdapterList(count).FileAdapterName = fileName;
            fileAdapterList(count).FunctionName = thisFcnName;
            isProp = strcmp({mc.PropertyList.Name}, 'SUPPORTED_FILE_TYPES');
            fileAdapterList(count).SupportedFileTypes = mc.PropertyList(isProp).DefaultValue;
            isProp = strcmp({mc.PropertyList.Name}, 'DataType');
            fileAdapterList(count).DataType = mc.PropertyList(isProp).DefaultValue;
            count = count + 1;
            
        end
    end


end