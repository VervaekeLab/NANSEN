function infoTable = listMountedDrives()
%listMountedDrives List mounted drives present on system
%
%   infoTable = sysutil.drive.listMountedDrives() returns a table which contains
%       the following variables:
%
%       DeviceID        : The device id (drive letter / disk number)
%       VolumeName      : Name of drive / volume
%       SerialNumber    : Serial number of drive / volume
%       FileSystem      : File system, i.e ntfs, ex-fat, apfs (Note: only for windows)
%       Size            : Physical storage size
%       SizeUnit        : Actual unit for size, i.e MB, GB, TB

% References
%   Mac : https://ss64.com/osx/diskutil.html
%   PC  : https://learn.microsoft.com/en-us/windows/win32/cimwin32prov/win32-logicaldisk

% Written by Eivind Hennestad | 2022-11-24
% Updated by Claude Sonnet 4.5 | 2025-11-13

% Todo:
% [ ] Add internal, external (how to get this on pc?)
% [ ] On mac, file system is not correct...
% [ ] On mac, don't show hidden partitions?
% [ ] On mac, add serial number
% [ ] On mac, parse result when using -plist instead?
% [ ] On linux, add serial number (use lsblk -o +UUID or blkid)

    try
        if ismac % Use diskutil
            [~, infoStr] = system('diskutil list physical');
            infoTable = convertListToTableMac(infoStr);
    
        elseif ispc % Use PowerShell Get-Volume
            [~, infoStr] = system(['powershell -Command "Get-Volume | ', ...
                'Where-Object {$_.DriveLetter} | ', ...
                'Select-Object DriveLetter, FileSystemLabel, FileSystem, ', ...
                'Size, DriveType | ', ...
                'ConvertTo-Csv -NoTypeInformation"']);
            infoTable = convertListToTablePc(infoStr);
    
        elseif isunix % Use lsblk
            [~, infoStr] = system('lsblk -o NAME,LABEL,FSTYPE,SIZE,TYPE,MOUNTPOINT -P -b');
            infoTable = convertListToTableLinux(infoStr);
        end

        infoTable = postprocessTable(infoTable);

    catch MECause
        ME = MException('SYSTEMUTIL:ListMountedDrives:FailedToListDrives', ...
            'Failed to list mounted drives using system command.');
        ME = ME.addCause(MECause);
        throw(ME)
    end
end

% % Local functions:

function infoTable = convertListToTableMac(infoStr)
%convertListToTableMac Split string containing list of drive info into a table
%
%   Ad hoc conversion of string into table.

    % Remove some random(?) unicode symbols
    infoStr = strrep(infoStr, char(8296), ' ');
    infoStr = strrep(infoStr, char(8297), ' ');
    infoStr = strrep(infoStr, '*', ' ');

    infostrCell = splitStringIntoRows(infoStr);

    rowIdxRemove = strncmp(infostrCell, '/dev', 4);

    % Keep track of rows belonging to same drive / device
    deviceNumber = cumsum(rowIdxRemove);
    deviceHeaders = infostrCell(rowIdxRemove);

    infostrCell(rowIdxRemove) = [];  % Remove title rows
    deviceNumber(rowIdxRemove) = [];

    % Use first header row to find index locations for splitting each row
    % into cells. Find indices where columns start and stop:
    colStart = regexp(infostrCell{1}, '(?<= )\S{1}', 'start'); % Space before char
    colStop = regexp(infostrCell{1}, '\S{1}(?= )', 'start'); % Space after char

    % Columns 1-2 are right aligned, columns 3-5 are left-aligned
    colStart = [1, colStop(1:2)+1, colStart(3:4)];

    rowIdxRemove = strncmp(infostrCell, '#', 1);
    infostrCell(rowIdxRemove) = [];  % Remove header rows before splitting
    deviceNumber(rowIdxRemove) = [];

    C = splitRowsIntoColumns(infostrCell, colStart);

    % Remove first column.
    C(:, 1) = [];

    % Split columns with disk size into size and unit
    colIdx = size(C, 2) + 1;
    for i = 2:size(C, 1)
        C(i, [3,colIdx]) = strsplit(C{i, 3}, ' ');
    end

    % Get the drive type
    expression = '\((.*)\)';
    driveType = regexp(deviceHeaders, expression, 'tokens');
    driveTypeColumnData = arrayfun(@(x) driveType{x}{1}{1}, deviceNumber, 'uni', 0);

    colIdx = size(C, 2) + 1;
    C(:, colIdx) = driveTypeColumnData;

    % Set variable names and create table
    variableNames = {'FileSystem', 'VolumeName', 'Size', 'DeviceID', 'SizeUnit', 'DriveType'};
    infoTable = cell2table(C(2:end,:), 'VariableNames', variableNames);

    % Convert some variables into numbers
    infoTable.Size = str2double( infoTable.Size );

    % Todo: Find serial number
    serialNumber = repmat(missing, size(C, 1)-1, 1);
    infoTable = addvars(infoTable, serialNumber, 'NewVariableNames', 'SerialNumber');
