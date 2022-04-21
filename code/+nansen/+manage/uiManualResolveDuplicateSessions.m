function uiManualResolveDuplicateSessions(sessionArray)

    % Todo: add option to remove from list...
    % Todo: add button to retry creating session table / redected sessions
    
    
    hFig = figure('MenuBar', 'none');
    hFig.NumberTitle = 'off';
    hFig.Name = 'Resolve Duplicate Sessions';
    
    warning('off', 'MATLAB:ui:javacomponent:FunctionToBeRemoved')
    hTable = uiw.widget.Table('Parent', hFig);
    warning('on', 'MATLAB:ui:javacomponent:FunctionToBeRemoved')
    hTable.Position = [0.05, 0.05, 0.9, 0.7];
    
    dataTable = table({sessionArray.sessionID}', 'VariableNames', {'SessionID'});
    
    hTable.DataTable = dataTable;
    
    hPanel = uipanel(hFig, 'Position', [0.05, 0.75, 0.9, 0.2]);
    hPanel.BorderType = 'none';
    
    hTextbox = uicontrol(hPanel, 'style', 'text');
    hTextbox.Units = 'normalized';
    hTextbox.Position = [0.05, 0.4, 0.9, 0.65];
    hTextbox.String = 'Select sessions and open session folders to rename or remove folders. Remember, session IDs are detected from the session folder name.';
    hTextbox.FontSize = 14;
    hTextbox.HorizontalAlignment = 'left';
    
    hButton = uicontrol(hPanel, 'style', 'pushbutton');
    hButton.Units = 'normalized';
    hButton.Position = [0.35, 0.15, 0.3, 0.25];
    hButton.String = 'Open Folder';
    hButton.Callback = @(s,e) onOpenSessionFolderButtonPushed(hTable, sessionArray);
    
% %     hButton = uicontrol(hPanel, 'style', 'pushbutton');
% %     hButton.Units = 'normalized';
% %     hButton.Position = [0.35, 0.15, 0.3, 0.25];
% %     hButton.String = 'Remove Form List';
% %     hButton.Callback = @(s,e) onRemoveSessionFromList(hTable, sessionArray);
    
    uiwait(hFig)
    
end

function onOpenSessionFolderButtonPushed(hTable, sessionArray)

    selectedRow = hTable.SelectedRows;
    sessionObject = sessionArray(selectedRow);
    
    %dataLocations = fieldnames(sessionObject.DataLocation);
    
    dataLocationName = sessionObject.DataLocation(1).Name;
    folderPath = sessionObject.getSessionFolder(dataLocationName);
    
    utility.system.openFolder(folderPath)

end