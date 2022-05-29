classdef Options < nansen.wrapper.abstract.OptionsAdapter
    
    properties (Constant)
        ToolboxName = 'GRaFT'
        %Name = 'GRaFT Options'
        %Description = 'Options for GRaFT'
    end
    
    
    methods (Static) % Functions defined in files.
        
        [P, V] = getDefaults()
        M = getAdapter()
        
    end
    
    methods (Static)
        
        function S = getOptions()
            S = nansen.wrapper.graft.Options.getDefaults();
        end
        
        function SOut = convert(S)
            
            SOut = S; return
            % not renaming of params implemented yet
        end
        
    end
    
    
    
    
end