function createTableVariable(app, metadataClass)
%addTableVariable Opens a dialog where user can add table variable
%
%   User gets the choice to create a variable that can be edited
%   from the table or which is retrieved from a function.

%  Q: This belongs to MetaTableViewer, but was more convenient to
%  add it here for now. 

% Todo: Use class instead of functions / add class as a third
% choice. Can make more configurations using a class, i.e class can
% provides a mouse over effect etc.

    % Create a struct to open in a dialog window
    
    if nargin < 2
        error('Missing input')
    end
    
    import nansen.metadata.utility.createFunctionForCustomTableVar
    import nansen.metadata.utility.createClassForCustomTableVar
    
    inputModeSelection = {...
        'Enter values manually', ...
        'Get values from function', ...
        'Get values from list' };
    
    % Create a struct for opening in the structeditor dialog
    S = struct();
    S.VariableName = '';
    S.DataType = 'numeric';
    S.DataType_ = {'numeric', 'text', 'logical'};
    S.InputMode = inputModeSelection{1};
    S.InputMode_ = inputModeSelection;
    
    S = tools.editStruct(S, '', 'New Variable', ...
        'ReferencePosition', app.Figure.Position);
    
    if isempty(S.VariableName); return; end
             
    % Make sure variable does not already exist
    currentVars = app.MetaTable.entries.Properties.VariableNames;
    if any(strcmp( S.VariableName, currentVars ))
        
        message = sprintf(['The variable "%s" already exists in this table. ', ...
            'Do you want to modify this variable? ', ...
            'Note: The old variable definition will be lost.'], S.VariableName);
        title = 'Confirm Variable Modification';
        %answer = questdlg(message, title);
        answer = app.openQuestionDialog(message, title);

        switch answer
            case 'Yes'
                % Proceed
            case {'No', 'Cancel'}
                return
        end
% %                 error('Variable with name %s already exists in this table', ...
% %                     S.VariableName )
    end

    % Add the metadata class to s. An idea is to also select this
    % on creation.
    S.MetadataClass = metadataClass;

    % Make sure the variable name is valid
    msg = sprintf('%s is not a valid variable name', S.VariableName);
    if ~isvarname(S.VariableName); app.openErrorDialog(msg); return; end
    
    switch S.InputMode
        case 'Enter values manually'
            createClassForCustomTableVar(S)
        case 'Get values from function'
            createFunctionForCustomTableVar(S)
        case 'Get values from list'
            dlgTitle = sprintf('Create list of choices for %s', S.VariableName);
            selectionList = uics.multiLineListbox({}, 'Title', dlgTitle, ...
                'ReferencePosition', app.Figure.Position);
            S.SelectionList = selectionList;
            createClassForCustomTableVar(S)
    end
    
    % Todo: Add variable to table and table settings....
    initValue = nansen.metadata.utility.getDefaultValue(S.DataType);
    
    app.MetaTable.addTableVariable(S.VariableName, initValue)
    app.UiMetaTableViewer.refreshColumnModel();
    app.UiMetaTableViewer.refreshTable(app.MetaTable)
    
    % Refresh menus that show the variables of the session table...
    app.updateSessionInfoDependentMenus()
end
