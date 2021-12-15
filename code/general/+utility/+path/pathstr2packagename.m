function packageName = pathstr2packagename(pathStr)
%pathstr2packagename Convert a path string to a string with name of package
%
%       packageName = pathstr2packagename(pathStr)
%
%   EXAMPLE:
% 
%    pathStr =
%       '/Users/eivinhen/PhD/Programmering/MATLAB/VervaekeLab_Github/NANSEN/code/+nansen/+session/+methods/+data/+open'
%
%    packageName = utility.path.pathstr2packagename(pathStr)
%
%    packageName =
%       'nansen.session.methods.data.open'


    assert(isfolder(pathStr), 'Path must point to a folder.')
       
    % Split pathstr by foldernames
    splitFolderNames = strsplit(pathStr, filesep);
    
    % Find all folders that are a package
    isPackage = cellfun(@(str) strncmp(str, '+', 1), splitFolderNames );
    
    % Create output string
    packageFolderNames = splitFolderNames(isPackage);
    packageFolderNames = strrep(packageFolderNames, '+', '');
    
    packageName = strjoin(packageFolderNames, '.');

end