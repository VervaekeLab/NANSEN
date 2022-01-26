classdef AppWithPlugin < uim.handle
    
    
    properties
        Plugins applify.mixin.AppPlugin
    end
    
    methods
        function openPlugin(~)
            % Subclass whould override
        end
    end
    
    methods
        
        function tf = isPluginActive(obj, pluginName)
        %isPluginActive Is plugin with given name active in App?
            tf = any( strcmp( {obj.Plugins.Name}, pluginName) );
        end
        
        function addPlugin(obj, h)
        %addPlugin Add plugin to app    
            
            % Check that plugin is not already active on app
            if obj.isPluginActive(h.Name)
                error('Plugin is already active in this app')
            elseif ~isa(h, 'applify.mixin.AppPlugin')
                error('Object of type %s is not a valid AppPlugin.')
            else
                obj.Plugins(end+1) = h;
            end
            
        end
        
        function h = getPluginHandle(obj, pluginName)
        %getPluginHandle Get handle for plguin with given name    
            
            isMatch = strcmp( {obj.Plugins.Name}, pluginName);
            
            h = obj.Plugins(isMatch);
            
        end
        
        function deletePlugin(obj)
            
            isMatch = strcmp( {obj.Plugins.Name}, pluginName);

            h = obj.Plugins(isMatch);
            delete(h)
            obj.Plugins(isMatch) = [];

        end

    end
    
    
end