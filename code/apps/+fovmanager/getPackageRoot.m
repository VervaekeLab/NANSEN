function folderPath = getPackageRoot()
%GETPACKAGEROOT Return root path of current package
%   folderPath = packageName.getPackageRoot()
    folderPath = fileparts(mfilename('fullpath'));
end