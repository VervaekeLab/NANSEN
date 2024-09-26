classdef AddonManagerUI < applify.apptable
    
    properties 
        AddonManager  % Instance of AddonManager class
    end
    
    properties (Access = private) % Component appearance
        ToolbarButtons matlab.ui.control.Button
    end

    properties (Hidden)
        % Install button
        InstallButtonFontColor = [0.8784 0.8784 0.7059];                    % Todo: get from main gui (setup app)
        InstallButtonBackgroundColor = [0 0.6 0];                           % Todo: get from main gui (setup app)
        
        ToolbarButtonFontColor = [0.15,0.15,0.15]
        ToolbarButtonBackgroundColor = [0.94,0.94,0.94]
    end

    methods % Constructor
        
        function obj = AddonManagerUI(hParent, hAddonManager, varargin)
            
            % Todo: parent might not be given as first input, it might be
            % in the list of name value pairs...
            if nargin < 2
                userSession = nansen.internal.user.NansenUserSession.instance();
                hAddonManager = userSession.getAddonManager();
            end
            
            % Get data from the addonmanager handle.
            assert(isa(hAddonManager, 'nansen.config.addons.AddonManager'))
            data = hAddonManager.AddonList;
            
            obj@applify.apptable(hParent, 'Data', data, varargin{:})

            % Assign object to AddonManager property.
            obj.AddonManager = hAddonManager;
        end
        
    end
    
    methods % Set/get
        
        function set.ToolbarButtonFontColor(obj, newValue)
            try
                obj.onToolbarButtonFontColorSet(newValue)
                obj.ToolbarButtonFontColor = newValue;
            catch ME
                throw(ME)
            end
        end

        function set.ToolbarButtonBackgroundColor(obj, newValue)
            try
                obj.onToolbarButtonBackgroundColorSet(newValue)
                obj.ToolbarButtonBackgroundColor = newValue;
            catch ME
                throw(ME)
            end
        end
    end

    methods % Public methods
        function downloadAllAddons(obj)
            addonIndices = 1:numel(obj.AddonManager.AddonList);
            obj.downloadAddons(addonIndices)
        end
    end

    methods (Access = protected) % Implement superclass options
        
        function assignDefaultTablePropertyValues(obj)
            obj.ShowColumnHeader = false;
            obj.ColumnNames = {'Toolbox Name', 'Optionality', ...
                'Is Installed', '', '', ''};
            
            obj.ColumnWidths = [22, 140, 70, 20, 70, 75, 70, 90];
            obj.RowSpacing = 15;
            obj.TableMargin = 5;   % Space in pixels around the table within the parent container.

        end
        
        function hS = createTableRowComponents(obj, rowData, rowNum)
            
            % Create shorter variable names for some of the layout props 
            %m = obj.TableMargin;
            
            rowExtent = obj.RowHeight + obj.RowSpacing;
            
            X = obj.ColumnLocations;
            y = obj.RowLocations(rowNum);
            W = obj.ColumnWidths;
            h = 22;
            
            % Initialize a struct for storing uihandles for current row
            hS = struct();
            
            % Create Horizontal Divider
            imageArgs = {'BorderType', 'bottom', 'Selection', 'off'};
            imagePathStr = obj.getTableRowBackground(imageArgs{:});

            hS.HDivider = uiimage(obj.TablePanel);
            hS.HDivider.Position = [0 y obj.TablePanelPosition(3) rowExtent];
            hS.HDivider.ImageSource = imagePathStr;
            hS.HDivider.ImageClickedFcn = @obj.onTableRowSelected;
            
        % % Create checkbox for row selection
            i = 1;
            hS.CheckboxSelector = uicheckbox(obj.TablePanel);
            hS.CheckboxSelector.Position = [X(i) y W(i) 22];
            hS.CheckboxSelector.Text = '';
            hS.CheckboxSelector.ValueChangedFcn = @obj.onTableRowSelected;
            obj.centerComponent(hS.CheckboxSelector, y)
            
            
        % % Create label for toolbox name
            i = 2;
            hS.NameLabel = uilabel(obj.TablePanel);
            hS.NameLabel.FontName = 'Segoe UI';
            hS.NameLabel.Position = [X(i) y W(i) h];
            hS.NameLabel.Text = rowData.Name;
            hS.NameLabel.Tooltip = rowData.Description;
            obj.centerComponent(hS.NameLabel, y)
            %hNext.NameLabel.BackgroundColor = [0.8,0.8,0.8];
            
