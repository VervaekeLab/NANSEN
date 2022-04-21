function createSessionTableContextMenu(app)
%createSessionTableContextMenu Create a context menu for sessions in table

    import nansen.metadata.utility.getPublicSessionInfoVariables
    import nansen.metadata.utility.getMetaTableVariableAttributes
    
    hContextMenu = uicontextmenu(app.Figure);
    %hContextMenu.ContextMenuOpeningFcn = @(s,e,m) disp('test');%onContextMenuOpening;
    %hContextMenu.ContextMenuOpeningFcn = @(src,event)disp('Context menu opened');
    
    
% % %     if ~isempty(app.UiMetaTableViewer.HTable.ContextMenu)
% % %         delete(app.UiMetaTableViewer.HTable.ContextMenu)
% % %     end
% % %     app.UiMetaTableViewer.HTable.ContextMenu = hContextMenu;

    if ~isempty(app.UiMetaTableViewer.TableContextMenu)
        delete(app.UiMetaTableViewer.TableContextMenu)
    end
    app.UiMetaTableViewer.TableContextMenu = hContextMenu;
    
    hMenuItem = gobjects(0);
    c = 1;
    
    % Create a context menu
    hMenuItem(c) = uimenu(hContextMenu, 'Text', 'Open Session Folder');
    
    % Get available datalocations from a session object
    if contains('DataLocation', app.MetaTable.entries.Properties.VariableNames )
        if ~isempty(app.MetaTable.entries)
            dataLocationItem = app.MetaTable.entries{1, 'DataLocation'};
            dataLocationItem = app.DataLocationModel.expandDataLocationInfo(dataLocationItem);
            dataLocationNames = {dataLocationItem.Name};
        end
    

        for i = 1:numel(dataLocationNames)
            mTmpI = uimenu(hMenuItem(c), 'Text', dataLocationNames{i});
            mTmpI.Callback = @(s, e, datatype) app.openFolder(dataLocationNames{i});
        end
    end
    
    % % Todo... Create method for adding session to other databases....
    %m0 = uimenu(hContextMenu, 'Text', 'Add to Database', 'Tag', 'Add to Database', 'Separator', 'on');
    %app.updateRelatedInventoryLists(m0)

    
    c = c + 1;
    hMenuItem(c) = uimenu(hContextMenu, 'Text', 'Create New Note', 'Separator', 'on');
    hMenuItem(c).Callback = @(s, e) app.onCreateNoteSessionContextMenuClicked();
    
    c = c + 1;
    hMenuItem(c) = uimenu(hContextMenu, 'Text', 'View Session Notes');
    hMenuItem(c).Callback = @(s, e) app.onViewSessionNotesContextMenuClicked();
   
    c = c + 1;
    hMenuItem(c) = uimenu(hContextMenu, 'Text', 'Get Task List', 'Separator', 'on');
    hSubmenuItem = uimenu(hMenuItem(c), 'Text', 'Manual');
    hSubmenuItem.Callback = @(s, e) app.createBatchList('Manual');
    hSubmenuItem = uimenu(hMenuItem(c), 'Text', 'Queuable');
    hSubmenuItem.Callback = @(s, e) app.createBatchList('Queuable');

    c = c + 1;
    hMenuItem(c) = uimenu(hContextMenu, 'Text', 'Assign Pipeline');
    app.updatePipelineItemsInMenu(hMenuItem(c))
    
    c = c + 1;
    hMenuItem(c) = uimenu(hContextMenu, 'Text', 'Update Column Variable');
    %columnVariables = getPublicSessionInfoVariables(app.MetaTable);
    
    S = getMetaTableVariableAttributes('session');
    columnVariables = {S([S.HasFunction]).Name};
    
    for iVar = 1:numel(columnVariables)
        hSubmenuItem = uimenu(hMenuItem(c), 'Text', columnVariables{iVar});
        hSubmenuItem.Callback = @app.updateTableVariable;
    end

    c = c + 1;
    hMenuItem(c) = uimenu(hContextMenu, 'Text', 'Copy SessionID(s)', 'Separator', 'on');
    hMenuItem(c).Callback = @(s, e) app.copySessionIdToClipboard;

    
    %m3 = uimenu(hContextMenu, 'Text', 'Update Session', 'Callback', @app.updateSessionObjects, 'Enable', 'on');
    %m4 = uimenu(hContextMenu, 'Text', 'Edit Session Notes', 'Callback', @app.editSessionNotes, 'Enable', 'on');
    %m1 = uimenu(hContextMenu, 'Text', 'Remove Session', 'Callback', @app.buttonCallback_RemoveSession, 'Separator', 'on');
    
    %app.UiMetaTableViewer.TableContextMenu = 
    
end