% Check that userpath is not empty (linux)
if isempty(userpath)
    nansen.internal.setup.resolveEmptyUserpath()
end

% Install required (FEX) dependencies
fprintf('Installing FileExchange dependencies...\n')
nansen.internal.setup.installDependencies()

% Open Setup Wizard
fprintf('Opening NANSEN''s Setup Wizard...\n')
nansen.setup()


