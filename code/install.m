% ! ! This should only be run if the repository was cloned from GitHub ! !
%
% Please note:
%
%   1) If the userpath is empty, this script will update userpath
%   2) This script will download dependencies for NANSEN
%   3) This script will add NANSEN and dependencies to the search path

% Check that userpath is not empty (can happen on linux platforms)
if isempty(userpath)
    nansen.internal.setup.resolveEmptyUserpath()
end

% Install required (FEX) dependencies
fprintf('Installing FileExchange dependencies...\n')
nansen.internal.setup.installDependencies()

% Add folder to path if it was not added already
toolboxFolderPath = fileparts(mfilename('fullpath'));
if ~contains(path, toolboxFolderPath)
    addpath(genpath(toolboxFolderPath))
    savepath()
end

% Open Setup Wizard
fprintf('Opening NANSEN''s Setup Wizard...\n')
nansen.setup()
