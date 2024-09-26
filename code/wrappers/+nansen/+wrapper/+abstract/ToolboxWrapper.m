classdef ToolboxWrapper < handle
        
    % Provide properties for classes that acts as wrapper for toolbox
    % methods..
    
    properties
        
    end
    
    methods (Abstract)
        %getToolboxSpecificOptions(obj)
    end
    
    methods (Static)

        function options = getDefaultOptions(className)
        %getDefaultOptions Get default options for a toolbox method
            
            % Each toolbox should have an Options class with a getDefaults
            % method. Use this to get the toolbox-specific default options.
            classNameSplit = strsplit(className, '.');
            classNameOptions = strjoin([classNameSplit(1:end-1), 'Options'], '.');
            optionsFcn = str2func( strjoin({classNameOptions, 'getDefaults'}, '.' ));
            options = optionsFcn();

            % Merge with default options for super classes
            superOptions = nansen.mixin.HasOptions.getSuperClassOptions(className);
            options = nansen.mixin.HasOptions.combineOptions(options, superOptions{:});
        end
    end
end
