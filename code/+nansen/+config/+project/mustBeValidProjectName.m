function mustBeValidProjectName(name)
% mustBeValidProjectName Validate that a project name adheres to MATLAB naming conventions.
%
%   MUSTBEVALIDPROJECTNAME(NAME) verifies that NAME is a valid MATLAB identifier.
%   A valid project name must start with a letter and can contain only alphanumeric
%   characters and underscores. If NAME does not meet these criteria, an error is thrown.
%
%   Example:
%       mustBeValidProjectName('My_Project1')   % Valid name
%       mustBeValidProjectName('1InvalidName')    % Throws an error

    % Create a valid MATLAB identifier from the provided name.
    validName = matlab.lang.makeValidName(name);
    
    % Compare the provided name with its valid MATLAB identifier.
    if ~isequal(name, validName)
        error('NANSEN:validator:InvalidProjectName', ...
              ['Invalid project name "%s". A project name must consist of ', ...
              'alphanumeric characters and underscores only, start with a ', ...
              'letter, and contain no other characters.'], name);
    end
end
