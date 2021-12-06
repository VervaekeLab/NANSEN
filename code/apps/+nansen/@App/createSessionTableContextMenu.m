function hMenu = createSessionTableContextMenu(app, hMenu)
%createSessionTableContextMenu Create a context menu for sessions in table


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

    
    % Todo: Get from data location definitions...
    dataLocation = {'Datadrive', 'Dropbox'};
    dataFolder = {'PROCESSED', 'microscope_data', 'rig_data'};
    dataFolderLabel = {'Processed', 'Microscope Data', 'Rig Data'};

    for i = 1:2
        mTmpI = uimenu(hMenuItem(c), 'Text', dataLocation{i});
        for j = 1:3
            mTmpJ = uimenu(mTmpI, 'Text', dataFolderLabel{j}, ....
                'Callback', @(s, e, rootdir, datatype) app.openFolder(lower(dataLocation{i}), dataFolder{j}) );
        end
    end
    
    
    
    % % Todo... Create method for adding session to other databases....
    %m0 = uimenu(hContextMenu, 'Text', 'Add to Database', 'Tag', 'Add to Database', 'Separator', 'on');
    %app.updateRelatedInventoryLists(m0)

    
    c = c + 1;
    hMenuItem(c) = uimenu(hContextMenu, 'Text', 'Update Column Variable');
    columnVariables = app.MetaTable.entries.Properties.VariableNames;
    for iVar = 1:numel(columnVariables)
        hSubmenuItem = uimenu(hMenuItem(c), 'Text', columnVariables{iVar});
        hSubmenuItem.Callback = @app.updateTableVariable;
    end
    
    
    %m3 = uimenu(hContextMenu, 'Text', 'Update Session', 'Callback', @app.updateSessionObjects, 'Enable', 'on');
    %m4 = uimenu(hContextMenu, 'Text', 'Edit Session Notes', 'Callback', @app.editSessionNotes, 'Enable', 'on');
    %m1 = uimenu(hContextMenu, 'Text', 'Remove Session', 'Callback', @app.buttonCallback_RemoveSession, 'Separator', 'on');
    
end