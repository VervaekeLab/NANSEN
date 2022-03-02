classdef ProjectManagerUI < handle

    
    % Todo:
    %   [ ] Flag for whether to create tabs or not (should not create on setup?)
    %   [ ] Only disable create new project controls if this is the initial setup...
    %   [ ] Add a context menu on the table. 
    %   [ ] Add boolean column to table. Configure it like a
    %       radiobuttongroup... Use for selecting current project.
    
    properties
        ProjectManager
        ProjectRootFolderPath
    end
    
    properties (Access = protected) % UI Components
        hParent
        
        TabGroup
        TabList = gobjects(0)
        UIControls struct = struct
        UILabels struct = struct
    end
    
    properties (Access = protected)
        ActiveRow = []
        SelectedRow = []
        SelectedRowBgColor = [74,86,99]/255
        SelectedRowFgColor = [234,236,237]/255
    end
    
    events
        ProjectCreated
        ProjectChanged
    end

    methods
        
        function obj = ProjectManagerUI(hParent)
            
            obj.assignInitialProjectRootFolderPath()
            obj.ProjectManager = nansen.config.project.ProjectManager();
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
        
        function addExistingProject(obj)
        %addExistingProject Add existing project from file
        
            [fileName, folder] = uigetfile(obj.ProjectRootFolderPath);
            
            if fileName == 0
                return
            end
            
            try
                filePath = fullfile(folder, fileName);
                obj.ProjectManager.addExistingProject(filePath)
            catch ME
                throw(ME)
            end

            obj.updateProjectTableData()
        end
        
        function createProject(obj)
            % Trigger the button down callback function...
            obj.CreateNewProjectButtonValueChanged()
            
            % Todo: This should be flipped around, i.e 
            % CreateNewProjectButtonValueChanged should call this method...
            
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
    
            parentSize = getpixelposition(obj.hParent);
            
            tabNames = {'Create New Project', 'Add Existing Project', 'Manage Projects'};
            
            obj.TabGroup = uitabgroup(obj.hParent);
            obj.TabGroup.SelectionChangedFcn = @obj.TabGroupSelectionChanged;
            obj.TabGroup.Position = [0 0 parentSize(3:4)];
            
            for i = 1:numel(tabNames)
                obj.TabList(i) = uitab(obj.TabGroup);
                obj.TabList(i).Title = tabNames{i};
            end
            
            set(obj.TabList, 'BackgroundColor', 'w')
            
        end
        
        function createUiControls(obj)
            
            % Create ChangeProjectFolderButton
            obj.UIControls.BrowseButton = uibutton(obj.TabList(1), 'push');
            obj.UIControls.BrowseButton.ButtonPushedFcn = @obj.ChangeProjectFolderButtonPushed;
            obj.UIControls.BrowseButton.BackgroundColor = [1 1 1];
            obj.UIControls.BrowseButton.FontName = 'Segoe UI';
            obj.UIControls.BrowseButton.FontWeight = 'bold';
            obj.UIControls.BrowseButton.Position = [565 89 100 25];
            obj.UIControls.BrowseButton.Text = 'Change Folder';

            
            % Create label and input field for the project name
            obj.UILabels.ProjectName = uilabel(obj.TabList(1));
            obj.UILabels.ProjectName.FontName = 'Segoe UI';
            obj.UILabels.ProjectName.FontWeight = 'bold';
            obj.UILabels.ProjectName.Visible = 'off';
            obj.UILabels.ProjectName.Position = [332 163 174 22];
            obj.UILabels.ProjectName.Text = 'Give the project a description';

            obj.UIControls.ProjectName = uieditfield(obj.TabList(1), 'text');
            obj.UIControls.ProjectName.Visible = 'off';
            obj.UIControls.ProjectName.Position = [336 141 279 22];

            
            % Create label for the project path input field
            obj.UILabels.ProjectPathInput = uilabel(obj.TabList(1));
            obj.UILabels.ProjectPathInput.FontName = 'Segoe UI';
            obj.UILabels.ProjectPathInput.FontWeight = 'bold';
            obj.UILabels.ProjectPathInput.Position = [51 112 250 22];
            obj.UILabels.ProjectPathInput.Text = 'Local path (to save project configurations)';

            % Create control for the project path input field
            obj.UIControls.ProjectPathInput = uieditfield(obj.TabList(1), 'text');
            obj.UIControls.ProjectPathInput.Position = [49 90 489 22];

            
            % Create label and input field for the project short name
            hLabel = uilabel(obj.TabList(1));
            hLabel.FontName = 'Segoe UI';
            hLabel.FontWeight = 'bold';
            hLabel.Position = [51 163 158 22];
            hLabel.Text = 'Enter a short project name';
            
            hEditField = uieditfield(obj.TabList(1), 'text');
            hEditField.ValueChangedFcn = @obj.ProjectLabelEditFieldValueChanged;
            hEditField.ValueChangingFcn = @obj.ProjectLabelEditFieldValueChanging;
            hEditField.FontName = 'Segoe UI';
            hEditField.FontWeight = 'bold';
            hEditField.Position = [49 141 169 22];
            
            % Set tooltips (no tooltip prop in older versions of matlab)
            try
                hLabel.Tooltip = {'(a-z, A-Z, 1-9, _)'};
                hEditField.Tooltip = {'(a-z, A-Z, 1-9, _)'};
            end
            
            obj.UILabels.ProjectShortNameInput = hLabel;
            obj.UIControls.ProjectShortNameInput = hEditField;

            
            % Create CreateNewProjectButton
            obj.UIControls.CreateNewProjectButton = uibutton(obj.TabList(1), 'push');
            obj.UIControls.CreateNewProjectButton.ButtonPushedFcn = @obj.CreateNewProjectButtonValueChanged;
            obj.UIControls.CreateNewProjectButton.FontSize = 14;
            obj.UIControls.CreateNewProjectButton.FontWeight = 'bold';
            obj.UIControls.CreateNewProjectButton.Position = [265 27 170 34];
            obj.UIControls.CreateNewProjectButton.Text = 'Create New Project';


            % Create controls on the Add Existing Project tab page
            taxIdx = strcmp({obj.TabList.Title}, 'Add Existing Project');
            hButton = uibutton(obj.TabList(taxIdx), 'push');
            hButton.Text = 'Add Existing Project';
            hButton.ButtonPushedFcn = @obj.onAddExistingProjectButtonPushed;
            hButton.Position(3:4) = [170 34];
            hButton.FontWeight = 'bold'; 
            
            obj.UIControls.AddExistingButton = hButton;
            uim.utility.layout.centerObjectInRectangle(hButton, obj.TabList(taxIdx))
            
            taxIdx = strcmp({obj.TabList.Title}, 'Manage Projects');
            
            obj.UIControls.ProjectTable = uitable(obj.TabList(taxIdx));
            obj.UIControls.ProjectTable.Position = [10,10,530,200];
            
            
            %set(obj.UIControls)
            
        end
        
        function createProjectTable(obj)
            
            obj.updateProjectTableData()
            obj.setProjectTablePosition()
            
            obj.UIControls.ProjectTable.ColumnWidth = {50, 100, 300, 500};
            obj.UIControls.ProjectTable.ColumnEditable = [true, false,true,false];
            
            obj.UIControls.ProjectTable.CellEditCallback = @obj.onTableCellEdited;
        end
        
        function updateProjectTableData(obj)
        %updateProjectTableData Update data in the uitable
        
            if isempty(obj.ProjectManager.Catalog); return; end
            if ~isfield(obj.UIControls, 'ProjectTable'); return; end
        
            T = struct2table(obj.ProjectManager.Catalog, 'AsArray', true);
            
            currentProjectName = getpref('Nansen', 'CurrentProject');
            
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
                obj.setRowStyle('Current Project', find(isCurrent))

                s = uistyle('FontWeight', 'bold');
                addStyle(obj.UIControls.ProjectTable, s, 'row', find(isCurrent));

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

            parentPosition = obj.TabList(2).InnerPosition;
            tablePosition = parentPosition + [1, 1, -2, -2] * margin;
            obj.UIControls.ProjectTable.Position = tablePosition;
            
        end
        
        function createTableContextMenu(obj)
            
            cMenu = uicontextmenu(ancestor(obj.hParent, 'figure'));
            
            contextMenuItemNames = {...
                'Set current project', ...
                'Remove project', ...
                'Delete project', ...
                'Open project folder' };
            
            hMenuItem = gobjects(numel(contextMenuItemNames), 1);
            for i = 1:numel(contextMenuItemNames)
                hMenuItem(i) = uimenu(cMenu, 'Text', contextMenuItemNames{i});
                hMenuItem(i).Callback = @obj.onContextMenuItemClicked;
            end
            
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
    
    methods (Access = protected)
        
        function changeProject(obj, rowIdx)
            
            projectName = obj.getNameFromRowIndex(rowIdx);
            
            msg = obj.ProjectManager.changeProject(projectName);
                        
            % Todo: What if something failed
            obj.uialert(msg, 'Changed Project', 'success')
            
            try % Note: Does not work in older versions of matlab
                obj.setRowStyle('Current Project', rowIdx)
                obj.UIControls.ProjectTable.Data(:, 'Current') = {false};
                obj.UIControls.ProjectTable.Data(rowIdx, 'Current') = {true};
            catch
                obj.UIControls.ProjectTable.Data(:, 1) = {false};
                obj.UIControls.ProjectTable.Data(rowIdx, 1) = {true};                
            end

            obj.notify('ProjectChanged', event.EventData)
            
        end
        
        function deleteProject(obj, rowIdx)
            
            % Display message
            hFig = ancestor(obj.hParent, 'figure');
            message = 'This action will remove the project and delete all the project data. Are you sure you want to continue?';
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
                name = obj.UIControls.ProjectTable.DisplayData{rowIndex, 2};    % Name colum index = 2
                if iscell(name)
                    name = name{1};
                end
                
            catch % DisplayData not available in older versions of matlab.
                name = obj.UIControls.ProjectTable.Data{rowIndex, 2};
            end
            
        end
    end

    methods (Access = protected) % UIControl callbacks
       
        % Button pushed function: ChangeProjectFolderButton
        function ChangeProjectFolderButtonPushed(obj, ~, ~)
        %    
        %   Lets user select a folder to save project files to.
        
            import nansen.config.project.uisetProjectFolder
            
            % Get values from UIControls and assign to local variables
            currentProjectPath = obj.UIControls.ProjectPathInput.Value;
            projectShortName = obj.UIControls.ProjectShortNameInput.Value;
            
            currentRootFolder = fileparts(currentProjectPath);

            % Call function thats asks user to interactively select a new folder
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
            
            projectLongName = obj.UIControls.ProjectName.Value;
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
                args = {projectShortName, projectLongName, projectFolderPath};
                
                try
                    obj.ProjectManager.createProject(args{:})
                catch ME
                    title = 'Project Creation Failed';
                    obj.uialert(ME.message, title)
                    rethrow(ME)
                end
                
                obj.notify('ProjectChanged', event.EventData)
                obj.updateProjectTableData()
                
                
                % Disable controls for creating new project
                % Todo: only do this during the initial setup
                obj.disableCreateNewProjectControls()
            end
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
            
            %obj.ProjectRootFolderPath = getpref('NansenSetup', 'DefaultProjectPath');
            
        end

        % Value changing function: ProjectLabelEditField
        function ProjectLabelEditFieldValueChanging(obj, ~, event)
            changingValue = event.Value;
            
            obj.UIControls.ProjectPathInput.Value = fullfile(obj.ProjectRootFolderPath, changingValue);
            obj.UIControls.ProjectPathInput.Tooltip = obj.UIControls.ProjectPathInput.Value;
        
        end

        % Tab selection chaged function: TabGroupSelectionChanged
        function TabGroupSelectionChanged(obj, ~, event)
            
            switch event.NewValue.Title
                
                case 'Manage Projects'
                    
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
            obj.SelectedRow = evt.DisplayIndices(1);
            obj.setRowStyle('Selected Row', evt.DisplayIndices(1))
        end
        
        function onTableCellEdited(obj, src, evt)
            
            if evt.Indices(2) == 3
                return % Todo: Save project data...
            end
            
            rowIdx = evt.Indices(1);
            
            if evt.NewData
                obj.changeProject(rowIdx)
            else
                src.Data(rowIdx, 1) = {true};
                return
            end

        end
        
        function onContextMenuItemClicked(obj, src, ~)
            
            if isempty(obj.SelectedRow)
                msg = 'No project is selected. Please select a project and try again.';
                obj.uialert(msg, 'No project is selected', 'error')
            end
            
            switch src.Text
                case 'Set current project'
                    obj.changeProject(obj.SelectedRow)

                case 'Remove project'
                    obj.removeProject(obj.SelectedRow)
                    
                case 'Delete project'
                    obj.deleteProject(obj.SelectedRow)
                    
                case 'Open project folder'
                    folderPath = obj.UIControls.ProjectTable.Data{obj.SelectedRow, 4};
                    utility.system.openFolder(folderPath{1})
                    
            end
        end
       
        function onAddExistingProjectButtonPushed(obj, src, evt)
            obj.addExistingProject()
        end
        
    end

    methods (Access = private)
        
        function assignInitialProjectRootFolderPath(obj)
            %
            % Set default value of path for project root folder
            rootdir = utility.path.getAncestorDir(nansen.rootpath, 1);
            projectFolder = fullfile(rootdir, '_userdata', 'projects'); % <-- Default value
            projectFolder = getpref('NansenSetup', 'DefaultProjectPath', projectFolder);
            obj.ProjectRootFolderPath = projectFolder;
            
        end
        
    end
end