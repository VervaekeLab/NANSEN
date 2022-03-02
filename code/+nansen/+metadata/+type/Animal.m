classdef Animal < nansen.metadata.abstract.BaseSchema
    
    % todo: rename to subject?
    
    % Set metaObject abstract properties
    properties (Constant, Hidden)
        ANCESTOR = ''
        IDNAME = 'animalID'
    end
    
    properties
        ancestorID      % Add some validation scheme.... Can I dynamically set this according to <missing thought here>
        animalID         char
        dateOfBirth     char
        sex             char
        strain          char % /or enum
    end
    
    
    methods

        function str = tooltipString(obj)
            % hm...
        end
        
    end
    
end