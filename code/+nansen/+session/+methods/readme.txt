sessionMethods will automatically populate the menu in the nansen app.

The sessionMethods are subdivided into subfolders (or packages), which can 
contain again can consist of packages or functions. The package structure 
determines where the functions will be located in the menus and submenus. 

The function should take sessionID (char) or sessionIDs (cell) as a first 
input. It should also implement a function called validateSessionID (see 
help validateSessionID for details). 

In sessionBrowser, when a method is selected from the menu, it will be called
with all sessionIDs that are selected. Some methods might require to be run 
individually on each session whereas other methods will require multiple 
sessions to work properly. When the method is called from the menu it will be
called with a cell array of all selected sessions. If the method however has 
implemented validateSessionID and the mode is set to single an error will be 
thrown. This error is caught and the method will be run on each session in a 
loop instead.

Some methods might have very similar calls, but have different parameter
values. <Todo: Add example>. Instead of making a package with several 
identical function calls, it is possible to define a simple class (shown in
template below), where a set of constant properties define the different 
parameters for the method. Such a class will show up in the menu as its own 
submenu. For the example below, there would be a submenu "test" with to items;
"keywordA" and "keywordB".


% Template:


classdef test
    
    
    properties (Constant)
        keywordA = {'arg1', 'arg2', 'etc'};
        keywordB = {'arg1', 'arg2', 'etc'};
    end

    
    methods 
        function obj = test(sessionIDs, keyword)
            
            sessionIDs = validateSessionID(sessionIDs, 'any');
            numSessions = numel(sessionIDs);

            for i = 1:numSessions

                sid = sessionIDs{i};
                
                % Do something for this session.
                % randomSessionFunc(sid, obj.(keyword){:})

            end
            
            if ~nargout; clear obj; end
            
        end
        
    end
    
end