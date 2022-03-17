classdef AppWithPlugin < uim.handle
%AppWithPlugin Superclass for app that supports plugins.    
    
    properties
        Plugins applify.mixin.AppPlugin
    end
    
    methods
        
        function openPlugin(~)
            % Subclass should override
        end
        
        function delete(obj)
            for i = 1:numel(obj.Plugins)
                delete(obj.Plugins(i))
            end
        end
        
    end
    
    methods
        
        function addPlugin(obj, pluginObj)
        %addPlugin Add plugin to app    
            
            % Check that plugin is not already active on app
            if obj.isPluginActive(pluginObj)
                error('Plugin is already active in this app')
            elseif ~isa(pluginObj, 'applify.mixin.AppPlugin')
                error('Object of type %s is not a valid AppPlugin.')
            else
                obj.Plugins(end+1) = pluginObj;
            end
            
        end 

        function deletePlugin(obj)
            
            isMatch = strcmp( {obj.Plugins.Name}, pluginName);

            h = obj.Plugins(isMatch);
            delete(h)
            obj.Plugins(isMatch) = [];

        end
        
        function tf = isPluginActive(obj, pluginObj)
        %isPluginActive Is plugin with given name active in App?
            tf = any( strcmp( {obj.Plugins.Name}, pluginObj.Name) );
        end
        
        function h = getPluginHandle(obj, pluginName)
        %getPluginHandle Get handle for plguin with given name    
            
            isMatch = strcmp( {obj.Plugins.Name}, pluginName);
            
            h = obj.Plugins(isMatch);
            
        end
        
        function wasCaptured = sendKeyEventToPlugins(obj, ~, evt)
        %sendKeyEventToPlugins Send a key event to plugins
        %
        %   The key event is sent to the plugins in the order they have
        %   been added. If a plugin captures the key event, this method
        %   returns before sending the event to the remaining plugins.
        
            wasCaptured = false;
            
            for i = 1:numel(obj.Plugins)
                try
                    wasCaptured = obj.Plugins(i).keyPressHandler([], evt);
                    if wasCaptured; return; end
                catch ME
                    warning( [ME.message, '\n'] )
                end
            end
        end
        
    end
    
end