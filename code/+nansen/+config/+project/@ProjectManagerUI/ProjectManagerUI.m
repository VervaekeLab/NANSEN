classdef ProjectManagerUI < handle
%ProjectManagerUI - UI interface for project manager.
%
%   This class manages the graphical user interface for the project
%   manager. It creates ui controls, validates input data and responds to
%   user interactions.
    
    % Todo:
    %   [ ] Flag for whether to create tabs or not (should not create on setup?)
    %   [ ] Only disable create new project controls if this is the initial setup...
    %   [v] Add a context menu on the table. 
    %   [v] Add boolean column to table. Configure it like a
    %       radiobuttongroup... Use for selecting current project.
    %   [ ] Add menu item for editing preferences
    
    properties
        ProjectManager
        ProjectRootFolderPath
    end
    
    properties (Access = protected) % UI Components
        hParent
        MainGridLayout
        TabGroup
        TabList = gobjects(0)
        UIControls struct = struct
        UILabels struct = struct
    end
    
    properties (Access = protected) % Internal configurations
        ActiveRow = []
        SelectedRow = []
        SelectedRowBgColor = [74,86,99]/255
        SelectedRowFgColor = [234,236,237]/255
    end
    
    methods % Constructor
        
        function obj = ProjectManagerUI(hParent)
            
            obj.assignInitialProjectRootFolderPath()

            userSession = nansen.internal.user.NansenUserSession.instance();
            obj.ProjectManager = userSession.getProjectManager();

            % If no parent is added, return before creating components
            if nargin < 1 || isempty(hParent)
                return
            else
                obj.hParent = hParent;
            end
            
            % Create tabs
            obj.createTabGroup()
            obj.createUiControls()
            obj.createProjectTable()
        end
    end
    
    methods % Public methods
        
        function tf = isProjectInformationEntered(obj)
            tf = ~isempty(obj.UIControls.ProjectShortNameInput.Value);
        end
        
        function tf = wasProjectCreated(obj)
            tf = strcmp(obj.UIControls.CreateNewProjectButton.Enable, 'off');
        end
        
        function [success, projectName] = addExistingProject(obj)
        %addExistingProject Add existing project from file
            
            success = false;
            
            hFigure = ancestor(obj.hParent, 'figure');
            if ~isempty(hFigure)
                answer = uiconfirm(hFigure, 'Please select a project folder', ...
                    'Import project', 'Options', 'Ok'); %#ok<NASGU>
                % Minimize figure, because folder dialog appear below figure
                hFigure.WindowState = 'minimized';
            end

            folderPath = uigetdir(obj.ProjectRootFolderPath);
            
            % Bring figure back to view
            if ~isempty(hFigure)
                hFigure.WindowState = 'normal';
                figure( hFigure )
            end

            if folderPath == 0
                return
            end
            
            if ~isempty(hFigure)
                progressDlg = uiprogressdlg(hFigure, ...
                    'Message', 'Importing project...', ...
                    'Title', 'Please wait!', ...
                    'Indeterminate', 'on');
                progressDialogCleanup = onCleanup(@() delete(progressDlg));
            end

            try
                projectName = obj.ProjectManager.importProject(folderPath);
                success = ~isempty( projectName );
            catch ME
                obj.uialert(ME.message, 'Failed to add project', 'error')
                throw(ME)
            end

            % Todo: If there is no current project, make current project...
            if isempty( obj.ProjectManager.CurrentProject )
                obj.ProjectManager.changeProject(projectName);
            end
            obj.updateProjectTableData()
            
            if ~nargout
                clear success projectName
            elseif nargout == 1
                clear projectName
            end
        end
        
        function createProject(obj)
        % createProject - Validate entered information and create new project
           
        % Question: Does this method have to be public?

            projectDescription = obj.UIControls.ProjectName.Value;
            projectShortName = obj.UIControls.ProjectShortNameInput.Value;
            projectFolderPath = obj.UIControls.ProjectPathInput.Value;
            
            isValidProjectName = isvarname(projectShortName);
            
            if ~isValidProjectName
                if isempty(projectShortName)
                    message = 'Please enter a name for the project';
                    title = 'Project Name Missing';
                else
                    message = 'Project short name can only consist of letters, numbers and underscores';
                    title = 'Invalid Project Name';
                end
                
                obj.uialert(message, title)
                return
            end
    
