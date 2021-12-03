classdef AddonTable < applify.apptable
    
    properties 
        AddonManager  % Instance of AddonManager class
    end
    
    properties (Access = private, Hidden) % Component appeareance
        
        % Install button
        InstallButtonFontColor = [0.8784 0.8784 0.7059];                    % Todo: get from main gui (setup app)
        InstallButtonBackgroundColor = [0 0.6 0];                           % Todo: get from main gui (setup app)
        
    end
    
    methods
        
        function obj = AddonTable(hParent, hAddonManager, varargin)
            
            % Todo: parent might not be given as first input, it might be
            % in the list of name value pairs...
            
            % Get data from the addonmanager handle.
            assert(isa(hAddonManager, 'nansen.setup.model.Addons'))
            data = hAddonManager.AddonList;
            
            obj@applify.apptable(hParent, 'Data', data, varargin{:})

            % Assign object to AddonManager property.
            obj.AddonManager = hAddonManager;
        end
        
    end
    
    methods (Access = protected)
        function assignDefaultTablePropertyValues(obj)
            obj.ShowColumnHeader = false;
            obj.ColumnNames = {'Toolbox Name', 'Optionality', ...
                'Is Installed', '', '', ''};
            
            obj.ColumnWidths = [22, 150, 80, 20, 80, 80, 70];
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
                hS.IsInstalledImage.ImageSource = 'warn.png';
                hS.IsInstalledImage.Tooltip = 'Warning: Multiple instances of toolbox was found';
            elseif rowData.IsInstalled
                hS.IsInstalledImage.ImageSource = 'check-01.png';
                hS.IsInstalledImage.Tooltip = 'Toolbox is installed';
            else
                hS.IsInstalledImage.ImageSource = 'cross-01.png';
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
            
            
        % % Create button for browsing to locate toolbox 
            i = 6;
            hS.BrowseButton = uibutton(obj.TablePanel, 'push');
            hS.BrowseButton.FontName = 'Segoe UI';
            hS.BrowseButton.Position = [X(i) y W(i) 22];
            hS.BrowseButton.Text = 'Locate';
            hS.BrowseButton.ButtonPushedFcn = @(s,e,name,num) obj.onBrowseAddonPushed(rowData.Name, rowNum);
            obj.centerComponent(hS.BrowseButton, y)

            if ~isempty(rowData.FilePath)
                hS.BrowseButton.Tooltip = rowData.FilePath;
            end
            
            
        % % Create button for updating toolbox 
            i = 7;
            hS.UpdateButton = uibutton(obj.TablePanel, 'push');
            hS.UpdateButton.FontName = 'Segoe UI';
            hS.UpdateButton.Position = [X(i) y W(i) 22];
            hS.UpdateButton.Text = 'Update';
            hS.UpdateButton.ButtonPushedFcn = @(s,e,name,num) obj.onUpdateAddonPushed(rowData.Name, rowNum);
            obj.centerComponent(hS.UpdateButton, y)

            if ~rowData.IsInstalled
                hS.UpdateButton.Enable = 'off';
            end

        end
    end
    
    
    methods % Subclass specific callbacks
              
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
            obj.AddonManager.downloadAddon(addonName)
            
            close(d)
            
            obj.RowControls(iRow).IsInstalledImage.ImageSource = 'check-01.png';
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
            
            obj.RowControls(iRow).IsInstalledImage.ImageSource = 'check-01.png';
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
        
    end

end