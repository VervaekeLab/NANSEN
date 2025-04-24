% ! ! This should only be run if the repository was cloned from GitHub ! !
%
% Please note:
%
%   1) If the userpath is empty, this script will update userpath
%   2) This script will download dependencies for NANSEN
%   3) This script will add NANSEN and dependencies to the search path

function nansen_install(options)

    arguments
        options.SavePath (1,1) logical = true
    end

    nansenProjectFolder = fileparts(mfilename('fullpath')); % Path to nansen codebase
    nansenToolboxFolder = fullfile(nansenProjectFolder, 'code');
    if isfolder(nansenToolboxFolder)
        addpath( genpath(nansenToolboxFolder) )
    else
        error('NANSEN:Setup:CodeFolderNotFound', ...
              'Could not find folder with code for Nansen')
    end
    
    % Check that userpath is not empty (can happen on linux platforms)
    if isempty(userpath)
        nansen.internal.setup.resolveEmptyUserpath()
    end
        
    warnState = warning('off', 'MATLAB:javaclasspath:jarAlreadySpecified');
    warningCleanup = onCleanup(@(state) warning(warnState));
    
    % Use MatBox to install dependencies/requirements
    downloadAndInstallMatBox();

    requirementsInstallationFolder = fullfile(userpath, 'NANSEN', 'Requirements');
    matbox.installRequirements(nansenProjectFolder, 'u', ...
        'InstallationLocation', requirementsInstallationFolder)

    % Add NANSEN toolbox folder to path if it was not added already 
    if ~contains(path(), nansenToolboxFolder)
        addpath(genpath(nansenToolboxFolder))
        savepath()
    end
    if options.SavePath
        savepath()
    end
end

function downloadAndInstallMatBox()
    if ~exist('+matbox/installRequirements', 'file')
        sourceFile = 'https://raw.githubusercontent.com/ehennestad/Matlab-Toolbox-Template/refs/heads/main/tools/tasks/installMatBox.m';
        filePath = websave('installMatBox.m', sourceFile);
        installMatBox('commit')
        rehash()
        delete(filePath);
    end
end
