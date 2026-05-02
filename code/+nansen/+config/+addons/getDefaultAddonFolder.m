function addonFolder = getDefaultAddonFolder()
%getDefaultAddonFolder Return the default folder for NANSEN add-ons.

    userPathFolder = userpath();

    assert(~isempty(userPathFolder), ...
        'NANSEN:Addons:EmptyUserpath', ...
        ['MATLAB''s userpath is empty. Configure userpath before ', ...
         'resolving the default NANSEN add-on folder.'])

    addonFolder = fullfile(userPathFolder, 'Nansen', 'Add-Ons');
end
