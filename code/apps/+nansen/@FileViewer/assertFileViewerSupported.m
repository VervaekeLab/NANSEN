function assertFileViewerSupported(metaTable)
% assertFileViewerSupported - Verify that the metatable supports file viewing
%
%   This function checks if the provided metatable has the necessary
%   properties to support file viewing functionality. It throws specific
%   errors with clear messages if any requirements are not met.
%
%   Input:
%       metaTable - A nansen.metadata.MetaTable instance to check

    tableProperties = metaTable.VariableNames;

    if ~any(strcmp(tableProperties, 'DataLocation'))
        error('NANSEN:FileViewer:MissingDataLocation', ...
            ['The selected metatable does not contain a DataLocation column. ', ...
            'File viewer requires a DataLocation column to locate files.']);
    end

    if ~strcmpi(metaTable.getTableType, 'session')
        error('NANSEN:FileViewer:UnsupportedTableType', ...
            ['File viewer is only available when viewing the session table. ', ...
            'Current table type: %s'], metaTable.getTableType);
    end

    % Todo: remove this contraint
    if ~any(strcmp(tableProperties, 'sessionID'))
        error('NANSEN:FileViewer:MissingSessionID', ...
            ['The metatable does not contain a sessionID column. ', ...
            'File viewer requires a sessionID column to identify sessions.']);
    end
end
