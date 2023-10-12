function infoTable = listPhysicalDrives()
%listPhysicalDrives List physical drives present on system
%
%   infoTable = system.listPhysicalDrives() returns a table which contains
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

% Todo: 
% [ ] Implement for linux systems
% [ ] Add internal, external (how to get this on pc?)
% [ ] On mac, file system is not correct...
% [ ] On mac, don't show hidden partitions?
% [ ] On windows, is the serial number complete?
% [ ] On mac, add serial number
% [ ] On mac, parse result when using -plist instead?
% [ ] On windows, use 'where drivetype=3' i.e 'wmic logicaldisk where drivetype=3 get ...'

    if ismac
        [~, infoStr] = system('diskutil list physical');
        infoTable = convertListToTableMac(infoStr);

    elseif ispc
        [~, infoStr] = system(['wmic logicaldisk get DeviceId, ', ...
            'VolumeName, VolumeSerialNumber, FileSystem, Size, ', ...
            'DriveType' ] );
        infoTable = convertListToTablePc(infoStr);

    elseif isunix
        error('Not implemented for unix systems')
    end

    infoTable = postprocessTable(infoTable);
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

    % Set varible names and create table
    variableNames = {'FileSystem', 'VolumeName', 'Size', 'DeviceID', 'SizeUnit', 'DriveType'};
    infoTable = cell2table(C(2:end,:), 'VariableNames', variableNames);

    % Convert some variables into numbers
    infoTable.Size = str2double( infoTable.Size );

    % Todo: Find serial number
    serialNumber = repmat(missing, size(C, 1)-1, 1);
    infoTable = addvars(infoTable, serialNumber, 'NewVariableNames', 'SerialNumber');
end

function infoTable = convertListToTablePc(infoStr)

    infostrCell = splitStringIntoRows(infoStr);

    % Detect indices where rows should be split
    colStart = regexp(infostrCell{1}, '(?<=\ )\S{1}', 'start');
    colStart = [1, colStart];

    C = splitRowsIntoColumns(infostrCell, colStart);

    %C{1,6} = 'SerialNumber'; % Shorten name
    C = strrep(C, 'VolumeSerialNumber', 'SerialNumber');
    infoTable = cell2table(C(2:end,:), 'VariableNames',C(1,:));

    % Compute size and add unit
    infoTable.Size = str2double( infoTable.Size );

    power = floor(log10(infoTable.Size)/3)*3;
    infoTable.Size = infoTable.Size ./ 10.^(power);

    sizeUnit = categorical(power, [3, 6, 9, 12], {'kB', 'MB', 'GB', 'TB'});
    infoTable = addvars(infoTable, sizeUnit, 'NewVariableNames', 'SizeUnit');
    
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
    
    %     0	Unknown
    %     1	No Root Directory
    %     2	Removable Disk
    %     3	Local Disk
    %     4	Network Drive
    %     5	Compact Disc
    %     6	RAM Disk

    driveType = categorical(driveType, {'0','1','2','3','4','5','6'}, ...
        {'Unknown', 'No Root Directory', 'Removable Disk', 'Local Disk', ...
         'Network Drive', 'Compact Disc', 'RAM Disk'});
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

% % % function filename = filewrite(filename, textString)
% % %     
% % %     if isempty(filename)
% % %         filename = [tempname, '.txt'];
% % %     end
% % %     
% % %     fid = fopen(filename, 'w');
% % %     fwrite(fid, textString);
% % %     fclose(fid);
% % % end
% % % 
% % %         [~, infoStr] = system('diskutil list -plist physical');
% % % 
% % %         filename = [tempname, '.xml'];
% % %         filename = filewrite(filename, infoStr);
% % %     
% % %         convertedValue = readstruct(filename);