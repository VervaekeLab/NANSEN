function ME = NotImplemented(description)
% NotImplemented - Creates an exception for unimplemented features.
%
% Syntax:
%   ME = NotImplemented(description) Returns a formatted MException
%   indicating that a feature is not implemented.
%
% Input Arguments:
%   description (string, optional) - A description of the unimplemented
%   feature.
%
% Output Arguments:
%   ME (MException) - The exception object that contains the error message.

    arguments
        description (1,1) string = ""
    end

    if description ~= ""
        description = sprintf(": %s", description);
    else
        description = ".";
    end

    ME = MException(...
        "NANSEN:common:NotImplementedError", ...
        "This feature is not implemented yet%s" + ...
        newline + ...
        "If you encounter this error and need this feature, " + ...
        "please open an issue in the NANSEN GitHub repository.", ...
        description);
end
