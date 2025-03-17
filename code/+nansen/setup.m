function setup(userName)
    arguments
        userName (1,1) string = ""
    end

    userName = char(userName);

    try
        nansen.internal.user.NansenUserSession.instance(userName);
    catch ME
        warning(ME.identifier, '%s', ME.message)
    end

    % Run setup for nansen
    matlabVersion = version;
    ind = strfind(matlabVersion, '.');
    versionAsNumber = strrep(matlabVersion(1:ind(2)+1), '.', '');
    
    nansen.addpath()
    
    if str2double(versionAsNumber) >= 960
        nansen.app.setup.SetupWizard % Run app coded in appdesigner
    else
        error('Setup requires MATLAB release 2019a or later')
        %setup.App
    end
end

% Todo
% if ~verLessThan('matlab','9.6') && ~isMATLABReleaseOlderThan("R2019a")