end

function infoTable = convertListToTablePc(infoStr)

    % Parse CSV output from PowerShell Get-Volume
    infostrCell = splitStringIntoRows(infoStr);

    % Remove quotes and split by comma
    C = cellfun(@(row) strsplit(strrep(row, '"', ''), ','), ...
        infostrCell, 'UniformOutput', false);
    C = vertcat(C{:});

    % Rename columns to match expected format
    C{1,1} = 'DeviceID';
    C{1,2} = 'VolumeName';
    C{1,3} = 'FileSystem';
    C{1,4} = 'Size';
    C{1,5} = 'DriveType';

    % Add colon to drive letters
    C(2:end, 1) = cellfun(@(x) [x, ':'], C(2:end, 1), 'UniformOutput', false);

    infoTable = cell2table(C(2:end,:), 'VariableNames', C(1,:));

    % Compute size and add unit
    infoTable.Size = str2double(infoTable.Size);

    power = floor(log10(infoTable.Size)/3)*3;
    infoTable.Size = infoTable.Size ./ 10.^(power);

    sizeUnit = categorical(power, [3, 6, 9, 12], {'kB', 'MB', 'GB', 'TB'});
    infoTable = addvars(infoTable, sizeUnit, 'NewVariableNames', 'SizeUnit');

    % Add empty SerialNumber column (Get-Volume doesn't provide this easily)
    serialNumber = repmat(missing, size(infoTable, 1), 1);
    infoTable = addvars(infoTable, serialNumber, 'NewVariableNames', 'SerialNumber');

    % Label drive types (handle empty values)
    for i = 1:height(infoTable)
        if isempty(infoTable.DriveType{i}) || strcmp(infoTable.DriveType{i}, '')
            infoTable.DriveType{i} = '3'; % Default to Fixed for empty values
        end
    end
    infoTable.DriveType = labelDriveTypePC(infoTable.DriveType);
end

function infoStrCell = splitStringIntoRows(infoStr)

    % Split string into rows
    infoStrCell = textscan( infoStr, '%s', 'delimiter', '\n' );
    infoStrCell = infoStrCell{1};

    % Remove empty cells
    infoStrCell = removeEmptyCells(infoStrCell);
end

function C = splitRowsIntoColumns(infostrCell, splitIdx)

    numRows = numel(infostrCell);
    numColumns = numel(splitIdx);

    strLength = max( cellfun(@(c) numel(c), infostrCell) );

    % Make sure all rows are the same length
    infostrCell = cellfun(@(str) pad(str, strLength), infostrCell, 'uni', 0);

    % Add length of row to split index (Add 1, see below)
    splitIdx = [splitIdx, strLength+1];

    C = cell(numRows, numColumns);

    for i = 1:numColumns
        colIdx = splitIdx(i) : splitIdx(i+1)-1;
        C(:, i) = cellfun(@(str) str(colIdx), infostrCell, 'uni', 0);
    end

    C = strtrim(C); % Remove trailing whitespace from all cells
end

function driveType = labelDriveTypePC(driveType)

    % Map Get-Volume DriveType values to descriptive names
    % Get-Volume returns: Unknown=0, Fixed=3, Removable=2, CD-ROM=5, Network=4

    driveType = categorical(driveType, {'0','2','3','4','5'}, ...
        {'Unknown', 'Removable', 'Fixed', 'Network', 'CD-ROM'});
end

function infoTable = convertListToTableLinux(infoStr)

    % Parse lsblk output (key="value" format)
    infostrCell = splitStringIntoRows(infoStr);

    % Keep only mounted drives (has MOUNTPOINT)
    mountedIdx = contains(infostrCell, 'MOUNTPOINT="/') | contains(infostrCell, 'MOUNTPOINT="/boot');
    infostrCell = infostrCell(mountedIdx);

    if isempty(infostrCell)
        % Create empty table with correct structure
        infoTable = cell2table(cell(0, 7), 'VariableNames', ...
            {'DeviceID', 'VolumeName', 'SerialNumber', 'FileSystem', 'Size', 'SizeUnit', 'DriveType'});
        return;
    end

    numRows = numel(infostrCell);
    C = cell(numRows, 7);

    for i = 1:numRows
        row = infostrCell{i};

        % Extract key-value pairs
        name = extractValue(row, 'NAME');
        label = extractValue(row, 'LABEL');
        fstype = extractValue(row, 'FSTYPE');
        sizeBytes = extractValue(row, 'SIZE');
        driveType = extractValue(row, 'TYPE');
        mountpoint = extractValue(row, 'MOUNTPOINT');

        % DeviceID: /dev/name
        C{i, 1} = ['/dev/', name];

        % VolumeName: use label if available, otherwise mountpoint
        if isempty(label)
            C{i, 2} = mountpoint;
        else
            C{i, 2} = label;
        end

        % SerialNumber: not easily available with lsblk
        C{i, 3} = '';

        % FileSystem
        C{i, 4} = fstype;

        % Size (in bytes, will convert later)
        C{i, 5} = sizeBytes;

        % SizeUnit (placeholder, will be computed)
        C{i, 6} = 'B';

        % DriveType
        if strcmp(driveType, 'disk')
            C{i, 7} = 'Fixed';
        elseif strcmp(driveType, 'part')
            C{i, 7} = 'Partition';
        elseif strcmp(driveType, 'loop')
            C{i, 7} = 'Loop';
        elseif strcmp(driveType, 'rom')
            C{i, 7} = 'CD-ROM';
        else
            C{i, 7} = driveType;
        end
    end

    infoTable = cell2table(C, 'VariableNames', ...
        {'DeviceID', 'VolumeName', 'SerialNumber', 'FileSystem', 'Size', 'SizeUnit', 'DriveType'});

    % Convert size to numeric and compute appropriate unit
    infoTable.Size = str2double(infoTable.Size);

    power = floor(log10(infoTable.Size)/3)*3;
    infoTable.Size = infoTable.Size ./ 10.^(power);

    sizeUnit = categorical(power, [3, 6, 9, 12], {'kB', 'MB', 'GB', 'TB'});
    infoTable.SizeUnit = sizeUnit;
end

function value = extractValue(str, key)
    % Extract value from KEY="VALUE" format
    pattern = [key, '="([^"]*)"'];
    tokens = regexp(str, pattern, 'tokens');
    if ~isempty(tokens)
        value = tokens{1}{1};
    else
        value = '';
    end
end

function infoTable = postprocessTable(infoTable)

    % Convert the rest of the variables into strings
    infoTable.FileSystem = string(infoTable.FileSystem);
    infoTable.VolumeName = string(infoTable.VolumeName);
    infoTable.SizeUnit = categorical(infoTable.SizeUnit);
    infoTable.DeviceID = string(infoTable.DeviceID);
    infoTable.SerialNumber = string(infoTable.SerialNumber);
    infoTable.DriveType = string(infoTable.DriveType);

    % Reorder variables into standard order
    variableOrder = {'DeviceID', 'VolumeName', 'SerialNumber', ...
                        'FileSystem', 'Size', 'SizeUnit', 'DriveType'};
    infoTable = infoTable(:, variableOrder);

    % Add row names
    infoTable.Properties.RowNames = arrayfun(@num2str, 1:size(infoTable,1), 'uni', 0)';
end

function cellArray = removeEmptyCells(cellArray)
    isEmptyCell = cellfun(@isempty, cellArray);
    cellArray( isEmptyCell ) = [];
end
