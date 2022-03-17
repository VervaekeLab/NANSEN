% Run setup for nansen
matlabVersion = version;
ind = strfind(matlabVersion, '.');
versionAsNumber = strrep(matlabVersion(1:ind(2)+1), '.', '');

if str2double(versionAsNumber) >= 960
    NansenSetupApp2 % Run app coded in appdesigner
else
    error('Setup requires MATLAB release 2019a or later')
    %setup.App
end 



% % s = settings();
% % if ~s.hasGroup('nansen')
% %     nansenSettingsGroup = s.addGroup('nansen');
% % else
% %     nansenSettingsGroup = s.nansen;
% % end
% % 
% % if ~nansenSettingsGroup.hasSetting('IsPathSet')
% %     setting_IsPathSet = nansenSettingsGroup.addSetting('IsPathSet');
% %     setting_IsPathSet.TemporaryValue = false;
% % else
% %     setting_IsPathSet = nansenSettingsGroup.IsPathSet;
% % end