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

% Todo
% if ~verLessThan('matlab','9.6') && ~isMATLABReleaseOlderThan("R2019a")