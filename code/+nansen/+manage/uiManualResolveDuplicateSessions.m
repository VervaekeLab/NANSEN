function uiManualResolveDuplicateSessions(sessionArray)

    duplicateTable = nansen.manage.buildDuplicateSessionTable(sessionArray);

    hFig = figure('MenuBar', 'none');
    hFig.NumberTitle = 'off';
    hFig.Name = 'Resolve Duplicate Sessions';
    figurePosition = hFig.Position;
    figurePosition(3:4) = [900, 520];
    hFig.Position = figurePosition;

    if nansen.util.useModernUiTable()
        createModernTableUi(hFig, duplicateTable)
    else
        createLegacyTableUi(hFig, duplicateTable)
    end

    uiwait(hFig)
end

function createModernTableUi(hFig, duplicateTable)

    hPanel = createInstructionPanel(hFig);
    hTextbox = createInstructionText(hPanel);
    hTextbox.String = getInstructionText();

    hButton = createOpenFolderButton(hPanel);
    hButton.Callback = @(~, ~) openSelectedDuplicateSessionFolder(hFig);

    displayTable = getDisplayDuplicateTable(duplicateTable);
    hTable = uitable('Parent', hFig, ...
        'Units', 'normalized', ...
        'Position', [0.05, 0.05, 0.9, 0.68], ...
        'Data', table2cell(displayTable), ...
        'ColumnName', displayTable.Properties.VariableNames, ...
        'ColumnEditable', false(1, width(displayTable)), ...
        'SelectionType', 'row', ...
        'Multiselect', 'off', ...
        'SelectionChangedFcn', @(src, evt) onModernTableSelectionChanged(hFig, src));

    try
        hTable.ColumnWidth = {160, 110, 140, 430};
    catch
    end

    hFig.WindowButtonDownFcn = @(~, ~) onFigureMouseButtonDown(hFig);
    setappdata(hFig, 'DuplicateSessionTable', duplicateTable);
    setappdata(hFig, 'DuplicateSessionUITable', hTable);
    setappdata(hFig, 'SelectedDuplicateTableRow', []);
end

function createLegacyTableUi(hFig, duplicateTable)

    warning('off', 'MATLAB:ui:javacomponent:FunctionToBeRemoved')
    hTable = uiw.widget.Table('Parent', hFig);
    warning('on', 'MATLAB:ui:javacomponent:FunctionToBeRemoved')
    hTable.Position = [0.05, 0.05, 0.9, 0.68];
    hTable.DataTable = getDisplayDuplicateTable(duplicateTable);

    hPanel = createInstructionPanel(hFig);
    hTextbox = createInstructionText(hPanel);
    hTextbox.String = getInstructionText();

    hButton = createOpenFolderButton(hPanel);
    hButton.Callback = @(~, ~) openSelectedLegacySessionFolder(hTable, duplicateTable);
end

function hPanel = createInstructionPanel(hFig)

    hPanel = uipanel(hFig, 'Position', [0.05, 0.75, 0.9, 0.2]);
    hPanel.BorderType = 'none';
end

function hTextbox = createInstructionText(hPanel)

    hTextbox = uicontrol(hPanel, 'style', 'text');
    hTextbox.Units = 'normalized';
    hTextbox.Position = [0.05, 0.34, 0.9, 0.62];
    hTextbox.FontSize = 13;
    hTextbox.HorizontalAlignment = 'left';
end

function hButton = createOpenFolderButton(hPanel)

    hButton = uicontrol(hPanel, 'style', 'pushbutton');
    hButton.Units = 'normalized';
    hButton.Position = [0.35, 0.08, 0.3, 0.24];
    hButton.String = 'Open Folder';
end

function text = getInstructionText()

    text = ['These folders produce duplicate session IDs. Each row is one ', ...
        'detected duplicate folder, grouped by session ID and numbered within ', ...
        'that group. Open the relevant folders, rename or remove folders outside ', ...
        'NANSEN so each session ID is unique, then rerun initialization.'];
end

function displayTable = getDisplayDuplicateTable(duplicateTable)

    displayTable = removevars(duplicateTable, 'SessionIndex');
    displayTable.SessionID = cellstr(displayTable.SessionID);
    displayTable.DataLocation = cellstr(displayTable.DataLocation);
    displayTable.FolderPath = cellstr(displayTable.FolderPath);
end

function onModernTableSelectionChanged(hFig, hTable)

    if isempty(hTable.Selection)
        setappdata(hFig, 'SelectedDuplicateTableRow', []);
        return
    end

    setappdata(hFig, 'SelectedDuplicateTableRow', hTable.Selection(1, 1));
end

function onFigureMouseButtonDown(hFig)

    if strcmp(hFig.SelectionType, 'open')
        openSelectedDuplicateSessionFolder(hFig)
    end
end

function openSelectedDuplicateSessionFolder(hFig)

    selectedRow = getappdata(hFig, 'SelectedDuplicateTableRow');
    if isempty(selectedRow)
        return
    end

    duplicateTable = getappdata(hFig, 'DuplicateSessionTable');
    folderPath = duplicateTable.FolderPath(selectedRow);

    if strlength(folderPath) ~= 0
        utility.system.openFolder(char(folderPath))
    end
end

function openSelectedLegacySessionFolder(hTable, duplicateTable)

    selectedRow = hTable.SelectedRows;
    if isempty(selectedRow)
        return
    end

    folderPath = duplicateTable.FolderPath(selectedRow(1));

    if strlength(folderPath) ~= 0
        utility.system.openFolder(char(folderPath))
    end
end
