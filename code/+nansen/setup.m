% Run setup for nansen
matlabVersion = version;
ind = strfind(matlabVersion, '.');
versionAsNumber = strrep(matlabVersion(1:ind(2)+1), '.', '');


if str2double(versionAsNumber) >= 960
    NansenSetupApp % Run app coded in appdesigner
else
    error('Setup requires MATLAB release 2019a or later')
    %setup.App
end 
