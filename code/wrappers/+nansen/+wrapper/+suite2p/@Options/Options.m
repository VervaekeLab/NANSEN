classdef Options < nansen.wrapper.abstract.OptionsAdapter
    
    properties (Constant)
        ToolboxName = 'Suite2p'
        Name = 'Suite2p Options'
        Description = 'Options for suite2p'
    end
    
    
    methods (Static) % Functions defined in files.
        
        S = getDefaults()
        M = getAdapter()
        
    end
    
    methods (Static)
        
        function S = getOptions()
            S = nansen.wrapper.suite2p.Options.getDefaults();
        end
        
        function S = convert(S)
            
            if nargin < 1
                S = nansen.wrapper.suite2p.Options.getOptions();
            end
            
            nameMap = nansen.wrapper.suite2p.Options.getAdapter;
            S = nansen.wrapper.abstract.OptionsAdapter.rename(S, nameMap);
        end
    end
end