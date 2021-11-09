function pathStr = localpath(keyword)

pkgRootPath = fileparts(mfilename('fullpath'));

switch keyword

    case 'toolbar_icons'
        pathStr = fullfile(pkgRootPath, 'resources', 'icons');

end
