function folder = rootpath()

    folder = fileparts( mfilename( 'fullpath' ) );

    % Todo (need to change all references to rootpath across code files): 
    % Now go two steps up:
    % folder = utility.path.getAncestorDir(folder, 1);
    
end