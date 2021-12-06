function hMenu = createSessionTableContextMenu(app, hMenu)
%createSessionTableContextMenu Create a context menu for sessions in table

    import nansen.metadata.utility.getPublicSessionInfoVariables

    hContextMenu = uicontextmenu(app.Figure);
    hContextMenu.ContextMenuOpeningFcn = @(s,e,m) disp('test');%onContextMenuOpening;
    hContextMenu.ContextMenuOpeningFcn = @(src,event)disp('Context menu opened');
    
    if ~isempty(app.UiMetaTableViewer.HTable.ContextMenu)
        delete(app.UiMetaTableViewer.HTable.ContextMenu)
    end
    
    %app.UiMetaTableViewer.HTable.ContextMenu = hContextMenu;
    app.UiMetaTableViewer.TableContextMenu = hContextMenu;
    hMenuItem = gobjects(0);
    c = 1;
    
    % Create a context menu
    hMenuItem(c) = uimenu(hContextMenu, 'Text', 'Open Session Folder');
    
    % Get available datalocations from a session object
    if ~isempty(app.MetaTable.entries)
        dataLocations = fieldnames(app.MetaTable.entries{1, 'DataLocation'});
    end
    

    for i = 1:numel(dataLocations)
        mTmpI = uimenu(hMenuItem(c), 'Text', dataLocations{i});
        mTmpI.Callback = @(s, e, datatype) app.openFolder(dataLocations{i});
    end
    
    % % Todo... Create method for adding session to other databases....
    %m0 = uimenu(hContextMenu, 'Text', 'Add to Database', 'Tag', 'Add to Database', 'Separator', 'on');
    %app.updateRelatedInventoryLists(m0)

    c = c + 1;
    hMenuItem(c) = uimenu(hContextMenu, 'Text', 'Update Column Variable');
    columnVariables = getPublicSessionInfoVariables(app.MetaTable);
    
    for iVar = 1:numel(columnVariables)
        hSubmenuItem = uimenu(hMenuItem(c), 'Text', columnVariables{iVar});
        hSubmenuItem.Callback = @app.updateTableVariable;
    end
    
    
    %m3 = uimenu(hContextMenu, 'Text', 'Update Session', 'Callback', @app.updateSessionObjects, 'Enable', 'on');
    %m4 = uimenu(hContextMenu, 'Text', 'Edit Session Notes', 'Callback', @app.editSessionNotes, 'Enable', 'on');
    %m1 = uimenu(hContextMenu, 'Text', 'Remove Session', 'Callback', @app.buttonCallback_RemoveSession, 'Separator', 'on');
    
end