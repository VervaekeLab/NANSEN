function pathStr = localpath(keyword)

% Todo: Do I need this?
% Pro: Can access paths to local files/folders that is not on matlab
% path, i.e for resource files. Also, having it hardcoded in one file makes
% it easier if folder structures are changed later, because code in scripts
% that call this function is not influenced.
% Con: Am I overthinking this. Maybe just don't change anything....

pkgRootPath = fileparts(mfilename('fullpath'));

switch keyword
    
    case 'brain_atlas'
        pathStr = fullfile(pkgRootPath, 'resources', 'brain_atlas');
    case 'toolbar_icons'
        pathStr = fullfile(pkgRootPath, 'resources', 'icons');
    case 'paxinos-atlas'
        pathStr = fullfile(fovmanager.localpath('brain_atlas'));
        pathStr = fullfile(pathStr, 'paxinos');
%     case 'allen-map'
%         pathStr = fullfile(fovmanager.localpath('brain_atlas'));
%         pathStr = fullfile(pathStr, 'allen');

end
