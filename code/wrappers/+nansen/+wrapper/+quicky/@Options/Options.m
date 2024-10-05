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
            
            import nansen.wrapper.abstract.OptionsAdapter
            
            if nargin < 1
                S = nansen.wrapper.quicky.Options.getDefaults();
            end
            
            S = OptionsAdapter.ungroupOptions(S);
            
            % Remove fields with ui specifications
            S = OptionsAdapter.removeUiSpecifications(S);
            
            SOut = S;

        end
    end
end
