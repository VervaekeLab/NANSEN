function codespell()

    projectDirectory = nansentools.projectdir();

    ignoreFileListing = dir(fullfile(projectDirectory, '*', '.codespell_ignore'));
    
    nvOptions = {};
    if ~isempty(ignoreFileListing)
        ignoreFilePath = fullfile(ignoreFileListing.folder, ignoreFileListing.name);
        nvOptions = [nvOptions, "IgnoreFilePath", ignoreFilePath];
    end

    matbox.tasks.codespellToolbox(projectDirectory, nvOptions{:});
end
