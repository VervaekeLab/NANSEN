% Run setup for nansen
matlabVersion = version;
ind = strfind(matlabVersion, '.');
versionAsNumber = strrep(matlabVersion(1:ind(2)+1), '.', '');


if str2double(versionAsNumber) >= 950
    NansenSetupApp % Run app coded in appdesigner
else
    error('Setup requires MATLAB release 2018b or later')
    %setup.App
end 
