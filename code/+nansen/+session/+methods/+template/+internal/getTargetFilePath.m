function [filePath, subLocationNames] = getTargetFilePath(values, methodsFolder)
%getTargetFilePath Get the file a new method is saved to
%
%   [filePath, subLocationNames] = getTargetFilePath(values, methodsFolder)
%   returns the path of the file for the method described by values. The
%   file is in a namespace named after MenuLocation, inside one nested
%   namespace for each comma-separated name in MenuSubLocation.
%
%   Input Arguments:
%       values : Struct with the fields MethodName, MenuLocation and
%           MenuSubLocation, as entered in the dialog of
%           createNewSessionMethod.
%       methodsFolder : Root folder of the methods of the project.
%
%   Output Arguments:
%       filePath : Path of the file for the new method.
%       subLocationNames : String array with the names in MenuSubLocation.
%           It is empty if MenuSubLocation is empty.
%
%   See also nansen.session.methods.template.createNewSessionMethod

    arguments
        values (1,1) struct
        methodsFolder (1,1) string
    end

    subLocationText = strip(string(values.MenuSubLocation));

    if strlength(subLocationText) == 0
        subLocationNames = string.empty(1, 0);
    else
        subLocationNames = strip(split(subLocationText, ","))';
    end

    namespaceFolders = "+" + [string(values.MenuLocation), subLocationNames];
    fileName = string(values.MethodName) + ".m";
    filePath = fullfile(methodsFolder, join(namespaceFolders, filesep), fileName);
end
