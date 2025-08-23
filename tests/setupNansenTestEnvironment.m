function [status, teardownObjects] = setupNansenTestEnvironment(options)

    arguments
        options.ClearAll = false
    end

    % Get permission from user to do "close all force", "clear all"
    if ~options.ClearAll
        fprintf('Running the NANSEN test suite will close all figures and clear all variables.\n')
        answer = input('Enter y or n: ', 's');
        if ~strcmp(answer, 'y')
            error('Test Suite aborted by user')
        end
    end

    close all force
    clear all %#ok<CLALL>
    clear classes %#ok<CLCLS>
    
    status = 0;

    % Initialize teardown objects.
    teardownObjects = onCleanup.empty;

    try
        %% Get the rootpath of NANSEN
        nansenRootPath = nansen.rootpath();

        %% Get the current search path
        searchPathStr = path;

        %% Create temporary folder to user for userpath
        temporaryUserpath = tempname;
        if ~isfolder(temporaryUserpath); mkdir(temporaryUserpath); end
        utility.filewrite(fullfile(temporaryUserpath,'test.txt'), 'test')
        fprintf('Created temporary folder "%s"\n', temporaryUserpath)
        
        teardownObjects(end+1) = onCleanup(...
            @(pathName) deleteTemporaryUserPath(temporaryUserpath));
        
        %% Configure temporary userpath
        currentUserpath = userpath();
        fprintf('Current userpath is "%s"\n', currentUserpath)
        userpath(temporaryUserpath)
        fprintf('New userpath is "%s"\n', userpath)

        teardownObjects(end+1) = onCleanup(...
            @(pathName) resetUserPath(currentUserpath) );
    
        %% Create a "test" UserSession
        nansen.internal.user.NansenUserSession.instance("", "reset");
        warning('off', 'Nansen:NoProjectsAvailable')
        nansen.internal.user.NansenUserSession.instance("test");
        warning('on', 'Nansen:NoProjectsAvailable')
        teardownObjects(end+1) = onCleanup( @resetTestUserSession );

        %% Reset search path to default factory path
        restoredefaultpath()
        teardownObjects(end+1) = onCleanup( @(str) path(searchPathStr) );
        
        %% Re-add nansen to path
        addpath(genpath(nansenRootPath))

    catch ME
        disp(getReport(ME, 'extended'))
        status = 1;
        
        clear teardownObjects; 
        teardownObjects = [];
    end
end

function resetUserPath(pathName)
    userpath(pathName)
    fprintf('Reset userpath to "%s"\n', userpath)
end

function deleteTemporaryUserPath(pathName)
    rmdir(pathName, "s")
    fprintf('Deleted temporary folder: "%s"\n', pathName)
end

function resetTestUserSession()
    userSession = nansen.internal.user.NansenUserSession.instance();
    assert(userSession.CurrentUserName == "test")
    
    testPreferenceFolder = userSession.getPrefdir("test");
    nansen.internal.user.NansenUserSession.instance("", "reset");
    
    % Delete the preference folder for the "test" user.
    rmdir(testPreferenceFolder, "s")

    fprintf('Removed UserSession "test"\n')
end
