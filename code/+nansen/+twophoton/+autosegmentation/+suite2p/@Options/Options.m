classdef Options < nansen.adapter.OptionsAdapter
    
    properties (Constant)
        ToolboxName = 'Suite2p'
        Name = 'Suite2p Options'
        Description = 'Options for suite2p'
    end
    
    
    methods (Static) % Functions defined in files.
        
        S = getDefaultOptions()
        M = getOptionsConversionMap()
        
    end
    
    methods (Static)
        
        function S = getOptions()
            S = nansen.twophoton.autosegmentation.suite2p.Options.getDefaultOptions();
        end
        
        function S = convert(S)
            
            if nargin < 1
                S = nansen.twophoton.autosegmentation.suite2p.Options.getOptions();
            end
            
            nameMap = nansen.twophoton.autosegmentation.suite2p.Options.getOptionsConversionMap;
            S = nansen.adapter.OptionsAdapter.rename(S, nameMap);
            
        end
        
    end
    
    
    
    
end