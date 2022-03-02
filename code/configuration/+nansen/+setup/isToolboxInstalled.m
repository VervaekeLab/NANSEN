function tf = isToolboxInstalled(requiredToolboxes)

    % Get names of all installed toolboxes
    v_ = ver;
    installedToolboxes = {v_.Name}';
    
    % Check if required toolboxes are installed
    tf = ismember(requiredToolboxes, installedToolboxes);
        
end