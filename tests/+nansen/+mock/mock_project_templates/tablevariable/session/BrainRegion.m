function value = BrainRegion(sessionObject)
%BRAINREGION Get value for BrainRegion
%   Detailed explanation goes here
    
    % Initialize output value with the default value.
    value = {'N/A'};                 % Please do not edit this line
    
    % Return default value if no input is given (used during config).
    if nargin < 1; return; end	% Please do not edit this line
    
    % Insert your code here:
    sessionFolder = sessionObject.getSessionFolder('MockData');
    L = dir(fullfile(sessionFolder, 'ses*_metadata.json'));
    pathName = fullfile(L.folder, L.name);
    info = jsondecode(fileread(pathName));

    value = info.brain_region;
end
