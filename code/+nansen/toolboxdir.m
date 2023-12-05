function pathName = toolboxdir()
%toolboxdir Return the absolute path for the nansen toolbox folder.
    pathName = utility.path.getAncestorDir(mfilename( 'fullpath' ), 2);
end