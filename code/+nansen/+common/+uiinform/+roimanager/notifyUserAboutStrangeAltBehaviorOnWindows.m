function notifyUserAboutStrangeAltBehaviorOnWindows(mode)
    
    if nargin < 1; mode = "default"; end
      
    group = 'Nansen_Roimanager_Info';
    pref =  'StrangeAltBehavior';
    
    if mode == "reset";  setpref(group, pref, 'ask'); end
    
    title = 'Info';
    msg = {...
        'Due to an undiscovered bug on Windows, pressing the left ''alt'' key will ', ...
        'freeze the pointer tool. The solution is to press the ''alt'' key one more', ...
        'time to unfreeze the pointer tool or to use the right ''alt'' button instead.'};
    pbtns = {'Ok'};

    [pval, tf] = uigetpref(group, pref, title, msg, pbtns);
end
    
