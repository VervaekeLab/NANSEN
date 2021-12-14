classdef sessionMethodClassTemplate < nansen.session.SessionMethod

    
    properties (Constant) % SessionMethod attributes
        BatchMode = 'serial'
        IsQueueable = true;
        OptionsManager = nansen.OptionsManager('nansen.adapter.NAME')
    end
    
    
    methods
        
        function obj = sessionMethodClassTemplate(varargin)
            
            obj@nansen.session.SessionMethod(varargin{:})

        end
        
        
    end
    
    methods
        
        function runMethod(obj)
            
        end
        
    end

    

end