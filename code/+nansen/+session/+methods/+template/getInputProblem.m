function problem = getInputProblem(values, methodsFolder)
%getInputProblem Get the reason a new method cannot be created from given values
%
%   problem = getInputProblem(values, methodsFolder) returns text giving
%   the reason a new method cannot be created from the values entered in
%   the dialog of createNewSessionMethod. The text is "" if it can be
%   created.
%
%   The method name becomes the name of a function or class, and each name
%   in MenuSubLocation becomes the name of a namespace, so they have to be
%   valid MATLAB identifiers. MenuSubLocation may be empty. A method must
%   not already exist at the same location, because the template would
%   replace its file.
%
%   Input Arguments:
%       values : Struct with the fields MethodName, MenuLocation and
%           MenuSubLocation.
%       methodsFolder : Root folder of the methods of the project.
%
%   See also nansen.session.methods.template.createNewSessionMethod
%   nansen.session.methods.template.getTargetFilePath

    arguments
        values (1,1) struct
        methodsFolder (1,1) string
    end

    [filePath, subLocationNames] = ...
        nansen.session.methods.template.getTargetFilePath(values, methodsFolder);
    methodName = string(values.MethodName);

    problem = "";

    if strlength(methodName) == 0
        problem = "Enter a name for the method.";

    elseif ~isvarname(methodName)
        problem = sprintf("'%s' is not a valid method name. A name must start " + ...
            "with a letter and contain only letters, numbers and underscores.", methodName);

    elseif ~all(arrayfun(@isvarname, subLocationNames))
        problem = "Menu Sub Location must be a comma-separated list of names. Each name " + ...
            "must start with a letter and contain only letters, numbers and underscores.";

    elseif isfile(filePath)
        problem = sprintf("A method named '%s' already exists in this menu location. " + ...
            "Choose another name.", methodName);
    end
end
