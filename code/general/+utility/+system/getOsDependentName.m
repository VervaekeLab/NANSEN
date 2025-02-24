function name = getOsDependentName(referenceName)
%getOsDependentName Translate reference name to equivalent for current OS
%
%   This function is used as a dictionary for translating system (OS)
%   dependent names from a mac-centric point of view.

    if ismac
        name = referenceName;
        return
    end
    
    % % Translate to names on windows
    if ispc
        switch referenceName
            
            case 'Finder';  name = 'Explorer';
            case 'finder';  name = 'explorer';
            
            otherwise
                error('Name (%s) is not available', referenceName)
        end
        
    % % Translate to names on linux
    elseif isunix
        switch referenceName
                    
            case 'Finder';  name = 'File Explorer'; %?
            case 'finder';  name = 'file explorer'; %?
                
            otherwise
                error('Name (%s) is not available', referenceName)
        end
    end
end
