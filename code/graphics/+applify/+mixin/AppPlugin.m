classdef AppPlugin < applify.mixin.UserSettings & matlab.mixin.Heterogeneous & uiw.mixin.AssignPVPairs
%AppPlugin Abstract superclass for an app plugin
%   
%   Syntax:
%       hPlugin = AppPlugin(hApp) creates a plugin instance for the given
%       app reference
%
%       hPlugin = AppPlugin(hApp, options) additionally provides options to
%       use. Options can be a struct or an OptionsManager object.
%
%       hPlugin = AppPlugin(hApp, options, flags) specifies flags to set
%       mode of plugin.
%           Flags: 
%               '-p' : create plugin using partial construction, i.e
%                      create, but do not open the control panel
%
%        hPlugin = AppPlugin(hApp, options, property, value, ...) specifies
%        property, value pairs to be set on construction
%       


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
    
    
    % Todo:
    %   [ ] Inherit from nansen.mixin.HasOptions instead of
    %       applify.mixin.UserSettings?
    %       The original idea was that a plugin has some additional
    %       settings that should be combined with the apps own settings
    %       when the plugin is active. However, all the plugins that are
    %       implemented is a method/algorithm with parameters, and these
    %       are managed using the Options/OptionsManager instead...
    
    
    properties (Abstract, Constant)
        Name
    end
    
    properties (Abstract)
        PrimaryAppName              % What is this used for exatly? Maybe remove?
    end
    
    properties (SetAccess = protected)
        PartialConstruction = false % Do a partial construction, i.e skip the opening of options editor on construction
    end
    
    properties
        RunMethodOnFinish = true    % Should we run method when settings/options are "saved"?
        Modal = true                % Is figure modal or not
        DataIoModel                 % Store a data i/o model object if it is provided.
        OptionsManager              % Store optionsmanager handle if plugin is provided with an optionsmanager on construction
    end
    
    properties
        PrimaryApp          % App which is primary "owner" of the plugin. find better propname?
        MenuItem struct     % Struct for storing menu handles 
        Icon
    end
    
    properties (Access = protected)
        IsActivated = false;
    end
    
    methods (Abstract, Static) % Should it be a property or part of settings?
        %getPluginIcon()
    end

    methods % Constructor
        
        function obj = AppPlugin(hApp, options, varargin)
            
            if nargin > 2
                obj.parseVarargin(varargin{1:end})
            end
            
            if ~nargin || isempty(hApp); return; end
            
            obj.validateAppHandle(hApp)
            
            % Check if plugin is already open/active
            if hApp.isPluginActive(obj)
                obj = hApp.getPluginHandle(obj.Name);
            end
            
            % Assign options from input if provided
            if nargin >= 2 && ~isempty(options)
                obj.assignOptions(options)
            else
                obj.assignDefaultOptions()
            end
                        
            if ~hApp.isPluginActive(obj)
                obj.activatePlugin(hApp)
            end
            
            if ~nargout; clear obj; end

        end
        
        function delete(obj)
            if ~isempty(obj.PrimaryApp)
                obj.PrimaryApp.removePlugin(obj.Name)
            end

            % Delete menu items
            if ~isempty(obj.MenuItem)
                structfun(@delete, obj.MenuItem)
            end
            
        end
        
    end
    
    methods (Access = public)
        
        function openControlPanel(obj)
            obj.editSettings()
        end
        
        function run(obj)
            % Subclasses may override
        end
        
    end
    
    % Methods for mouse and keyboard interactive callbacks
    methods (Access = {?applify.mixin.AppPlugin, ?applify.AppWithPlugin} )
        
        function tf = keyPressHandler(obj, src, evt) % Subclass can overide
            % todo: rename to onKeyPressed
            tf = false; % Key press event was not captured by plugin

        end
        
        function tf = keyReleasedHandler(obj, src, evt) % Subclass can overide
            tf = false; % Key released event was not captured by plugin
        end

        %tf = mousePressHandler(src, evt) % Subclass can overide
        
    end
    
    methods % Access?
        
        function activatePlugin(obj, appHandle)
            obj.PrimaryApp = appHandle;
            obj.PrimaryApp.addPlugin(obj)
            
            obj.onPluginActivated()
            obj.IsActivated = true;
        end
        
        function sEditor = openSettingsEditor(obj)
        %openSettingsEditor Open ui dialog for editing plugin options.
            
            titleStr = sprintf('%s Parameters', obj.Name);

            if ~isempty(obj.OptionsManager)
                sEditor = obj.OptionsManager.openOptionsEditor();
                sEditor.Callback = @obj.onSettingsChanged;
            else
                sEditor = structeditor(obj.settings, 'Title', titleStr, ...
                    'Callback', @obj.onSettingsChanged );
            end
            
            obj.relocatePrimaryApp(sEditor) % To prevent figures covering each other
            obj.hSettingsEditor = sEditor;
            
            addlistener(obj, 'ObjectBeingDestroyed', @(s,e)delete(sEditor));
        
        end
        
        function editSettings(obj)
        %editSettings Open and wait for user to edit settings.
        
            sEditor = obj.openSettingsEditor();

            if obj.Modal
                sEditor.waitfor()
                obj.onSettingsEditorResumed()

            else
                % Todo: implement above in callback.
                addlistener(sEditor, 'AppDestroyed', ...
                        @(s, e) obj.onSettingsEditorResumed);
            end

        end
        
        function place(obj, varargin)
            obj.hSettingsEditor.place(varargin{:})
        end
    end
    
    methods (Access = protected)
        
        function onPluginActivated(obj)
        %onPluginActivated Run subroutines when plugin is activated.
            obj.createSubMenu()
        end
        
        function parseVarargin(obj, varargin)
        %parseVarargin Parser for varargin that are passed on construction    
            
            % Look for flag of whether to open plugin's options panel on
            % construction
            if ischar(varargin{1}) && isequal(varargin{1}, '-p')
                obj.PartialConstruction = true;
                varargin(1) = [];
            end
            
            obj.assignPVPairs(varargin{:})
        end
        
        function assignOptions(obj, options)
        %assignOptions Assign non default options for plugin
        %
        %   obj.assignOptions(options) assigns non-default settings to
        %   this object. options can be a struct or an OptionsManager
        %   object
        
            if isa(options, 'struct')
                obj.settings = options;
            elseif isa(options, 'nansen.manage.OptionsManager')
                obj.OptionsManager = options;
                obj.settings = obj.OptionsManager.Options;
            end
            
        end
        
        function assignDefaultOptions(obj)
        %assignDefaultOptions Assign default options
            % Subclasses may override.
        end
        
        function createSubMenu(obj)
            % Subclasses may override
        end
        
        function onSettingsEditorResumed(obj)
        %onSettingsEditorResumed Callback for when settings editor is resumed              
            
            % Todo: What if obj is invalid
        
            % Abort if sEditor is invalid (improper exit)
            if ~isvalid(obj.hSettingsEditor); return; end

            if ~obj.hSettingsEditor.wasCanceled
                obj.settings_ = obj.hSettingsEditor.dataEdit;
            end

            obj.wasAborted = obj.hSettingsEditor.wasCanceled;
            delete(obj.hSettingsEditor)

            obj.onSettingsEditorClosed()

            if ~obj.wasAborted && obj.RunMethodOnFinish
                obj.run();
            else
                delete(obj)
            end
        
        end
        
        function onSettingsEditorClosed(obj)
            % Subclasses may override
        end
        
        function relocatePrimaryApp(obj, hPlugin, direction)
        %relocatePrimaryApp Relocate windows to prevent coverup.
            
            % TODO: What if plugin figure is in same window.. i.e roimanager
            % TODO: Improve so that windows are not moved off-screen
            
            if nargin < 3
                direction = 'horizontal';
            end
           
            figPos(1,:) = getpixelposition(hPlugin.Figure);
            figPos(2,:) = getpixelposition(obj.PrimaryApp.Figure);
            hFig = [hPlugin.Figure, obj.PrimaryApp.Figure];

            switch direction
                case 'horizontal'
                    figPos_ = figPos(:, [1,3]); dim = 1;
                case 'vertical'
                    figPos_ = figPos(:, [2,4]); dim = 2;
            end
            
            screenPos = uim.utility.getCurrentScreenSize( obj.PrimaryApp.Figure );
            
            [~, idx] = sort(figPos_(:, 1));
            figPos = figPos(idx, :);
            hFig = hFig(idx);
            
            [x, ~] = uim.utility.layout.subdividePosition(min(figPos(:,1)), ...
                screenPos(dim+2), figPos_(:,2), 20);
            
            for i = 1:2
                hFig(i).Position(dim) = x(i);
            end
            
        end
        
    end
    
    methods (Access = private)
                    
        function validateAppHandle(obj, hApp)
        %validateAppHandle Check validity of app handle
        
            if ~isa(hApp, 'applify.AppWithPlugin')
                error('Can not add plugin "%s" to app of type %s', ...
                    obj.Name, class(hApp))
            end
        end
        
    end
end