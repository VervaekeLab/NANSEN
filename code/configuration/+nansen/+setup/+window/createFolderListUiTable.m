function [hFig, hTable] = createFolderListUiTable(hFigSetupApp)
%createFolderListUiTable Figure with table for listing folder paths
%
%   Open figure side by side with the setup app figure.
%
%   Requires uiw and uim packages.

    % Todo: These should be retrieved from theme stylesheet
    FGCOLOR = [234,236,237]/255;        % Panel foreground color
    BGCOLOR = [48,62,76]/255;           % Panel background color
    BGCOLORFIG = [246,248,252]/255;     % Background color for figure 
    
    % Calculate position for placement of new figure
    screenSize = get(0, 'ScreenSize');
    appFigPosition = hFigSetupApp.Position;
    newFigPosition = appFigPosition;
    newFigPosition(1) = sum( appFigPosition([1,3]) ) + 10;                  % Why 10??? % Todo (UI4)
    newFigPosition(3) = screenSize(3) - appFigPosition(3) - 30;             % Why 30??? % Todo (UI4)
    
    % Create the figure
    hFig = figure();
    hFig.Name = 'Detected data folders';
    hFig.MenuBar = 'none';
    hFig.NumberTitle = 'off';
    hFig.Position = newFigPosition;
    hFig.Color = BGCOLORFIG;

    
    % Create the table for listing folders
    
    %tTmp = uitable('Parent', hFig);
    %tTmp = uiw.widget.Table('Parent', hFig);

    tableParams = { ...
        'Theme', uim.style.tableLightNansen, ...
        'ShowColumnHeader', false, ...
        'ColumnResizePolicy', 'next' };
    
    hTable = uim.widget.StylableTable('Parent', hFig, tableParams{:});
    
    hTable.Units = 'pixels';
    hTable.Position = [20,20,newFigPosition(3:4)-[40, 60]];
    hTable.FontName = 'helvetica';
    hTable.FontSize = 9;
    hTable.ColumnName = {'Detected data folders'};
    
    % Todo: Fix column width and table autoresizing.
    %hTable.Data = folderList;
    %hTable.ColumnPreferredWidth = 800;
    %v.ColumnWidth = 800;

    % Create panel for displaying info text...
    hPanel = uipanel(hFig);
    %hPanel.BorderType = 'none';
    hPanel.Units = 'pixels';
    hPanel.Position = [1, newFigPosition(4)-63, newFigPosition(3), 63];
    hPanel.BackgroundColor = BGCOLOR;

    msg = ['Shows a list of all folders that are found using the ', ...
           'current folder organization settings.'];
    
    % Create control for displaying info text.
    label = uicontrol(hPanel, 'style', 'text');
    label.String = msg;
    label.Position = [10, 10, hPanel.Position(3:4)-20];
    label.FontSize = 14;
    label.BackgroundColor = BGCOLOR;
    label.ForegroundColor = FGCOLOR;

    % Todo (UI4): make table interactive, and add inputs for ignore
    % filter and expression.


end
