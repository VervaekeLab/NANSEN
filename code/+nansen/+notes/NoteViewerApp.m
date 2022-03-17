classdef NoteViewerApp < handle
%NoteViewerApp App for viewing notes
%
%   app = NoteViewerApp(notes) open the app for a notes argument. Notes can
%   be an array of note objects, a struct array of notes or a NoteBook.
%   
%   See also nansen.notes.Note nansen.notes.NoteBook

%   Note: App was created in appdesigner, but exported to m-file for easier
%   updating and for working with git. 
%

%   TODO:
%
%   [ ] Implement add, edit, remove notes
%   [ ] Events for the above actions.
%   [ ] Indicate type of notes in list??
%   [ ] Indicate what type of note is being displayed? 
%   [ ] Import/export options for notes.
%
%   Less important
%   [ ] Create version for traditional figure.
%   [ ] Update tree when filtering items. 
%   [ ] Methods for sorting, filtering and reseting list & tree
%   [ ] some overlap with ConfigurationApp. should they have a shared
%       superclass?



    properties 
        Owner
    end
    
    properties
        Notebook
    end
    
    properties (Dependent)
        Visible matlab.lang.OnOffSwitchState
    end
    
    properties (Dependent, SetAccess = private)
        Valid 
    end

    properties (Access = private)
        NotesTitleStr cell
        NotesSessionID cell
        NotesDateCreated cell
    end
    
    events
        NotebookModified
    end

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure            matlab.ui.Figure
        NotePanel           matlab.ui.container.Panel
        NoteTextArea        matlab.ui.control.TextArea
        NoteTitleLabel      matlab.ui.control.Label
        NoteSubtitleLabel   matlab.ui.control.Label
        TabGroup            matlab.ui.container.TabGroup
        ListTab             matlab.ui.container.Tab
        ListBox             matlab.ui.control.ListBox
        TreeTab             matlab.ui.container.Tab
        Tree                matlab.ui.container.Tree
        HeaderPanel         matlab.ui.container.Panel
        TabButtonGroup      matlab.ui.container.ButtonGroup
        TreeButton          matlab.ui.control.ToggleButton
        ListButton          matlab.ui.control.ToggleButton
        SortButton          matlab.ui.control.Button
        CreateNoteButton    matlab.ui.control.Button
        LockButton          matlab.ui.control.Button
        DeleteNoteButton    matlab.ui.control.Button
        SelectTagLabel      matlab.ui.control.Label
        SelectTagDropDown   matlab.ui.control.DropDown
        SelectTypeLabel     matlab.ui.control.Label
        SelectTypeDropDown  matlab.ui.control.DropDown
    end

    methods % Set/Get methods
        function set.Visible(app, visibleState)
            app.UIFigure.Visible = visibleState;
        end
        
        function visibleState = get.Visible(app)
            visibleState = app.UIFigure.Visible;
        end
        
        function isValid = get.Valid(app)
            isValid = isvalid(app) && isvalid(app.UIFigure);
        end
        
        function set.Notebook(app, newNotebook)
            app.Notebook = newNotebook;
            app.onNotebookSet()
        end
    end
    
    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = NoteViewerApp(notes, varargin)

            % Create UIFigure and components
            createComponents(app)
            app.UIFigure.Name = 'Notes';

            app.assignCallbacks()
            try app.createTooltips; end %#ok<TRYNC> % Newer matlab versions only...
            
            app.updateTypeSelectionList()
            
            % Todo: Implement these buttons and their actions.
            app.CreateNoteButton.Enable = 'off';
            app.LockButton.Enable = 'off';
            app.DeleteNoteButton.Enable = 'off';
            
            if nargin == 1
                try
                    app.assignNotebook(notes)
                catch ME
                    delete(app); rethrow(ME)
                end
            else
                app.ListBox.Items = {};
            end
            
            drawnow
            uim.utility.layout.setUiFigureMinSize(app.UIFigure, [700,400])
            
            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
        
    end
    
    % Callbacks that handle component events
    methods (Access = private)

        % Selection changed function: TabButtonGroup
        function TabButtonGroupSelectionChanged(app, ~, ~)
            selectedButton = app.TabButtonGroup.SelectedObject;
            
            switch selectedButton.Tag
                case 'List'
                    app.TabGroup.SelectedTab = app.ListTab;
                case 'Tree'
                    app.TabGroup.SelectedTab = app.TreeTab;
            end
            
        end

        % Button pushed function: SortButton
        function onSortButtonPushed(app, ~, ~)
            
            switch app.SortButton.Tag
                case 'Sort Descend'
                    app.SortButton.Icon =  app.getIcon('Sort Ascend');
                    app.SortButton.Tag = 'Sort Ascend';
                case 'Sort Ascend'
                    app.SortButton.Icon = app.getIcon('Sort Descend');
                    app.SortButton.Tag = 'Sort Descend';
            end
           
            app.updateListItems();
            app.updateTreeOrder();
        end
        
        function onCreateNoteButtonPushed(app, ~, ~)
            % Todo: Implement function
        end
        
        function onLockButtonPushed(app, ~, ~)
            
            switch app.SortButton.Tag
                case 'Locked'
                    app.SortButton.Icon = 'Unlocked.png';
                    app.SortButton.Tag = 'Unlocked';
                case 'Unlocked'
                    app.SortButton.Icon = 'Locked.png';
                    app.SortButton.Tag = 'Locked';
            end
            
        end
        
        function onDeleteNoteButtonPushed(app, ~, ~)
            
        end
        
        function onTreeSelectionChanged(app, src, ~)
            
            selectedTitle = src.SelectedNodes.Text;
            
            allTitles = app.Notebook.getTitleArray;
            noteIdx = find( strcmp(allTitles, selectedTitle) );
            
            if ~isempty(noteIdx)
                app.showNote(noteIdx)
            end
        end
        
        function onListSelectionChanged(app, src, ~)
            
            selectedIdx = find( strcmp(src.Items, src.Value) );
            noteIdx = app.ListBox.UserData.DisplayedIdx(selectedIdx);
            app.showNote(noteIdx)
            
        end
        
        function onSelectTagValueChanged(app, ~, ~)
            app.updateListItems()
            
            % Temp (?): Switch to list tab, because tree is not filtered.
            app.TabGroup.SelectedTab = app.ListTab;
            app.TabButtonGroup.SelectedObject = app.TabButtonGroup.Children(1);
            % Todo: Update tree items
        end
        
        function onSelectTypeValueChanged(app, ~, ~)
            app.updateListItems()
            
            % Temp (?): Switch to list tab, because tree is not filtered.
            app.TabGroup.SelectedTab = app.ListTab;
            app.TabButtonGroup.SelectedObject = app.TabButtonGroup.Children(1);
            % Todo: Update tree items
        end
        
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 700 400];
            app.UIFigure.Name = 'MATLAB App';

            % Create NotePanel
            app.NotePanel = uipanel(app.UIFigure);
            app.NotePanel.BorderType = 'none';
            app.NotePanel.Position = [300 0 400 350];

            % Create NoteTextArea
            app.NoteTextArea = uitextarea(app.NotePanel);
            app.NoteTextArea.Editable = 'off';
            app.NoteTextArea.Position = [10 12 380 280];

            % Create NoteSubtitleLabel
            app.NoteSubtitleLabel = uilabel(app.NotePanel);
            app.NoteSubtitleLabel.Position = [15 298 360 22];
            app.NoteSubtitleLabel.Text = 'Subtitle';

            % Create NoteTitleLabel
            app.NoteTitleLabel = uilabel(app.NotePanel);
            app.NoteTitleLabel.FontWeight = 'bold';
            app.NoteTitleLabel.Position = [15 320 360 22];
            app.NoteTitleLabel.Text = 'Title';

            % Create TabGroup
            app.TabGroup = uitabgroup(app.UIFigure);
            app.TabGroup.Position = [0 0 300 400];

            % Create ListTab
            app.ListTab = uitab(app.TabGroup);
            app.ListTab.Title = 'Tab';

            % Create ListBox
            app.ListBox = uilistbox(app.ListTab);
            app.ListBox.Position = [10 10 280 330];

            % Create TreeTab
            app.TreeTab = uitab(app.TabGroup);
            app.TreeTab.Title = 'Tab2';

            % Create Tree
            app.Tree = uitree(app.TreeTab);
            app.Tree.Position = [10 10 280 330];

            % Create HeaderPanel
            app.HeaderPanel = uipanel(app.UIFigure);
            app.HeaderPanel.BackgroundColor = [0.9412 0.9412 0.9412];
            app.HeaderPanel.Position = [1 350 700 50];

            % Create TabButtonGroup
            app.TabButtonGroup = uibuttongroup(app.HeaderPanel);
            app.TabButtonGroup.BorderType = 'none';
            app.TabButtonGroup.BackgroundColor = [0.9412 0.9412 0.9412];
            app.TabButtonGroup.Position = [4 8 75 30];

            % Create TreeButton
            app.TreeButton = uitogglebutton(app.TabButtonGroup);
            app.TreeButton.Tag = 'Tree';
            app.TreeButton.Icon = app.getIcon('Tree');
            app.TreeButton.Text = '';
            app.TreeButton.Position = [35 1 28 28];

            % Create ListButton
            app.ListButton = uitogglebutton(app.TabButtonGroup);
            app.ListButton.Tag = 'List';
            app.ListButton.Icon =  app.getIcon('List');
            app.ListButton.Text = '';
            app.ListButton.Position = [5 1 28 28];
            app.ListButton.Value = true;

            % Create CreateNoteButton
            app.CreateNoteButton = uibutton(app.HeaderPanel, 'push');
            app.CreateNoteButton.Tag = 'Add Note';
            app.CreateNoteButton.Icon = app.getIcon('Create');
            app.CreateNoteButton.IconAlignment = 'center';
            app.CreateNoteButton.Position = [156 8 28 28];
            app.CreateNoteButton.Text = '';

            % Create SortButton
            app.SortButton = uibutton(app.HeaderPanel, 'push');
            app.SortButton.Tag = 'Sort Ascend';
            app.SortButton.Icon = app.getIcon('Sort Ascend');
            app.SortButton.IconAlignment = 'center';
            app.SortButton.Position = [81 8 28 28];
            app.SortButton.Text = '';

            % Create LockButton
            app.LockButton = uibutton(app.HeaderPanel, 'push');
            app.LockButton.Tag = 'Lock Note';
            app.LockButton.Icon = app.getIcon('Locked');
            app.LockButton.Position = [189 8 28 28];
            app.LockButton.Text = '';

            % Create DeleteNoteButton
            app.DeleteNoteButton = uibutton(app.HeaderPanel, 'push');
            app.DeleteNoteButton.Tag = 'Delete Note';
            app.DeleteNoteButton.Icon = app.getIcon('Delete');
            app.DeleteNoteButton.IconAlignment = 'center';
            app.DeleteNoteButton.Position = [123 8 28 28];
            app.DeleteNoteButton.Text = '';

            % Create SelectTypeLabel
            app.SelectTypeLabel = uilabel(app.HeaderPanel);
            app.SelectTypeLabel.HorizontalAlignment = 'right';
            app.SelectTypeLabel.Position = [304 11 67 22];
            app.SelectTypeLabel.Text = 'Select Type:';

            % Create SelectTypeDropDown
            app.SelectTypeDropDown = uidropdown(app.HeaderPanel);
            app.SelectTypeDropDown.Items = {'Show All'};
            app.SelectTypeDropDown.Position = [376 11 110 22];
            app.SelectTypeDropDown.Value = 'Show All';

            % Create SelectTagLabel
            app.SelectTagLabel = uilabel(app.HeaderPanel);
            app.SelectTagLabel.HorizontalAlignment = 'right';
            app.SelectTagLabel.Position = [510 11 61 22];
            app.SelectTagLabel.Text = 'Select Tag:';

            % Create SelectTagDropDown
            app.SelectTagDropDown = uidropdown(app.HeaderPanel);
            app.SelectTagDropDown.Items = {'Show All'};
            app.SelectTagDropDown.Position = [576 11 110 22];
            app.SelectTagDropDown.Value = 'Show All';

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
        


        function assignCallbacks(app)
            
            % Buttons:
            app.SortButton.ButtonPushedFcn          = @app.onSortButtonPushed;
            app.CreateNoteButton.ButtonPushedFcn    = @app.onCreateNoteButtonPushed;
            app.LockButton.ButtonPushedFcn          = @app.onLockButtonPushed;
            app.DeleteNoteButton.ButtonPushedFcn    = @app.onDeleteNoteButtonPushed;
            
            app.TabButtonGroup.SelectionChangedFcn  = @app.TabButtonGroupSelectionChanged;
            
            % List and tree:
            app.Tree.SelectionChangedFcn            = @app.onTreeSelectionChanged;
            app.ListBox.ValueChangedFcn             = @app.onListSelectionChanged;
            
            % Dropdown menus:
            app.SelectTagDropDown.ValueChangedFcn   = @app.onSelectTagValueChanged;
            app.SelectTypeDropDown.ValueChangedFcn  = @app.onSelectTypeValueChanged;
            
            % Figure:
            % app.UIFigure.SizeChangedFcn             = @app.onFigureResized;

        end
        
        function createTooltips(app)
        %createTooltips Create tooltips for components
        %
        % These are in separate method because older versions of matlab 
        % did not support tooltips for uifigure components.
        
            app.TreeButton.Tooltip = {'Show Group'};
            app.ListButton.Tooltip = {'Show List'};
            app.LockButton.Tooltip = {'Lock Note'};
            app.CreateNoteButton.Tooltip = {'Create Note'};
            app.DeleteNoteButton.Tooltip = {'Delete Note'};

        end
    end
    
    % App component update
    methods (Access = protected)

        function onFigureResized(app, ~, ~)% Not In Use
        %onFigureResized Callback for figure size changed events
        %
        %   Note, this is not used. Figure is autoresizing children.
        
            figurePosition = app.UIFigure.Position;
            
            % Set position of header panel
            app.HeaderPanel.AutoResizeChildren = 'off';
            app.HeaderPanel.Position(2) = figurePosition(4) - app.HeaderHeight;
            app.HeaderPanel.Position(3) = figurePosition(3) + 100; 
            
            % Set heights for tabgroup and note panel
            app.TabGroup.Position(4) = figurePosition(4);
            app.NotePanel.Position(4) = figurePosition(4) - app.HeaderHeight;
            
            % Calculate widths for tabgroup and note panel
            W = figurePosition(3) .* app.MainPanelWidth;
            app.TabGroup.Position(3) = W(1);
            app.NotePanel.Position(3) = W(2);
            app.NotePanel.Position(1) = W(1);
            
            app.ListBox.Position(4) = figurePosition(4) - app.HeaderHeight;
            app.Tree.Position(4) = figurePosition(4) - app.HeaderHeight;
            
        end
        
        function onNotebookSet(app)
            
            app.updateListItems()
            app.updateTreeItems()
            
            app.updateTagSelectionList()
            
        end
        
        function updateTagSelectionList(app)
        %updateTagSelectionList Update items in tag selection dropdown    
            items = ['Show All', app.Notebook.getAllTags() ];
            if ischar(items); items = {items}; end
            app.SelectTagDropDown.Items = items;
            
        end
        
        function updateTypeSelectionList(app)
        %updateTypeSelectionList Update items in type selection dropdown    
            items = ['Show All', nansen.notes.Note.VALID_NOTE_TYPES];
            app.SelectTypeDropDown.Items = items;
        end
        
        function updateListItems(app)
        %updateListItems Update items in list.        
            
            dateStrArray = app.Notebook.getFormattedDate('[yyyy.MM.dd]');
            titleStrArray = app.Notebook.getTitleArray();
            
            numNotes = app.Notebook.NumNotes;
            makeLabel = @(i) sprintf('%s - %s', dateStrArray(i,:), titleStrArray{i});
            noteTitle = arrayfun(@(i) makeLabel(i), 1:numNotes, 'uni', 0 );
            
            % Get sort direction
            sortDirection = app.getSortDirection;
            sortIdx = app.Notebook.getSortIdx('DateTime', sortDirection);
            
            % Check the type filter
            selectedType = app.getSelectedType();
            if ~isempty(selectedType)
                idx = app.Notebook.getTypeMatch(selectedType);
                sortIdx = intersect(sortIdx, idx, 'stable');
            end
            
            % Check the tag filter
            selectedTag = app.getSelectedTag();
            if ~isempty(selectedTag)
                idx = app.Notebook.getTagMatch(selectedTag);
                sortIdx = intersect(sortIdx, idx, 'stable');
            end
            
            % Get titles to display in the right order
            noteTitle = noteTitle(sortIdx);

            if isempty(sortIdx)
                app.ListBox.Items = {};
                app.clearNote()
                return
            end

            % Update listbox component items and values
            app.ListBox.Items = noteTitle;
            app.ListBox.Value = noteTitle{1};
            
            % Store the indices (and order) of items that are displayed
            app.ListBox.UserData.DisplayedIdx = sortIdx;
            
            % Update displayed note if list view is active
            if isequal(app.TabButtonGroup.SelectedObject, app.ListButton)
                app.showNote(sortIdx(1))
            end
            
        end
        
        function updateTreeItems(app)
            
            objectIDs = app.Notebook.getObjectIds();
            
            uniqueIDs = unique(objectIDs, 'sorted');
            
            % Make sure groups are sorted the right way.
            if strcmp(app.getSortDirection(), 'descend')
                uniqueIDs = fliplr(uniqueIDs);
            end
            
            if ~isempty(app.Tree.Children)
                delete(app.Tree.Children)
                app.Tree.Children = [];
            end
            
            noteTitles = app.Notebook.getTitleArray();
            
            sortDirection = app.getSortDirection();
            sortIdx = app.Notebook.getSortIdx('DateTime', sortDirection);
            
            for iNode = 1:numel(uniqueIDs)
                node = uitreenode(app.Tree);
                node.Text = uniqueIDs{iNode};
                
                nodeIdx = find(strcmp(objectIDs, uniqueIDs{iNode}));
                nodeIdx = intersect(sortIdx, nodeIdx, 'stable');

                for jNote = nodeIdx
                    subnode = uitreenode(node);
                    subnode.Text = noteTitles{jNote};
                end
                
            end

        end
        
        function updateTreeOrder(app)
        %updateTreeOrder Update order of tree nodes (i.e when sorting).
        %
        %   Note: This is a quick solution. Could be improved upon if 
        %   anyone finds it necessary.
            nodeIdx = 1:numel(app.Tree.Children);
            app.Tree.Children = app.Tree.Children(fliplr(nodeIdx));
            
        end
        
        function sortList(app, sortDirection)
            %Todo
        end
        
        function sortTree(app, sortDirection)
            %Todo
        end
        
        function filterList(app, properyName, value)
            %Todo
        end
        
        function filterTree(app, properyName, value)
            %Todo
        end
        
        function resetListFilter(app)
            %Todo
        end
        
        function resetTreeFilter(app)
            %Todo
        end
        
        function showNote(app, noteIdx)
            
            % Update note header
            noteObject = app.Notebook.getNoteArray(noteIdx);
            app.NoteTitleLabel.Text = noteObject.Title;
            
            subtitle = strjoin({noteObject.ObjectID, char(noteObject.DateTime), noteObject.Author}, ' | ');
            
            app.NoteSubtitleLabel.Text = subtitle;
            
            % Update note text
            app.NoteTextArea.Value = sprintf( noteObject.Text );
        end
        
        function clearNote(app)
            
            app.NoteTitleLabel.Text = '';
            app.NoteSubtitleLabel.Text = '';
            
            % Update note text
            app.NoteTextArea.Value = '';
            
        end
        
        function hideApp(app)
            app.UIFigure.Visible = 'off';
        end
        
    end
    
    methods % Get states from component values
        
        function sortDirection = getSortDirection(app)
            switch app.SortButton.Tag
                case 'Sort Descend'
                    sortDirection = 'descend';
                case 'Sort Ascend'
                    sortDirection = 'ascend';
            end
        end
        
        function selectedType = getSelectedType(app)
            selectedType = app.SelectTypeDropDown.Value;
            if strcmp(selectedType, 'Show All')
                selectedType = [];
            end
        end
        
        function selectedTag = getSelectedTag(app)
            selectedTag = app.SelectTagDropDown.Value;
            if strcmp(selectedTag, 'Show All')
                selectedTag = [];
            end
        end

    end
    
    methods % Public methods
        
        function openNotebook(app, notes)
            app.assignNotebook(notes)
            figure(app.UIFigure)
        end
        
        function assignNotebook(app, notes)
        %assignNotebook Assign notebook in various forms.    
            
            if isa(notes, 'nansen.notes.Note')
                app.Notebook = nansen.notes.NoteBook( notes );
            elseif isa(notes, 'nansen.notes.NoteBook')
                app.Notebook = notes;
            elseif isa(notes, 'struct')
                app.Notebook = nansen.notes.NoteBook( notes );
            else
                errorId = 'Nansen:NoteViewerApp:InvalidInput';
                errorMsg = 'Notes input must be an array of Note objects, a struct of Note objects or a Notebook.';
                throw(MException(errorId, errorMsg))
            end
        end
        
        function transferOwnership(app, ownerApp)
        %transferOwnership Transfer ownership of app to another app   
            
        % App (figure) deletion is now controlled by another app. If figure
        % window is closed, the figure is not deleted, just made invisible
        
            app.UIFigure.CloseRequestFcn = @(s,e) app.hideApp;
            addlistener(ownerApp, 'ObjectBeingDestroyed', @(s,e) app.delete);
            
        end
        
        function setClosePolicy(app, mode)
            
            switch mode
                case 'hide'
                    app.UIFigure.CloseRequestFcn = @(s,e) app.hideApp;
                case {'close', 'delete'}
                    app.UIFigure.CloseRequestFcn = @(s,e) app.delete();
            end
                    
        end
        
%         function tf = isvalid(app)
%             tf = isvalid(app.UIFigure);
%         end
    end
    
    methods (Static)
        
        function iconPath = getIcon(iconName)

            persistent buttonIconDir
            if isempty(buttonIconDir)
                buttonIconDir = fullfile(fileparts(mfilename('fullpath')), 'uiicons');
            end
            
            iconPath = fullfile(buttonIconDir, [iconName, '.png']);

        end
    end
end