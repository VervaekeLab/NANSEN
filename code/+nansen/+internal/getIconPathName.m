function pathName = getIconPathName(iconFileName)
    pathName = fullfile(nansen.toolboxdir, 'resources', 'icons', ...
        'setup', iconFileName);
end