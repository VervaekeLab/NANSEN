function tutorialEnum = uiSelectTutorialProject()
% Allow user to select an existing project
    tutorialEnums = enumeration('nansen.app.tutorial.enum.Tutorial');
    tutorialTitles = [tutorialEnums.Title];

    [selection, ok] = listdlg('ListString', tutorialTitles, 'ListSize', [360, 240]);

    if ok
        tutorialEnum = tutorialEnums(selection);
    else
        error('User canceled.')
    end
end
