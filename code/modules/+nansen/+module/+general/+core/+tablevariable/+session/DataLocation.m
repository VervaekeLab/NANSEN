classdef DataLocation < nansen.metadata.abstract.TableVariable & nansen.metadata.abstract.TableColumnFormatter
%DataLocation Controls behavior of table cells containing datalocation items.
%
%

    % Todo: Add an update function

    properties (Constant)
        IS_EDITABLE = false
        DEFAULT_VALUE = struct.empty
    end

    properties
        % Value is a struct of pathstrings pointing to data locations.
        % Each field is a key representing the datatype, i.e rawdata or
        % processed etc, and each value is an individual char/string or a
        % cell array of chars/strings if one data are present in
        % multiple locations.

        % Value struct
    end
   
    methods
        function obj = DataLocation(S)
            if nargin < 1; S = struct.empty; end
            obj@nansen.metadata.abstract.TableVariable(S);
            assert( all( arrayfun(@isstruct, [obj.Value])), 'Value must be a struct')
        end
    end
    
    methods
        
        function str = getCellDisplayString(obj)
        %getCellDisplayString Get character vector to display in table cell
            
        % todo: vectorize
            
            % Assume that the current datalocation model is valid. This
            % is a weak assumption, since it is in theory possible to have
            % a call this function with values from sessions/metatables
            % that are not part of the current project...
            dataLocationModel = nansen.DataLocationModel();
            
            str = cell(numel(obj), 1);
            
            for i = 1:numel(obj)
                
                if ~isfield(obj(i).Value, 'Uuid')
                    dataLocationNames = fieldnames(obj(i).Value);
                else % legacy code (when each dataloc is a field...):
                    if ~isfield(obj(i).Value, 'Name')
                        obj(i).Value = dataLocationModel.expandDataLocationInfo(obj(i).Value);
                    end
                    dataLocationNames = {obj(i).Value.Name};
                end
                
                numDataLocations = numel(dataLocationNames);
                thisStr = '<html>';

                for j = 1:numDataLocations
                    
                    if isfield(obj(i).Value, 'RootPath')
                        rootPath = obj(i).Value(j).RootPath;
                        subFolder = obj(i).Value(j).Subfolders;
                    else % legacy code (when each dataloc is a field...):
                        rootPath = obj(i).Value.(dataLocationNames{j});
                        subFolder = rootPath;
                    end

                    % Subfolder might be a file, if using "virtual" folder
                    % mode where a folder level is actually consisting of
                    % files and not subfolders.
                    if ~isempty(rootPath)
                        if isfile(fullfile(rootPath, subFolder))
                            subFolder = fileparts(subFolder);
                        end
                    end
                    
                    if isempty(rootPath)
                        tmpStr = obj.getIconHtmlString('dot_off');
                    elseif isfolder(fullfile(rootPath, subFolder)) && ~isempty(subFolder)
                        tmpStr = obj.getIconHtmlString('dot_on');
                    elseif isempty(subFolder)
                        tmpStr = obj.getIconHtmlString('dot_off');
                    elseif isfolder(subFolder) % ref legacy...
                        tmpStr = obj.getIconHtmlString('dot_on');
                    else
                        tmpStr = obj.getIconHtmlString('dot_none');
                    end

                    thisStr = strcat(thisStr, tmpStr);
                end

                if numDataLocations == 0
                    thisStr = sprintf('%d Datalocations', numDataLocations);
                end
                
                str{i} = thisStr;
            end
        end
       
        function str = getCellTooltipString(obj)
        %getCellTooltipString Get character vector to display as tooltip
        
            datalocStruct = obj.Value;
            
            if isa(datalocStruct, 'cell')
                datalocStruct = datalocStruct{1};
            end
            
            if isempty(datalocStruct)
                str = '';
            
            else
                % Create a html formatted string from values in struct
                str = cell(size(datalocStruct));
                strtab = '&nbsp;&nbsp;&nbsp;&nbsp;';
                
                for i = 1:numel(datalocStruct)
                    str{i} = sprintf(['%s (%s)',...
                        '<br/>%s Root Number: %d', ...
                        '<br/>%s DiskName: %s', ...
                        '<br/>%s RootPath: %s', ...
                        '<br/>%s Folder: %s'], ...
                        datalocStruct(i).Name, char( datalocStruct(i).Type ), ...
                        strtab, datalocStruct(i).RootIdx,...
                        strtab, datalocStruct(i).Diskname, ...
                        strtab, datalocStruct(i).RootPath, ...
                        strtab, datalocStruct(i).Subfolders);
                end
                
                str = strjoin(str, '<br /><br />'); % Add blank line between data locations
                str = sprintf('<html><div align="left"> %s </div>', str);
            end
        end
        
        function onCellDoubleClick(obj, metaObj)
        %onCellDoubleClick Callback for doubleclick on table cell
        %
        % Open ui editor for changing data location root and subfolders.
        % Each data location gets its own page
            
            if ~isempty(obj.Value)
                
                S = struct();
                for i = 1:metaObj.DataLocationModel.NumDataLocations
                    thisDataLoc = metaObj.DataLocationModel.Data(i);
                    
                    fieldName = thisDataLoc.Name;
                                        
                    rootPath = metaObj.getDataLocationRootDir(fieldName);
                    allRootPaths = {thisDataLoc.RootPath.Value};
                    
                    if isempty(rootPath)
                        rootPath = '';
                    end
                    
                    if ~any(strcmp(rootPath, allRootPaths))
                        allRootPaths = [{rootPath}, allRootPaths];
                    end
                    
                    S.(fieldName).RootPath = rootPath;
                    S.(fieldName).RootPath_ = allRootPaths;
                       
                    S.(fieldName).Subfolder = obj.Value(i).Subfolders;
                    if isempty(S.(fieldName).Subfolder)
                        if isa(S.(fieldName).Subfolder, 'double')
                            S.(fieldName).Subfolder = '';
                        end
                    end
                    
                    %structeditor is not advanced enough for this yet..
                    % todo for the future
                    %S.(fieldName).Subfolder_ = @(x)uigetdir(rootPath);
                end
                
                h = structeditor.App(S, 'AdjustFigureSize', true, ...
                    'Title', 'Edit Data Location Rootpaths', ...
                    'LabelPosition', 'over', ...
                    'CustomFigureSize', [700, 300], ...
                    'Prompt', 'Select datalocation root directories'); %, ...
                    %'ValueChangedFcn', @obj.onDataLocationChanged );
                h.Title = sprintf('Edit Data Locations for %s', metaObj.sessionID);

                h.waitfor()
                
                if h.wasCanceled
                    return
                else
                    sNew = h.dataEdit;
                    if ~isequal(sNew, S)
                        metaObj.updateRootDir(sNew)
                    end
                end
            end
        end
        
        function onCellDoubleClick2(obj, metaObj)
        %onCellDoubleClick Callback for doubleclick on table cell
        %
        % Open ui editor for changing data location roots. All roots are
        % listed with a dropdown for selecting a different root for each
        % data location

            if ~isempty(obj.Value)
                
                S = struct();
                for i = 1:metaObj.DataLocationModel.NumDataLocations
                    thisDataLoc = metaObj.DataLocationModel.Data(i);
                    
                    fieldName = thisDataLoc.Name;
                    fieldName_ = strcat(fieldName, '_');
                    
                    rootPath = metaObj.getDataLocationRootDir(fieldName);
                    allRootPaths = {thisDataLoc.RootPath.Value};
                    
                    if isempty(rootPath)
                        rootPath = '';
                    end
                    
                    S.(fieldName) = rootPath;
                    if ~any(strcmp(rootPath, allRootPaths))
                        allRootPaths = [{rootPath}, allRootPaths];
                    end
                    S.(fieldName_) = allRootPaths;
                    
                end
                
                h = structeditor.App(S, 'AdjustFigureSize', true, ...
                    'Title', 'Edit Data Location Rootpaths', ...
                    'LabelPosition', 'over', ...
                    'Prompt', 'Select datalocation root directories');
                h.Title = sprintf('Edit Data Locations for %s', metaObj.sessionID);

                h.waitfor()
                
                if h.wasCanceled
                    return
                else
                    sNew = h.dataEdit;
                    if ~isequal(sNew, S)
                        metaObj.updateRootDir(sNew)
                    end
                end
            end
        end
    end
    
    methods (Access = ?structeditor.App)
        function onDataLocationChanged(obj, src, evt)
            
            switch evt.Name
                case 'Subfolder'
                    rootDirValue = evt.UIControls.RootPath.String{evt.UIControls.RootPath.Value};
                    newSubfolder = strrep(evt.UIControls.String, rootDirValue, '');
                    evt.UIControls.Subfolder.String = newSubfolder;
                    obj.Value(evt.PageNumber).Subfolders = newSubfolder;
                case 'RootPath'
                    % Todo: change the function handle for uigetdir...
                    %S.(fieldName).Subfolder_
            end
        end
    end
    
    methods (Static)
        
        function value = updateDataLocation(sessionObj)
                  
            % Todo: Change name to update when finished. then datalocation
            % will be updatable from sessionbrowser.
            
            % Todo: Make sure root uid is assigned correctly...
            
            error('not implemented')
            value = sessionObj.DataLocation;
            
            dataLocationModel = sessionObj.DataLocationModel;
            
            % Todo: Make sure this works even if rootpath identity
            % changed..
            
            for i = 1:numel(dataLocationModel.Data)
                thisLoc = dataLocationModel.Data(i);
                pathString = sessionObj.detectSessionFolder(thisLoc);
                if ~isempty(pathString)

                    folders = strsplit(pathString, filesep);
                    numFolders = numel(thisLoc.SubfolderStructure);
                    
                    value(i).RootPath = strjoin(folders(1:end-numFolders), filesep);
                    value(i).Subfolders = strjoin(folders(end-numFolders+1:end), filesep);
                    
                end
            end
        end
    end
   
    methods (Static)
        
        function str = getIconHtmlString(iconName, iconSize)
        %getIconHtmlString Return html string for icon with given name
        %
        %   str = <CLASSNAME>.getIconHtmlString(iconName)
        %
        %   str = <CLASSNAME>.getIconHtmlString(iconName, iconSize)
        %
        %   Input:
        %       iconName : 'dot_on' | 'dot_off'
        
            if nargin < 2
                iconSize = 16;
            end
            
            folderPath = nansen.common.constant.TableVariableTemplateDirectory();
            iconPath = fullfile(folderPath, '_symbols', sprintf('%s.png', iconName));
            
            sizeSpec = sprintf('width="%d" height="%d"', iconSize, iconSize);
            str = sprintf('<img src="file:%s" %s margin="0">', iconPath, sizeSpec);
            
        end
    end
end
