function installProject(projectRootFolder, dataRootFolder, options)
    arguments
        projectRootFolder (1,1) string {mustBeFolder}
        dataRootFolder (1,1) string = missing
        options.NansenUserName (1,1) string = "default"
    end

    if ismissing(dataRootFolder)
        dataRootFolder = uigetdir();
    end

    nansenUserSession = nansen.internal.user.NansenUserSession.instance(options.NansenUserName);
    projectManager = nansenUserSession.getProjectManager();

    L = dir(fullfile(projectRootFolder, '**', 'project.nansen.json'));
    try
        if numel(L) == 1
            projectMeta = jsondecode(fileread(fullfile(L.folder, L.name)));
            projectName = projectManager.importProject(L.folder);
        elseif isempty(L)
            error('No project was found in the given directory: "%s".', projectRootFolder)
        else
            error('More than one project was found in the given directory: "%s".', projectRootFolder)
        end
    catch ME
        if string(ME.identifier) == "Nansen:ProjectExists"
            projectName = projectMeta.Properties.ShortName;
        else
            rethrow(ME)
        end
    end

    project = projectManager.getProjectObject(projectName);
    dlm = project.DataLocationModel;

    if isfield(projectMeta.Properties, 'OriginalRootPath')
        dlm.configureLocalRootpath(dataRootFolder, projectMeta.Properties.OriginalRootPath)
    end
end