% %             if isempty(projectLongName)
% %                 message = 'Please enter a name for project';
% %                 title = 'Project Name Missing';
% %
% %                 % app.displayMessage(message, true)
% %                 obj.uialert(message, title)
% %                 return
% %
% %             end

            if isempty(projectFolderPath)
                message = 'Please enter a directory for saving project metadata';
                title = 'Project Path Missing';
                
                obj.uialert(message, title)
                return
            end

            if strcmp(obj.UIControls.CreateNewProjectButton.Text, 'Create New Project')
                
                % Todo: Check that project does not exist...
                                
                % Create new project
                args = {projectShortName, projectDescription, projectFolderPath};
                
                try
                    obj.ProjectManager.createProject(args{:})
                catch ME
                    title = 'Project Creation Failed';
                    obj.uialert(ME.message, title)
                    rethrow(ME)
                end

                % Should this be triggered by a listener on ProjectManager
                % for ProjectCreatedEvent? Todo: set up that event.
                obj.updateProjectTableData()
                
                % Disable controls for creating new project
                % Todo: only do this during the initial setup
                obj.disableCreateNewProjectControls()
            end
        end
        
        function uialert(obj, message, title, alertType)
            
            VALID_ALERT_TYPES = {'info', 'warning', 'error', 'success'};
            
            if nargin < 4
                alertType = 'info';
            end
            
            alertType = validatestring(alertType, VALID_ALERT_TYPES);
            
            hFig = ancestor(obj.hParent, 'figure');
            uialert(hFig, message, title, 'Icon', alertType)
        end
    end
    
    methods (Access = protected) % Component creation
        
        function createTabGroup(obj)
            obj.MainGridLayout = uigridlayout(obj.hParent);
            obj.MainGridLayout.ColumnWidth = {'1x'};
            obj.MainGridLayout.RowHeight = {'1x'};
            obj.MainGridLayout.Padding = 0;

            tabNames = {'Create New Project', 'Add Existing Project', 'Manage Projects'};
            
            obj.TabGroup = uitabgroup(obj.MainGridLayout);
            obj.TabGroup.SelectionChangedFcn = @obj.TabGroupSelectionChanged;
            
            for i = 1:numel(tabNames)
                obj.TabList(i) = uitab(obj.TabGroup);
                obj.TabList(i).Title = tabNames{i};
            end
            
            set(obj.TabList, 'BackgroundColor', 'w')
        end
        
        function createUiControls(obj)
            
            % Use gridlayout for better positioning of components
            uigrid = uigridlayout(obj.TabList(1));
            uigrid.ColumnWidth = {'1x',170, '1x'};
            uigrid.RowHeight = {120, '1x', 34, '3x'};
            uigrid.RowSpacing = 10;
            uigrid.BackgroundColor = "white";

            controlPanel = uipanel(uigrid, "BorderType", "none");
            controlPanel.Layout.Column = [1,3];
            controlPanel.Layout.Row = 1;
            controlPanel.BackgroundColor = "white";

            y0 = 20;

            % Create ChangeProjectFolderButton
            obj.UIControls.BrowseButton = uibutton(controlPanel, 'push');
            obj.UIControls.BrowseButton.ButtonPushedFcn = @obj.ChangeProjectFolderButtonPushed;
            obj.UIControls.BrowseButton.BackgroundColor = [1 1 1];
            obj.UIControls.BrowseButton.FontName = 'Segoe UI';
            obj.UIControls.BrowseButton.FontWeight = 'bold';
            obj.UIControls.BrowseButton.Position = [525 y0 100 25];
            obj.UIControls.BrowseButton.Text = 'Change Folder';
            
            % Create label and input field for the project name
            obj.UILabels.ProjectName = uilabel(controlPanel);
            obj.UILabels.ProjectName.FontName = 'Segoe UI';
            obj.UILabels.ProjectName.FontWeight = 'bold';
            obj.UILabels.ProjectName.Visible = 'off';
            obj.UILabels.ProjectName.Position = [332 163 174 22];
            obj.UILabels.ProjectName.Text = 'Give the project a description';

            obj.UIControls.ProjectName = uieditfield(controlPanel, 'text');
            obj.UIControls.ProjectName.Visible = 'off';
            obj.UIControls.ProjectName.Position = [336 141 279 22];
            
            % Create label for the project path input field
            obj.UILabels.ProjectPathInput = uilabel(controlPanel);
            obj.UILabels.ProjectPathInput.FontName = 'Segoe UI';
            obj.UILabels.ProjectPathInput.FontWeight = 'bold';
            obj.UILabels.ProjectPathInput.Position = [31 y0+22 250 22];
            obj.UILabels.ProjectPathInput.Text = 'Local path (to save project configurations)';

            % Create control for the project path input field
            obj.UIControls.ProjectPathInput = uieditfield(controlPanel, 'text');
            obj.UIControls.ProjectPathInput.Position = [29 y0+1 489 22];
            
            y0 = 72;
            
            % Create label and input field for the project short name
            hLabel = uilabel(controlPanel);
            hLabel.FontName = 'Segoe UI';
            hLabel.FontWeight = 'bold';
            hLabel.Position = [31 y0+22 158 22];
            hLabel.Text = 'Enter a short project name';
            
            hEditField = uieditfield(controlPanel, 'text');
            hEditField.ValueChangedFcn = @obj.ProjectLabelEditFieldValueChanged;
            hEditField.ValueChangingFcn = @obj.ProjectLabelEditFieldValueChanging;
            hEditField.FontName = 'Segoe UI';
            hEditField.FontWeight = 'bold';
            hEditField.Position = [29 y0 169 22];
            
            % Set tooltips (no tooltip prop in older versions of matlab)
            try
                hLabel.Tooltip = {'(a-z, A-Z, 1-9, _)'};
                hEditField.Tooltip = {'(a-z, A-Z, 1-9, _)'};
            end
            
            obj.UILabels.ProjectShortNameInput = hLabel;
            obj.UIControls.ProjectShortNameInput = hEditField;
            
            % Create CreateNewProjectButton
            obj.UIControls.CreateNewProjectButton = uibutton(uigrid, 'push');
            obj.UIControls.CreateNewProjectButton.ButtonPushedFcn = @obj.CreateNewProjectButtonValueChanged;
            obj.UIControls.CreateNewProjectButton.FontSize = 14;
            obj.UIControls.CreateNewProjectButton.FontWeight = 'bold';
            obj.UIControls.CreateNewProjectButton.Layout.Column = 2;
            obj.UIControls.CreateNewProjectButton.Layout.Row = 3;
            %obj.UIControls.CreateNewProjectButton.Position = [265 27 170 34];
            obj.UIControls.CreateNewProjectButton.Text = 'Create New Project';

            % Create controls on the Add Existing Project tab page
            tabIdx = strcmp({obj.TabList.Title}, 'Add Existing Project');
            
            uigrid = uigridlayout(obj.TabList(tabIdx));
            uigrid.ColumnWidth = {'1x', 170, '1x'};
            uigrid.RowHeight = {'2x', 34, '3x'};
            uigrid.BackgroundColor = "white";

            hButton = uibutton(uigrid, 'push');
            hButton.Layout.Row = 2;
            hButton.Layout.Column = 2;
            hButton.Text = 'Add Existing Project';
            hButton.ButtonPushedFcn = @obj.onAddExistingProjectButtonPushed;
            hButton.FontWeight = 'bold';
            
            obj.UIControls.AddExistingButton = hButton;
            %uim.utility.layout.centerObjectInRectangle(hButton, obj.TabList(tabIdx))
            
            tabIdx = strcmp({obj.TabList.Title}, 'Manage Projects');
            
            obj.UIControls.ProjectTable = uitable(obj.TabList(tabIdx));
            obj.UIControls.ProjectTable.Position = [10,10,530,200];
        end
        
        function createProjectTable(obj)
            
            obj.updateProjectTableData()
            
            obj.UIControls.ProjectTable.ColumnWidth = {65, 100, 100, 200, 500};
            obj.UIControls.ProjectTable.ColumnEditable = [true,false,false,true,false];
            obj.UIControls.ProjectTable.CellEditCallback = @obj.onTableCellEdited;

            obj.setProjectTablePosition()
        end
        
        function updateProjectTableData(obj)
        %updateProjectTableData Update data in the uitable
        
            if isempty(obj.ProjectManager.Catalog); return; end
            if ~isfield(obj.UIControls, 'ProjectTable'); return; end
        
            T = struct2table(obj.ProjectManager.Catalog, 'AsArray', true);
            
            % Add column to indicate current/active project
            currentProjectName = obj.ProjectManager.CurrentProject;
            isCurrent = strcmp(T.Name, currentProjectName);
            tableColumn = table(isCurrent, 'VariableNames', {'Current'});
            
            T = [tableColumn, T];
            
            try
                obj.UIControls.ProjectTable.Data = T;
                
            catch
                obj.UIControls.ProjectTable.Data = table2cell(T);
                obj.UIControls.ProjectTable.ColumnName = T.Properties.VariableNames;
            end
            
            try % Only available in newer matlab versions...
                if any(isCurrent)
                    obj.setRowStyle('Current Project', find(isCurrent))

                    s = uistyle('FontWeight', 'bold');
                    addStyle(obj.UIControls.ProjectTable, s, 'row', find(isCurrent));
                end
                if isempty(obj.UIControls.ProjectTable.UIContextMenu)
                    obj.createTableContextMenu()
                end
            catch
                warning('Some features of the project table are not created properly. Matlab 2018b or newer is required.')
            end
            
            if isempty(obj.UIControls.ProjectTable.CellSelectionCallback)
                obj.UIControls.ProjectTable.CellSelectionCallback = @obj.onTableCellSelected;
            end
        end
        
        function setProjectTablePosition(obj)
        %setProjectTablePosition Position the table within the UI
        
            margin = 10;
            drawnow
            pause(0.05)

            parentPosition = obj.TabList(2).InnerPosition;
            %tablePosition = parentPosition + [1, 1, -2, -2] * margin;
            %obj.UIControls.ProjectTable.Position = tablePosition;
        end
        
        function createTableContextMenu(obj)
            
            cMenu = uicontextmenu(ancestor(obj.hParent, 'figure'));
            
            contextMenuItemNames = {...
                'Set current project', ...
                'Remove project', ...
                'Delete project', ...
                'Update project folder location', ...
                'Open project folder', ...
                'Open project folder in MATLAB'};
            
            hMenuItem = gobjects(numel(contextMenuItemNames), 1);
            for i = 1:numel(contextMenuItemNames)
                hMenuItem(i) = uimenu(cMenu, 'Text', contextMenuItemNames{i});
                hMenuItem(i).Callback = @obj.onContextMenuItemClicked;
            end
            set(hMenuItem([2,5]), 'Separator', 'on')
            
            obj.UIControls.ProjectTable.UIContextMenu = cMenu;
        end
        
        function disableCreateNewProjectControls(obj)

            % Disable all input fields.
            obj.UIControls.ProjectName.Enable = 'off';
            obj.UIControls.ProjectShortNameInput.Enable = 'off';
            obj.UIControls.ProjectPathInput.Enable = 'off';
            obj.UIControls.BrowseButton.Enable = 'off';

            % Change appearance of "create project" button
            obj.UIControls.CreateNewProjectButton.Text = 'Project Created!';
            obj.UIControls.CreateNewProjectButton.BackgroundColor = [0.47,0.87,0.19];
            obj.UIControls.CreateNewProjectButton.Enable = 'off';
        end
    end

    methods (Access = ?nansen.config.project.ProjectManagerApp)
        function resizeComponents(obj)
            

        end
    end
    
    methods (Access = protected) % Project context menu action handlers
        
        function changeProject(obj, rowIdx)
        % changeProject - Changes the current project
            projectName = obj.getNameFromRowIndex(rowIdx);
            
            try
                obj.ProjectManager.changeProject(projectName);
                msg = sprintf('Current NANSEN project was changed to "%s".', projectName);
                obj.uialert(msg, 'Changed Project', 'success')
            catch ME
                obj.uialert(ME.message, 'Failed to Change Project')
                return
            end
            
            try % Note: Does not work in older versions of matlab
                obj.setRowStyle('Current Project', rowIdx)
                obj.UIControls.ProjectTable.Data(:, 'Current') = {false};
                obj.UIControls.ProjectTable.Data(rowIdx, 'Current') = {true};
            catch
                obj.UIControls.ProjectTable.Data(:, 1) = {false};
                obj.UIControls.ProjectTable.Data(rowIdx, 1) = {true};
            end
        end
        
        function updateProjectDirectory(obj, rowIdx, newProjectDirectory)
            projectName = obj.getNameFromRowIndex(rowIdx);
            if ~isequal(projectName, 0)
                obj.ProjectManager.updateProjectDirectory(projectName, newProjectDirectory)
                obj.UIControls.ProjectTable.Data(rowIdx, 'Path') = {newProjectDirectory};
            end
        end
        
        function deleteProject(obj, rowIdx)
        % deleteProject - Delete project from project manager and project table
        %
        % NB: This removes the project and deletes the project files from disk.

            projectName = obj.getNameFromRowIndex(rowIdx);
            
            % Display message
            hFig = ancestor(obj.hParent, 'figure');
            message = sprintf(['This action will remove the project "%s" ', ...
                'and delete all the project data. Are you sure you want ', ...
                'to continue?'], projectName);
            title = 'Confirm Delete';
            opts = {'Options', {'Delete Project', 'Cancel'}};
            selection = uiconfirm(hFig, message, title, opts{:});
            
            switch selection
                case 'Delete Project'
                    % Call removeProject with flag for deleting project folder
                    obj.removeProject(rowIdx, true)
                otherwise
                    % Cancel
            end
        end
        
        function removeProject(obj, rowIdx, deleteFolder)
        % removeProject - Remove project from project manager and project table
        %
        %   NB: This does not delete the project files from disk unless
        %   deleteFolder is set to true.

            if nargin < 3
                deleteFolder = false;
            end
            
            projectName = obj.getNameFromRowIndex(rowIdx);
            
            % Remove project before removing table row
            % (In case project can not be removed)
            try
                obj.ProjectManager.removeProject(projectName, deleteFolder);
                % Remove row in uitable
                obj.UIControls.ProjectTable.Data(rowIdx, :) = [];
            catch ME
                obj.uialert(ME.message, 'Project Not Removed', 'error')
            end
        end
        
        function openProjectFolder(obj, rowIdx)
        % Open project folder in operating system i.e Finder or Explorer

            folderPath = obj.UIControls.ProjectTable.Data{rowIdx, 'Path'};
            utility.system.openFolder(folderPath{1})
        end

        function openProjectFolderInMatlab(obj, rowIdx)
            folderPath = obj.UIControls.ProjectTable.Data{rowIdx, 'Path'};
            cd(folderPath{1})
        end

        function uiLocateProjectFolder(obj, rowIdx)
            folderPath = uigetdir();
            if ~isequal(folderPath, 0)
                obj.updateProjectDirectory(rowIdx, folderPath)
            end
        end

        function setRowStyle(obj, styleType, rowIdx)
        %setRowStyle Set style on row according to type
        %
        %
        %   Only one style of each type are allowed at any time, so if the
        %   style already exists it is removed before it is added again.
        
            % Remove this style type if it exists on another row
            sConfig = obj.UIControls.ProjectTable.StyleConfigurations;
            
            switch styleType
                case 'Selected Row'
                    s = uistyle('BackgroundColor', obj.SelectedRowBgColor,...
                        'FontColor', obj.SelectedRowFgColor);
                case 'Current Project'
                    s = uistyle('FontWeight', 'bold');
            end
            
            isStyleActive = arrayfun(@(h) isequal(s, h), sConfig.Style);
            if any(isStyleActive)
                removeStyle(obj.UIControls.ProjectTable, find(isStyleActive))
            end
            
            addStyle(obj.UIControls.ProjectTable, s, 'row', rowIdx);
        end
        
        function name = getNameFromRowIndex(obj, rowIndex)
        %getNameFromRowIndex Get name of project from row index
            
            try
                name = obj.UIControls.ProjectTable.DisplayData{rowIndex, 'Name'};    % Name column index = 2
                if iscell(name)
                    name = name{1};
                end
                
            catch % DisplayData not available in older versions of matlab.
                name = obj.UIControls.ProjectTable.Data{rowIndex, 2};
            end
            
            if iscell(name)
                name = name{1};
            end
        end
    end

    methods (Access = protected) % UIControl callbacks
       
        % Button pushed function: ChangeProjectFolderButton
        function ChangeProjectFolderButtonPushed(obj, ~, ~)
        %   Lets user select a folder to save project files to.
        
            import nansen.config.project.uisetProjectFolder
            
            % Get values from UIControls and assign to local variables
            currentProjectPath = obj.UIControls.ProjectPathInput.Value;
            projectShortName = obj.UIControls.ProjectShortNameInput.Value;
            
            currentRootFolder = fileparts(currentProjectPath);

            % Call function that's asks user to interactively select a new folder
            newFolder = uisetProjectFolder(currentRootFolder, projectShortName);

            % Bring ui figure back into focus.
            figure( ancestor(obj.hParent, 'figure') )
            
            % Return if user canceled / update the folderpath ui control
            if newFolder == 0
                return;
            else
                obj.UIControls.ProjectPathInput.Value = newFolder;
            end
            
            % Set current project root folder (This is added to prefs in
            % uisetProjectFolder if it was changed)
            obj.ProjectRootFolderPath = getpref('NansenSetup', 'DefaultProjectPath');
        end
        
        % Button pushed function: CreateNewProjectButton
        function CreateNewProjectButtonValueChanged(obj, ~, ~)
            obj.createProject()
        end
        
        % Value changed function: ProjectLabelEditField
        function ProjectLabelEditFieldValueChanged(obj, ~, event)
            
            projectOldName = event.PreviousValue;
            
            % Get the project name and current path
            projectNewName = obj.UIControls.ProjectShortNameInput.Value;
            currentProjectPath = obj.UIControls.ProjectPathInput.Value;
            
            % Make sure its a valid name (letters/numbers/underscore only)
            isNameValid = isvarname(projectNewName);
            
            if isempty(projectNewName) || isNameValid
                return
                
            elseif ~isNameValid
                msg = 'Project name can only consist of letters, numbers and underscores';
                obj.uialert(msg, 'Invalid input')

                obj.UIControls.ProjectShortNameInput.Value = '';
                projectOldName = projectNewName;
                projectNewName = '';
            end
            
            % Update/create the project path based on new name selection
            projectFolder = nansen.config.project.autoUpdateProjectPath(...
                projectNewName, projectOldName, currentProjectPath);
            
            % Update the value of the local path field
            obj.UIControls.ProjectPathInput.Value = projectFolder;
        end

        % Value changing function: ProjectLabelEditField
        function ProjectLabelEditFieldValueChanging(obj, ~, event)
            changingValue = event.Value;
            
            % Dynamically update the project folder path
            obj.UIControls.ProjectPathInput.Value = fullfile(obj.ProjectRootFolderPath, changingValue);
            obj.UIControls.ProjectPathInput.Tooltip = obj.UIControls.ProjectPathInput.Value;
        end

        % Tab selection changed function: TabGroupSelectionChanged
        function TabGroupSelectionChanged(obj, ~, event)
            
            switch event.NewValue.Title
                case 'Manage Projects'
                    obj.setProjectTablePosition()
                    if isempty(obj.ProjectManager.Catalog)
                        obj.TabGroup.SelectedTab = obj.TabList(1);
                        msg = 'No projects are available, please create a project first.';
                        title = 'No Projects Available';
                        obj.uialert(msg, title)
                    end
            end
        end
        
        function onTableCellSelected(obj, ~, evt)
        %onTableCellSelected Change selected row
            
            if isprop(evt, 'Indices')
                displayIndices = evt.Indices;
            elseif isprop(evt, 'DisplayIndices')
                displayIndices = evt.DisplayIndices;
            end
        
            if isempty(displayIndices)
                obj.SelectedRow = [];
                return
            end
        
            obj.SelectedRow = displayIndices(1);
            try % Does not work for older MATLAB version
                obj.setRowStyle('Selected Row', displayIndices(1))
            end
        end
        
        function onTableCellEdited(obj, src, evt)
            
            rowIdx = evt.Indices(1); colIdx = evt.Indices(2);

            if colIdx == 3 % Description
                % Save project data...
                obj.ProjectManager.updateProjectItem(rowIdx, 'Description', evt.NewData);

            elseif colIdx == 1
                if evt.NewData
                    obj.changeProject(rowIdx)
                else
                    src.Data(rowIdx, 1) = {true};
                end
            else
                error('Could not update data in column %d', colIdx)
            end
        end
        
        function onContextMenuItemClicked(obj, src, ~)
            
            if isempty(obj.SelectedRow)
                msg = 'No project is selected. Please select a project and try again.';
                obj.uialert(msg, 'No project is selected', 'error')
                return
            end
            
            switch src.Text
                case 'Set current project'
                    obj.changeProject(obj.SelectedRow)

                case 'Remove project'
                    obj.removeProject(obj.SelectedRow)
                    
                case 'Delete project'
                    obj.deleteProject(obj.SelectedRow)
                    
                case 'Open project folder'
                    obj.openProjectFolder(obj.SelectedRow)

                case 'Open project folder in MATLAB'
                    obj.openProjectFolderInMatlab(obj.SelectedRow)

                case 'Update project folder location'
                    obj.uiLocateProjectFolder(obj.SelectedRow)
            end
        end
       
        function onAddExistingProjectButtonPushed(obj, src, evt)
            try
                obj.addExistingProject()
                obj.uialert('Project successfully added', 'info')
            catch ME
                obj.uialert(ME.message, "Failed to add project", 'error')
            end
        end
    end

    methods (Access = private)
        
        function assignInitialProjectRootFolderPath(obj)
            % Set default value of path for project root folder
            defaultProjectFolder = nansen.common.constant.DefaultProjectPath;
            % Get value from preferences. Todo: use user session preferences
            projectFolder = getpref('NansenSetup', 'DefaultProjectPath', defaultProjectFolder);
            obj.ProjectRootFolderPath = projectFolder;
        end
    end
end
