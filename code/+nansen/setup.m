% Run setup for nansen

matlabVersion = version;
ind = strfind(matlabVersion, '.');
versionAsNumber = strrep(matlabVersion(1:ind(2)+1), '.', '');

% Todo:

if str2double(versionAsNumber) >= 950
    NansenSetup
else
    setup.App
end 
