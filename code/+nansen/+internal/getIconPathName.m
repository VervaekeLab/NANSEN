function pathName = getIconPathName(iconFileName)
    pathName = fullfile(nansen.rootpath, 'code', 'resources', ...
        'icons', 'setup', iconFileName);
end