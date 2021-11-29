classdef AppPlugin < applify.mixin.UserSettings & matlab.mixin.Heterogeneous
    
    % Not quite sure yet what to add here.
    %
    % Provide properties and methods for other classes to act as plugins to
    % apps. 
    %   
    %       On construction of the plugin, it is added to the apps plugin
    %       list. If a plugin of the same type is already in the list, the
    %       handle of that is returned instead of creating a new one...
    %
    %       Plugins can implement mouse/keyboard callbacks that are called
    %       whenever the apps corresponding callback is invoked
    %
    %       The plugin gets access to some of the parent class properties
    %       and methods.
    %
    %       The plugin can add items to the apps menu.
    %
    %       App takes plugin's settings into account.
    
    
    
    properties (Abstract, Constant)
        Name
    end
    
    properties (Abstract)
        PrimaryAppName % is this needed???
    end
    
    properties
        Icon
    end
    
    properties
        PrimaryApp  % App which is primary "owner" of the plugin. find better propname?
        Menu
    end
    
    properties (Access = protected)
        IsActivated = false;
    end
    
    
    methods (Abstract, Access = protected)
        onPluginActivated % Todo: find better name..
    end
    
    methods (Abstract, Static) % Should it be a property or part of settings?
        %getPluginIcon()
    end
    
    
    
    % Methods for mouse and keyboard interactive callbacks
    methods (Access = {?applify.mixin.AppPlugin, ?applify.AppWithPlugin} )
        
        function tf = onKeyPress(src, evt) % Subclass can overide
            % todo: rename to onKeyPressed
            tf = false; % Key press event was not captured by plugin

        end
        
        function tf = onKeyRelease(src, evt) % Subclass can overide
            tf = false; % Key released event was not captured by plugin
        end

        %tf = onMousePressed(src, evt) % Subclass can overide
        
    end
    
    methods
        
        function obj = AppPlugin(hApp)

            if ~nargin || isempty(hApp); return; end
            
            if ~isa(hApp, 'applify.AppWithPlugin')
                error('Can not add plugin "%s" to app of type %s', ...
                    obj.Name, class(hApp))
            else
                % Check if plugin is already open/active
                if hApp.isPluginActive(obj)
                    obj = hApp.getPluginHandle(obj.Name);
                end
                
            end
            
            if ~nargout; clear obj; end

        end
    end
    
    
    methods
        
        function activatePlugin(obj, appHandle)
            obj.PrimaryApp = appHandle;
            obj.PrimaryApp.addPlugin(obj)
            
            obj.onPluginActivated()
            obj.IsActivated = true;
        end
        
    end
    
end