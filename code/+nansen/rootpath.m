function folderPath = rootpath()
%rootpath Return the absolute path for the nansen repository folder.
    folderPath = fileparts( mfilename( 'fullpath' ) );
    folderPath = utility.path.getAncestorDir(folderPath, 2);
end