classdef FolderMatcherDialog < uiw.abstract.AppWindow
%FolderMatcherDialog UI Dialog for matching set of folders manually
%
%   h = FolderMatcherDialog(matchedList, unmatchedList) opens the dialog
%   provided a set of matched folders and a set of unmatched folders.
%
%   INPUTS:
%       matchedList : Struct array of matched folders. Each element in the
%           struct array is a set of matched folders, and each field of the
%           struct refers to a named location for a folder. Each value is 
%           a character vector representing the absolute path to the folder
%       unmatchedList : Cell array of session folders. The cell array has 
%           one cell per field in the struct, and  each cell contains a 
%           list of unmatched folders. Each value is a character vector
%           representing the absolute path to the folder


%   Todo:
%       [ ] Make some labels and decorations
%       [ ] Add a search autoupdate input field
%       [ ] More options, i.e unmatch a folder from a matched set of
%           folders

    properties (Constant, Access=protected) % Inherited from uiw.abstract.AppWindow
        AppName char = 'Match Session Folders'
    end
        
    properties
        NumDataLocations
        MatchedSessionFolderList
        UnmatchedSessionFolderList
    end
    
    properties 
        MatchedSessionFolderNameList
        UnmatchedSessionFolderNameList
    end
    
    properties (Access = private)
        UITable
        UIListbox matlab.ui.control.UIControl
        TableContextMenu
    end
    
    
    methods
        
        function obj = FolderMatcherDialog(matchedList, unmatchedList)
            
            assert( numel(fieldnames(matchedList)) == numel(unmatchedList), ...
                'Number of Data Locations in inputs do not match')
            
            obj.NumDataLocations = numel(unmatchedList);
            obj.MatchedSessionFolderList = matchedList;
            obj.UnmatchedSessionFolderList = unmatchedList;
            
            obj.createTable()
            obj.createListbox()
            %obj.createButtons()

            obj.updateTable()
            obj.updateListbox()
        end
        
    end
    
    methods
        
        function set.MatchedSessionFolderList(obj, newValue)
            obj.MatchedSessionFolderList = newValue;
            obj.onMatchedSessionFolderListSet()
        end
        
        function set.UnmatchedSessionFolderList(obj, newValue)
            obj.UnmatchedSessionFolderList = newValue;
            obj.onUnmatchedSessionFolderListSet()
        end
        
        function uiwait(obj)
            obj.Figure.CloseRequestFcn = @(s,e)uiresume(s);
            uiwait(obj.Figure)
        end
    end
    
    methods (Access = private)
        
        function createTable(obj)
            
            obj.UITable = uim.widget.StylableTable('Parent', obj.Figure, ...
                'Editable', true, ...
                'RowHeight', 20, ...
                'FontSize', 8, ...
                'FontName', 'helvetica', ...
                'FontName', 'avenir next', ...
                'SelectionMode', 'single', ...
                'Sortable', false, ...
                'ColumnResizePolicy', 'subsequent', ...
                'MouseClickedCallback', @obj.onTableMousePress );
            
            obj.UITable.Position = [0.05 0.5 0.9 0.45];
            
            hMenu = uicontextmenu(obj.Figure);
            mItem = uimenu(hMenu, 'Text', 'Unmatch sessions');
            mItem.Callback = @obj.onUnmatchSessionMenuItemClicked;
            
            obj.TableContextMenu = hMenu;
        end
        
        function createListbox(obj)
            
            figPos = getpixelposition(obj.Figure);
            [xInit, pad] = deal( round( figPos(3).*0.05 ) );
            lengthInit = round( figPos(3) .* 0.9 );
            
            componentLength = ones(1, obj.NumDataLocations) ./ obj.NumDataLocations;
            
            [x, w] = uim.utility.layout.subdividePosition(xInit-1, ...
                lengthInit, componentLength, 10);
            
            for i = 1:obj.NumDataLocations
                obj.UIListbox(i) = uicontrol(obj.Figure, 'style', 'listbox');
                obj.UIListbox(i).Units = 'pixels';
                obj.UIListbox(i).Position = [x(i), pad, w(i), 0.4];
                obj.UIListbox(i).Units = 'normalized';
                obj.UIListbox(i).Position([2,4]) = [0.05 0.4];
                obj.UIListbox(i).FontSize = 12;
                obj.UIListbox(i).FontName = 'avenir next';
                
                cMenu = uicontextmenu(obj.Figure);
                menuItem = uimenu(cMenu, 'Text', 'Add Selected Folder to Matched Selection');
                menuItem.Callback = @(s,e,idx)obj.onAddItemToSetMenuItemClicked(i);
                menuItem = uimenu(cMenu, 'Text', 'Match Selected Folders');
                menuItem.Callback = @(s,e)obj.onMatchSelectedItems();                
                obj.UIListbox(i).ContextMenu = cMenu;
            end
        end
        
        function createButtons(obj)
            % Todo?
            % Do we need any buttons?
        end
        
        function updateTable(obj)
            T = struct2table( obj.MatchedSessionFolderNameList );
            obj.UITable.Data = table2cell(T);
            obj.UITable.ColumnName = fieldnames(obj.MatchedSessionFolderList);
        end
            
        function updateListbox(obj)
            for i = 1:numel(obj.UnmatchedSessionFolderNameList)
                items = obj.UnmatchedSessionFolderNameList{i};
                obj.UIListbox(i).String = [{'No Selection'}, items];
                obj.UIListbox(i).Value = 1;
            end
        end

    end
    
    methods (Access = private)
        
        function onMatchSelectedItems(obj)
            
            listIdx = zeros(1, obj.NumDataLocations);
            
            for i = 1:obj.NumDataLocations
                listIdx(i) = obj.UIListbox(i).Value - 1;
            end
            
            if sum( listIdx~=0 ) <= 1
                errordlg('Need to select at least 2 folders')
                return
            end
            
            newMatchedSet = struct();
            
            for i = 1:obj.NumDataLocations
                fieldName = obj.getFieldname(i);
                if listIdx == 0
                    newMatchedSet.(fieldName) = '';
                else
                    thisFolder = obj.UnmatchedSessionFolderList{i}{listIdx(i)};
                    obj.UnmatchedSessionFolderList{i}(listIdx(i)) = [];
                    newMatchedSet.(fieldName) = thisFolder;
                end
            end
            
            obj.MatchedSessionFolderList(end+1) = newMatchedSet;
            
            % Update table
            obj.updateTable()
            
            % Update listbox
            obj.updateListbox()
        end
        
        function onAddItemToSetMenuItemClicked(obj, colIdx)
            
            % Get selection idx of listbox
            listIdx = obj.UIListbox(colIdx).Value - 1;
            if listIdx == 0
                errordlg('No folder is selected')
                return
            end
            
            % Check that row is selected in table
            rowIdx = obj.UITable.SelectedRows;
            if isempty(rowIdx)
                errordlg('No row is selected')
                return
            end
            
            % Check that cell is free
            fieldName = obj.getFieldname(colIdx);
            currentValue = obj.MatchedSessionFolderList(rowIdx).(fieldName);
            
            if ~isempty(currentValue)
                answer = questdlg('This data location already has a value. Do you want to replace it?', 'Comfirm Replace');
                switch answer
                    case 'Yes'
                        %pass
                    otherwise
                        return
                end
            end
            
            % Remove from unmatched list
            currentPath = obj.UnmatchedSessionFolderList{colIdx}{listIdx};
            obj.UnmatchedSessionFolderList{colIdx}(listIdx) = [];
             
            % Add to matched set
            if ~isempty(obj.MatchedSessionFolderList(rowIdx).(fieldName))
                pathToUnmatch = obj.MatchedSessionFolderList(rowIdx).(fieldName);
                obj.UnmatchedSessionFolderList{colIdx}{end+1} = pathToUnmatch;
            end
            obj.MatchedSessionFolderList(rowIdx).(fieldName) = currentPath;
            
            % Update table
            obj.updateTable()
            
            % Update listbox
            obj.updateListbox()
        end
        
        function onUnmatchSessionMenuItemClicked(obj, src, evt)
            
            % Get row number... 
            rowIdx = obj.UITable.SelectedRows;
            
            % Unmatch...
            folders = struct2cell(obj.MatchedSessionFolderList(rowIdx));
            obj.MatchedSessionFolderList(rowIdx) = [];
            
            % Add unmatched folders to the unmatched folder lists
            for i = 1:numel(folders)
                if ~isempty(folders{i})
                    obj.UnmatchedSessionFolderList{i}{end+1} = folders{i};
                end
            end
            
            % Update table...
            obj.updateTable()
            
            % Update listbox
            obj.updateListbox()
        end
        
        function onTableMousePress(obj, src, evt)
            
            if evt.Button == 3 || strcmp(evt.SelectionType, 'alt')
                
                if ismac && evt.Button == 1 && evt.MetaOn
                    return % Command click on mac should not count as right click
                end
                
                obj.UITable.selectRowFromMouseEvent(evt)
                if isempty(obj.UITable.SelectedRows); return; end
                
                % Open context menu for table
                if ~isempty(obj.TableContextMenu)
                    position = obj.UITable.getTableContextMenuPosition(evt.Position);
                    % Set position and make menu visible.
                    obj.TableContextMenu.Position = position; 
                    obj.TableContextMenu.Visible = 'on';
                end 
            end
        end
        
        function onMatchedSessionFolderListSet(obj)
            obj.MatchedSessionFolderNameList = obj.MatchedSessionFolderList;
            for i = 1:numel(obj.MatchedSessionFolderList)
                obj.MatchedSessionFolderNameList(i) = structfun(...
                    @(f)obj.getFolderName(f), obj.MatchedSessionFolderList(i), 'uni', 0);
            end
        end
        
        function onUnmatchedSessionFolderListSet(obj)
            obj.UnmatchedSessionFolderNameList = cellfun(@(c) obj.getFolderName(c), ...
                obj.UnmatchedSessionFolderList, 'uni', 0);
        end
        
        function fieldName = getFieldname(obj, colIdx)
            fieldNames = fieldnames(obj.MatchedSessionFolderNameList);
            fieldName = fieldNames{colIdx};
        end
        
        function folderName = getFolderName(obj, pathStr)
            [~, folderName] = fileparts(pathStr);
        end
    end
    
end