function createABO_VisualCoding_CalciumImaging_Project()
% Create a NANSEN project for the Visual Coding Ophys dataset from the
% Allen Brain Observatory

    assert( exist('+bot/listSessions', 'file') == 2, ...
        'This action requires the Brain-Observatory-Toolbox to be installed' )
    
    % Define project name and project description:
    projectName = 'abo_ophys';
    projectDescription = "Allen Brain Observatory - Visual Coding - Two Photon Calcium Imaging";
    projectDirectory = fullfile( userpath, 'Nansen', 'New Projects', 'ABO-VisualCoding-TwoPhoton-Test');
    
    % Create a project
    project = nansen.createProject(projectName, projectDescription, projectDirectory);

    % Create a session metatable and add to project
    sessionTable = bot.listSessions("VisualCoding", "Ophys");
    metaTable = nansen.metadata.MetaTable(sessionTable, ...
        'MetaTableIdVarname', 'id', ...
        'MetaTableClass', 'Session', ...
        'ItemClassName', 'bot.item.concrete.OphysSession' );
    project.addMetaTable(metaTable)

    % Create a subject metatable and add to project
    subjectTable = sessionTable(:, {'mouse_id', 'age_in_days', 'sex', 'full_genotype', 'cre_line'});
    mouseIds = [subjectTable.mouse_id];
    [~, iA, ~] = unique(mouseIds);
    subjectTable = subjectTable(iA, :);
    metaTable = nansen.metadata.MetaTable(subjectTable, ...
        'MetaTableIdVarname', 'mouse_id', ...
        'MetaTableClass', 'Subject', ...
        'ItemClassName', '' );
    project.addMetaTable(metaTable)
end