% %             % Does not work. Probably a security concern from matlab.
% %             hNext.NameLabel = uihtml(obj.TablePanel);
% %             hNext.NameLabel.Position = [xPos(1) y 150 22];
% %             hNext.NameLabel.HTMLSource = sprintf('<a href="%s" style="font-size: 12px; font-family:helvetica">%s</a>', S.DownloadUrl, S.Name);
            

        % % Create label for showing if toolbox is required or optional
            i = 3;
            hS.RequiredLabel = uilabel(obj.TablePanel);
            hS.RequiredLabel.FontName = 'Segoe UI';
            hS.RequiredLabel.Position = [X(i) y W(i) 22];
            %hNext.RequiredLabel.VerticalAlignment = 'bottom';
            obj.centerComponent(hS.RequiredLabel, y)
            
            
            if rowData.IsRequired
                hS.RequiredLabel.Text = 'Required';
            else
                hS.RequiredLabel.Text = 'Optional';
            end


        % % Create image for showing if toolbox is already installed
            i = 4;
            hS.IsInstalledImage = uiimage(obj.TablePanel);
            hS.IsInstalledImage.Position = [X(i) y W(i) 20];
            obj.centerComponent(hS.IsInstalledImage, y)
            
            if rowData.IsDoubleInstalled
                hS.IsInstalledImage.ImageSource = nansen.internal.getIconPathName('warn.png');
                hS.IsInstalledImage.Tooltip = 'Warning: Multiple instances of toolbox was found';
            elseif rowData.IsInstalled
                hS.IsInstalledImage.ImageSource = nansen.internal.getIconPathName('checkmark.png');
                hS.IsInstalledImage.Tooltip = 'Toolbox is installed';
            else
                hS.IsInstalledImage.ImageSource = nansen.internal.getIconPathName('crossmark.png');
                hS.IsInstalledImage.Tooltip = 'Toolbox missing';
            end            

            
        % % Create button for downloading toolbox
            i = 5;
            hS.InstallButton = uibutton(obj.TablePanel, 'push');
            hS.InstallButton.BackgroundColor = obj.InstallButtonBackgroundColor; 
            hS.InstallButton.FontColor = obj.InstallButtonFontColor; 
            
            hS.InstallButton.FontName = 'Segoe UI';
            hS.InstallButton.FontWeight = 'bold';
            hS.InstallButton.FontColor = [0.8784 0.8784 0.7059];
            hS.InstallButton.Position = [X(i) y W(i) 22];
            hS.InstallButton.Text = 'Download';
            obj.centerComponent(hS.InstallButton, y)

            hS.InstallButton.ButtonPushedFcn = @(s,e,name,num) obj.onInstallAddonPushed(rowData.Name, rowNum);
            
            if rowData.IsInstalled
                hS.InstallButton.Enable = 'off';
            end
            
            if ~isempty(rowData.FilePath)
                hS.InstallButton.Tooltip = rowData.FilePath;
            end
            
        % % Create button for updating toolbox 
            i = 6;
            hS.UpdateButton = uibutton(obj.TablePanel, 'push');
            hS.UpdateButton.FontName = 'Segoe UI';
            hS.UpdateButton.Position = [X(i) y W(i) 22];
            hS.UpdateButton.Text = 'Update';
            hS.UpdateButton.ButtonPushedFcn = @(s,e,name,num) obj.onUpdateAddonPushed(rowData.Name, rowNum);
            obj.centerComponent(hS.UpdateButton, y)

            if ~rowData.IsInstalled
                hS.UpdateButton.Enable = 'off';
            end

        % % Create button for browsing to locate toolbox 
            i = 7;
            hS.BrowseButton = uibutton(obj.TablePanel, 'push');
            hS.BrowseButton.FontName = 'Segoe UI';
            hS.BrowseButton.Position = [X(i) y W(i) 22];
            hS.BrowseButton.Text = 'Locate...';
            hS.BrowseButton.ButtonPushedFcn = @(s,e,name,num) obj.onBrowseAddonPushed(rowData.Name, rowNum);
            obj.centerComponent(hS.BrowseButton, y)
            hS.BrowseButton.Tooltip = 'Find local addon folder on harddrive...';
          
        % % Create button for opening website
            i = 8;
            hS.WebButton = uibutton(obj.TablePanel, 'push');
            hS.WebButton.FontName = 'Segoe UI';
            hS.WebButton.Position = [X(i) y W(i) 22];
            hS.WebButton.Text = 'Open Website';
            hS.WebButton.ButtonPushedFcn = @(s,e,name,num) obj.onOpenWebsiteButtonPushed(rowData.Name, rowNum);
            obj.centerComponent(hS.WebButton, y)
            hS.WebButton.Tooltip = 'Open addon website';  
            
        end
        
        function createToolbarComponents(obj, hPanel)
        %createToolbarComponents Create "toolbar" components above table.    
            if nargin < 2; hPanel = obj.Parent.Parent; end

            import uim.utility.layout.subdividePosition
            hPanel = obj.Parent.Parent;
            
            toolbarPosition = obj.getToolbarPosition();
            
            buttonNames = {'Download All', 'Download Selected', 'Save MATLAB Path'};
            buttonWidths = [120, 140, 140];
            numButtons = numel(buttonNames);
            
            buttonSize = [140, 20];
            %wInit = repmat(buttonSize(1), 1, numButtons);
            
            % Get component positions for the components on the left
            [Xl, Wl] = subdividePosition(toolbarPosition(1), ...
                toolbarPosition(3), buttonWidths, 10);
            Y = toolbarPosition(2);

            % Create buttons
            for i = 1:numButtons
                obj.ToolbarButtons(i) = uibutton(hPanel, 'push');
                obj.ToolbarButtons(i).ButtonPushedFcn = @obj.onToolbarButtonPushed;
                obj.ToolbarButtons(i).Position = [Xl(i) Y Wl(i) 22];
                obj.ToolbarButtons(i).Text = buttonNames{i};
            end

            iconPath = fullfile(matlabroot, 'toolbox', 'shared', 'controllib', 'general', 'resources', 'toolstrip_icons', 'Import_24.png');
            [obj.ToolbarButtons(1:2).Icon] = deal(iconPath);
            %app.DownloadAllButton.Icon = iconPath;

            iconPath = fullfile(matlabroot, 'toolbox', 'shared', 'controllib', 'general', 'resources', 'toolstrip_icons', 'Set_Path_24.png');
            obj.ToolbarButtons(3).Icon = iconPath;

        end
        
        function toolbarComponents = getToolbarComponents(obj)
            toolbarComponents = obj.ToolbarButtons;
        end
        
    end
    
    methods (Access = private) % Button callbacks
              
        function onInstallAddonPushed(obj, addonName, iRow)
        %onInstallAddonPushed Callback for button press on download button    
             
            obj.RowControls(iRow).InstallButton.Text = 'Downloading';
            
            % Display a progress dialog while download is ongoing.
            hFig = ancestor(obj.Parent, 'figure');
            title = 'Download in progress';
            message = sprintf('Downloading %s', addonName);
            try
                d = uiprogressdlg(hFig, title, message, 'Indeterminate', 'on');
            catch
                d = uiprogressdlg(hFig, 'Title', title, 'Message', message, 'Indeterminate', 'on');
            end
            
            try
                obj.AddonManager.downloadAddon(addonName, false, true)
                close(d)

            catch ME
                try
                    errorMessage =  ME.message;
                    if ~isempty(ME.cause)
                        errorMessage = sprintf('%s\nCaused by:\n%s\n\nSee command window for more details.', errorMessage, ME.cause{1}.message);
                    end
                    answer = uiconfirm(hFig, errorMessage, "Something went wrong", ...
                        'Icon', 'error', 'Options', {'Ok'}, 'Interpreter', 'html');
                catch
                    answer = uiconfirm(hFig, 'Title', "Something went wrong", ...
                        'Message', ME.message, 'Icon', 'error', 'Options', {'Ok'});
                end
                close(d)
                return
            end
            
            obj.RowControls(iRow).IsInstalledImage.ImageSource = nansen.internal.getIconPathName('checkmark.png');
            obj.RowControls(iRow).IsInstalledImage.Tooltip = 'Toolbox is installed';

            obj.RowControls(iRow).InstallButton.Text = 'Download';
            obj.RowControls(iRow).InstallButton.Enable = 'off';
            
            obj.AddonManager.addAddonToMatlabPath(addonName)
            obj.AddonManager.saveAddonList()
            
        end
                
        function onBrowseAddonPushed(obj, addonName, iRow)
        %onBrowseAddonPushed Callback for button press on browse button    
            group = 'NansenSetup';
            pref =  'BrowseAddonHelp';
            title = 'Locate Folder';
            quest = {'Locate the folder where this addon is saved'};
            pbtns = {'Ok', 'Cancel'};
            
            [pval, tf] = uigetpref(group,pref,title,quest,pbtns);

            switch pval
                case 'ok'
                    % continue
                case 'cancel'
                    rmpref('NansenSetup', 'BrowseAddonHelp')
                    return
            end
            
            tf = obj.AddonManager.browseAddonPath(addonName);
            
            % Bring figure app back into focus.
            hFigure = ancestor(obj.Parent, 'figure');
            figure(hFigure)
            
            if ~tf; return; end
            
            obj.RowControls(iRow).IsInstalledImage.ImageSource = nansen.internal.getIconPathName('checkmark.png');
            obj.RowControls(iRow).IsInstalledImage.Tooltip = 'Toolbox already installed';
            obj.RowControls(iRow).InstallButton.Enable = 'off';
            
            S = obj.AddonManager.AddonList(iRow);
            obj.RowControls(iRow).NameLabel.Tooltip = S.FilePath;

        end
        
        function onUpdateAddonPushed(obj, addonName, ~)
        %onUpdateAddonPushed Callback for button press on update button 
                   
            % Display a progress dialog while download is ongoing.
            hFig = ancestor(obj.Parent, 'figure');
            title = 'Download in progress';
            message = sprintf('Updating %s', addonName);
        
            try
                d = uiprogressdlg(hFig, title, message, 'Indeterminate','on');
            catch
                d = uiprogressdlg(hFig, 'Title', title, 'Message', message, 'Indeterminate','on');
            end
            obj.AddonManager.downloadAddon(addonName, 'update')
            close(d)
            
            obj.AddonManager.addAddonToMatlabPath(addonName)
            obj.AddonManager.saveAddonList()
            
        end
        
        function onOpenWebsiteButtonPushed(obj, addonName, iRow)
            S = obj.AddonManager.AddonList(iRow);
            web(S.WebUrl, '-browser')
        end
        
        function onToolbarButtonPushed(obj, src, evt)
            
            switch src.Text
                
                case 'Download All'
                    addonIndices = 1:numel(obj.AddonManager.AddonList);
                    obj.downloadAddons(addonIndices)
                    
                case 'Download Selected'
                    addonIndices = obj.SelectedRows;
                    obj.downloadAddons(addonIndices)

                case 'Save MATLAB Path'
                    obj.saveMatlabPath()
                    
                case 'Open Addon Website'
                    addonIndices = obj.SelectedRows;
                    S = obj.AddonManager.AddonList(addonIndices(1));
                    web(S.WebUrl, '-browser')
                    return
            end
            

        end

    end
    
    methods (Access = private) % Actions
        
        function downloadAddons(obj, addonIndices)
                    
            for i = addonIndices
                S = obj.AddonManager.AddonList(i);
                if ~S.IsInstalled
                    % Call the install button callback
                    obj.onInstallAddonPushed(S.Name, i)
                end
            end
            
        end
        
        function saveMatlabPath(obj)
        %saveMatlabPath Save matlab path (presumably after installing addons) 
            message = 'This will permanently add the downloaded addons to the MATLAB search path.';
            title = 'Confirm Save';
            
            hFig = ancestor(obj.Parent, 'figure');

            selection = uiconfirm(hFig, message, ...
                title, 'Options', {'Save Path', 'Cancel'},...
                'DefaultOption', 1, 'CancelOption', 2);
            
            if strcmp(selection, 'Cancel'); return; end
            
            savepath()
            
            obj.AddonManager.markClean()
            obj.AddonManager.restoreAddToPathOnInitFlags()
        end

    end

    methods (Access = private) % Style components (Todo, move to superclass)
        
        function onToolbarButtonBackgroundColorSet(obj, newValue)
            set(obj.ToolbarButtons, 'BackgroundColor', newValue)
        end

        function onToolbarButtonFontColorSet(obj, newValue)
            set(obj.ToolbarButtons, 'FontColor', newValue)
        end
    end
end