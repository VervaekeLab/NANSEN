function selectedItem = uiSelectString(listOfItems, selectionMode, itemName)
    
    arguments
        listOfItems
        selectionMode {mustBeMember(selectionMode, {'single', 'multiple'})} = 'single'
        itemName = 'item'
    end

    switch selectionMode
        case 'single'
            titleStr = 'Select item';
        case 'multiple'
            titleStr = 'Select items';
    end
    
    if isempty( regexp( itemName(1), '[aeiouy]', 'once') )
        indefArticle = 'a';
    else
        indefArticle = 'an';
    end

    msg = sprintf('Select %s %s:', indefArticle, itemName);
    
    [selectedIndex, tf] = listdlg('ListString', listOfItems, 'Name', titleStr,...
        'PromptString', msg, 'SelectionMode', selectionMode );
    
    if tf
        selectedItem = listOfItems(selectedIndex);
    else
        selectedItem = {};
    end
end
