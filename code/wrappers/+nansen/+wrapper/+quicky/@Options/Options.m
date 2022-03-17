classdef Options < nansen.wrapper.abstract.OptionsAdapter
    
    properties (Constant)
        ToolboxName = 'Quicky'
    end
    
    
    methods (Static) % Functions defined in files.
        
        [P, V] = getDefaults()
        M = getAdapter()
        
    end
    
    methods (Static)
        
        function S = getOptions()
            S = nansen.wrapper.quicky.Options.getDefaults();
            
            className = 'nansen.wrapper.quicky.Processor';
            superOptions = nansen.mixin.HasOptions.getSuperClassOptions(className);
            S = nansen.mixin.HasOptions.combineOptions(S, superOptions{:});
            
        end
        
        function SOut = convert(S)
            
            % Most config fields are just placed in substructs, but some
            % fields where renamed before placing in a substruct called
            % CellFind. 
            
            if nargin < 1
                S = nansen.wrapper.quicky.Options.getDefaults();
            end
            
            SOut = S;

        end
        
    end
    
    
    
    
end