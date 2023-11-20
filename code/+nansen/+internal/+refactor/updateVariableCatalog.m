function updateVariableCatalog(projectDirectory)
    % Remove IsDefaultVariable field
    filePath = fullfile(projectDirectory, 'configurations', 'filepath_settings.mat');
    S = load(filePath);

    S.Data = rmfield(S.Data, 'IsDefaultVariable');
    save(filePath, '-struct', "S")
end