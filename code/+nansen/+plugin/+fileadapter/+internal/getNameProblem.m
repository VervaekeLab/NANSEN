function problem = getNameProblem(name, targetFolder)
%getNameProblem Get the reason a new file adapter cannot have a given name
%
%   problem = getNameProblem(name, targetFolder) returns text giving the
%   reason a new file adapter with this name cannot be created in
%   targetFolder. The text is "" if it can be created.
%
%   The name of a file adapter becomes the name of a MATLAB class or
%   namespace, so it has to be a valid MATLAB identifier. It also must not
%   belong to a file adapter in targetFolder, because the templates for a
%   new file adapter would replace the files of that file adapter.
%
%   Input Arguments:
%       name : Name of the new file adapter.
%       targetFolder : Folder the new file adapter would be created in.
%
%   See also nansen.plugin.fileadapter.createFileAdapter
%   nansen.plugin.fileadapter.uigetFileAdapterAttributes

    arguments
        name (1,1) string
        targetFolder (1,1) string
    end

    problem = "";

    if strlength(name) == 0
        problem = "Enter a name for the file adapter.";

    elseif ~isvarname(name)
        problem = sprintf("'%s' is not a valid file adapter name. A name must " + ...
            "start with a letter and contain only letters, numbers and underscores.", name);

    elseif isFileAdapterInFolder(name, targetFolder)
        problem = sprintf("A file adapter named '%s' already exists. Choose another name.", name);
    end
end

function tf = isFileAdapterInFolder(name, folderPath)
%isFileAdapterInFolder Check for each form a file adapter can take in a folder
    tf = isfolder(fullfile(folderPath, "+" + name)) ...
        || isfolder(fullfile(folderPath, "@" + name)) ...
        || isfile(fullfile(folderPath, name + ".m"));
end
