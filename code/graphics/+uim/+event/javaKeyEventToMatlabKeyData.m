function mEvt = javaKeyEventToMatlabKeyData(jEvt)
%javaKeyEventToMatlabKeyData Cast java keyevent to matlab event keydata
%
%   Properties of matlab event Keydata:
%    - Character  : Case sensitive
%    - Modifier   : 
%    - Key        : Lower version of a letter
    
    % Todo: What about keys that are not letters
    %       What about windows?
    
    
    %% Get the character
    mEvt.Character = get(jEvt, 'KeyChar');
    
    % Remove special characters...
    if double(mEvt.Character) == (2^16 - 1)
        mEvt.Character = '';
    end
    
    
    %% Get the modifier(s)
    mEvt.Modifier = getModifiers(jEvt);

    
    %% Get the key name
    mEvt.Key = lower( get(jEvt, 'KeyChar') );
    
    % Add key name for non-character keys.
    if double(mEvt.Key) == (2^16 - 1)
        mEvt.Key = getSpecialKey(jEvt);
    end
    
    
    %% For debugging
    if false
        get(jEvt)
    end
    
end


function cellOfModifiers = getModifiers(jEvt)

    cellOfModifiers = cell(0,1);
    
    if get(jEvt, 'ShiftDown') == 1
        cellOfModifiers{end+1} = 'shift'; 
    end
    
    if get(jEvt, 'ControlDown') == 1
        cellOfModifiers{end+1} = 'control'; 
    end
        
    if get(jEvt, 'AltDown') == 1
        cellOfModifiers{end+1} = 'alt'; 
    end
    
    if get(jEvt, 'MetaDown') == 1
        cellOfModifiers{end+1} = 'command';
    end
    
end

function keyName = getSpecialKey(jEvt)

    % Todo: Add mode cases...
    
    keyCode = get(jEvt, 'KeyCode');

    switch keyCode
        case 16
            keyName = 'shift';
        case 17
            keyName = 'control';
        case 18
            keyName = 'alt';
        case 157
            keyName = 'command';
            
        otherwise
            keyName = '';
    end
    
end