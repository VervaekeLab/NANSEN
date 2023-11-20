function updateVariableCatalog(projectDirectory)
    % Remove IsDefaultVariable field
    filePath = fullfile(projectDirectory, 'configurations', 'filepath_settings.mat');
    S = load(filePath);

    S.Data = rmfield(S.Data, 'IsDefaultVariable');
    save(filePath, '-struct', "S")
end

%     S = struct(...
%         'VariableName', '', ...         % Name of variable
%         'DataLocation', '', ...         % todo: rename DataLocationName? Name of datalocation where variable is stored.
%         'DataLocationUuid', '', ...     % uuid of datalocation variable belongs to (internal)
%         'Subfolder', '', ...            % Subfolder within sessionfolder where variable is saved to file (optional)
%         'FileNameExpression', '', ...   % Part of filename to reckognize variable from (optional)
%         'FileType', '', ...             % File type of variable
%         'FileAdapter', '', ...          % File adapter to use for loading and saving variable
%         'DataType', '', ...             % Datatype of variable: Will depend on file adapter
%         'Alias', '', ...                % alias or "nickname" for varibles
%         'GroupName', '', ...            % Placeholder...
%         'IsCustom', false, ...          % Is variable custom, i.e user made?
%         'IsInternal', false, ...        % Flag for internal variables
%         'IsFavorite', false );          % Flag for favorited variables
