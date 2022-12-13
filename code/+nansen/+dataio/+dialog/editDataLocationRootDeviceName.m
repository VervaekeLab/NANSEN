function dataLocationRootInfo = editDataLocationRootDeviceName(dataLocationRootInfo)
%editDataLocationRootDeviceName Change disk name for data location root.
%
%   S = editDataLocationRootDeviceName(S) opens a table dialog for editing
%   the disk name for all the datalocation roots in the
%   dataLocationRootInfo struct (S). 

%   Todo
%       [ ] Add some instructions in a textbox
%       [ ] Is it possible to indicate that the diskname is a dropdown?
%       [ ] Update dropdowns if drives are connected or disconnected

    volumeInfo = nansen.external.fex.sysutil.listPhysicalDrives();
    
    % Make table with 2 columns, device name and root path
    dataTable = rmfield(dataLocationRootInfo, 'Key');
    dataTable = orderfields(dataTable, {'DiskName', 'Value'});
    dataTable = struct2table(dataTable);
    
    % Fix data type issue. Todo: Should be done upstream
    for i = 1:size(dataTable, 1)
        if isempty(dataTable.DiskName{i}) && isa(dataTable.DiskName{i}, 'double')
            dataTable.DiskName{i} = '';
        end
    end

    % Get name of all connected volumes, and all volumes in root info
    mountedVolumeNames = volumeInfo.VolumeName;
    otherVolumeNames = string(dataTable.DiskName);
    allVolumeNames = unique(cat(1,mountedVolumeNames, otherVolumeNames));
    allVolumeNames = arrayfun(@(str) char(str), allVolumeNames, 'uni', 0);

    % Create and configure a figure
    hFigure = figure('Menubar', 'none');
    hFigure.Position = [1,1,1000,200];
    uim.utility.centerFigureOnScreen(hFigure)
    hFigure.NumberTitle = 'off'; 
    hFigure.Name = 'Select Disk Name for Root Path';

    % Create and configure the table.
    hTable = uim.widget.StylableTable('Parent', hFigure, ...
        'Editable', true, ...
        'RowHeight', 20, ...
        'FontSize', 8, ...
        'FontName', 'helvetica', ...
        'FontName', 'avenir next', ...
        'SelectionMode', 'discontiguous', ...
        'Sortable', false, ...
        'Units', 'pixel', ...
        'ColumnResizePolicy', 'subsequent', ...
        'Position', [20 20 960 160] );
    
    hTable.Units = 'normalized';
    hTable.changeColumnWidths([200,750]);
    hTable.ColumnResizePolicy = 'last';

    % Format device name as dropdown, add 
    colDataTypes = {'popup', 'char'};
    colFormatData = {allVolumeNames, ''};

    % Update the column formatting properties
    hTable.ColumnName = {'Select Disk Name', 'Root Path'};
    hTable.ColumnEditable = [true, false];
    hTable.ColumnFormat = colDataTypes;
    hTable.ColumnFormatData = colFormatData;
    
    hTable.Data = table2cell(dataTable);
    
    % Add some interactivity callbacks
    hTable.CellEditCallback = @(src, evt, info) onTableDataChanged(src, evt, volumeInfo);
    addlistener(hTable, 'MouseMotion', @onMouseMoveInTable);
    
    % When table is closed, return updated dataLocationRootInfo
    hFigure.CloseRequestFcn = @(src, evt) uiresume(src); 
    uiwait(hFigure)

    tableData = hTable.Data;
    
    for i = 1:size(tableData, 1)
        dataLocationRootInfo(i).Value = tableData{i,2};
        dataLocationRootInfo(i).DiskName = tableData{i,1};
    end

    delete(hFigure)
end

function onMouseMoveInTable(src, evt)
    
    hFigure = ancestor(src, 'figure');
    
    thisCol = evt.Cell(2);
    if thisCol == 1
        hFigure.Pointer = 'hand';
    else
        hFigure.Pointer = 'arrow';
    end
end

function onTableDataChanged(src, evt, volumeInfo)
    
    rowIdx = evt.Indices(1);
    colIdx = evt.Indices(2);

    assert(colIdx == 1, 'Something unexpected happen!')
    
    currentRoot = src.Data{rowIdx, 2};

    % Determine what format old string is:
    isCurrentPathMacStyle = ~isempty(regexp(currentRoot, '^/Volumes', 'match'));
    isCurrentPathPcStyle = ~isempty(regexp(currentRoot, '^\w{1}\:', 'match'));
    
    if isCurrentPathMacStyle && ispc
        oldString = ['\Volumes\', evt.OldValue];
        isMatch = volumeInfo.VolumeName == string(evt.NewValue);
        newString = volumeInfo.DeviceID(isMatch);
        currentRoot = strrep(currentRoot, '/', '\');
        
    elseif isCurrentPathMacStyle && ismac
        oldString = sprintf('/Volumes/%s/', evt.OldValue);
        newString = sprintf('/Volumes/%s/', evt.NewValue);
    
    elseif isCurrentPathPcStyle && ispc
        oldString = currentRoot(1:2);
        isMatch = volumeInfo.VolumeName == string(evt.NewValue);
        newString = volumeInfo.DeviceID(isMatch);
    
    elseif isCurrentPathPcStyle && ismac
        oldString = regexp(currentRoot, '^\w{1}\:', 'match');
        newString = sprintf('Volumes/%s', evt.NewValue);
        currentRoot = strrep(currentRoot, '\', '/');

    elseif isunix
        error('Not implemented yet')
    end
    
    currentRoot = replace(currentRoot, oldString, newString);

    src.Data{rowIdx, 2} = currentRoot;    
end