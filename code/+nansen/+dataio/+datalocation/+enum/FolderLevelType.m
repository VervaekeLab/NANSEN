classdef FolderLevelType
    
    enumeration
        Undefined('Undefined')
        Subject('Subject')
        Session('Session')
        Trial('Trial')
        Date('Date')
        Epoch('Epoch')
    end

    properties
        Name
        DefaultFolderPrefix
    end

    methods
        function obj = FolderLevelType(name)
            obj.Name = name;
            switch obj.Name
                case 'Subject'
                    obj.DefaultFolderPrefix = 'subject';
                case 'Session'
                    obj.DefaultFolderPrefix = 'session';
            end
        end
    end
end