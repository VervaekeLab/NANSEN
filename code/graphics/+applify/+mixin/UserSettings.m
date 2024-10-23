classdef (Abstract) UserSettings < uim.handle
%applify.mixin.UserSettings Class for adding settings to an app/subclass
%
%   Provides a subclass with a settings property that are saved to and
%   loaded from a file when the class is constructed/deleted.
%
%   Any class that inherits this class must implement the following:
%     * Properties:     USE_DEFAULT_SETTINGS, DEFAULT_SETTINGS (Constant, Hidden)
%     * Methods:        onSettingsChanged(obj, name, value) (protected)
%
%   This class gives access to the following methods:
%     loadSettings, saveSettings and editSettings.
%
%   The saveSettings and loadSettings will save/load class settings from a
%   file. These can be user-specific settings/preferences that should not
%   be subject to the class definition. The file is saved next to the class
%   definition file, but the suffix '_settings.mat' is added. If the class
%   is tracked using git, make sure to add *settings.mat to a .gitignore
%   file.
%
%   editSettings will open a gui for editing settings. When the gui is
%   open, it will call onSettingsChanged whenever a value is edited.
%
%   onSettingsChanged should be implemented to take care of updates done on
%   the settings. onSettingsChanged requires two inputs, name and value,
%   which are the name and the corresponding value of a field in the
%   struct.
%
%   Example from imviewer:
%
%        function onSettingsChanged(obj, name, value)
%             switch name
%                 case 'cLim'
%                     obj.changeBrightness(value)
%                 otherwise
%                     obj.settings.(name) = value;
%             end
%        end
%
%   Subclasses can implement a static getSettings method like this:
%       function S = getSettings()
%           S = getSettings@applify.mixin.UserSettings('subclass_name');
%       end
%   Then settings can be loaded without creating a class object first.
%
%   Written by Eivind Hennestad | Vervaeke Lab

%   ABSTRACT PROPERTIES:
%       USE_DEFAULT_SETTINGS (Constant) : Boolean flag for ignoring settings that are saved to file
%       DEFAULT_SETTINGS (Constant)     : Struct with default settings
%
%   ABSTRACT METHODS:
%       onSettingsChanged (Protected)   : Triggered when settings are changed.
%

    % TODO:
    %   [x] Generalize so that there can be multiple settings structs...
    %   [x] Use a recursive function to check loaded settings against
    %       default settings definition
    %   [ ] Make default settings dependent, and have a static method for
    %       getting the default settings path. That way, its easier to
    %       reset settings to default. When the default settings are in a
    %       constant property, the class need to be cleared in order for
    %       them to be updated.
    %
    % QUESTIONS:
    %   - Can I get name of subclass when superclass abstract method is
    %     called? Would be nice for the getSettings method.
    %
    %   - How to implement multiple subsettings? Cell Array? Struct with
    %     multiple fields?
    
    % Note to self:
    % Programmatic update of settings:
    % I.e obj.settings.name = value % Callback version
    %       update settings and trigger the onSettingsChanged
    % or  obj.settings_.name = value % No callback
    %       update settings and do not trigger onSettingsChanged
    
    properties(Abstract, Constant, Hidden = true)
        USE_DEFAULT_SETTINGS        % Ignore settings file                      Can be used for debugging/dev or if settings should be consistent.
        DEFAULT_SETTINGS            % Struct with default settings
    end
    
    properties (Dependent)
        settings            % A struct containing different settings variables
    end
    
    properties (Hidden)
        wasAborted = false; % Flag to indicate if settings editor ui was aborted..
    end

    properties (Access = protected, Hidden = true)
        settings_ struct    % For internal use to assign settings without triggering callbacks
        hSettingsEditor     % For internal use, handle to gui for editing settings
    end
    
    properties (Dependent, Access = protected, Hidden = true)
        settingsFilePath    % Absolute filepath for file where settings are saved
    end
   
    methods (Abstract, Access = protected)
        onSettingsChanged(obj, name, value) % Callback for change of fields in settings
    end

    properties (Access = private)
        settingsNames cell   % List of all field names in settings, across all levels of substructs (excludes uicontrol configurations)
        settingsSubs cell
    end
    
    methods % Constructor
        
        function obj = UserSettings()
        %UserSettings Construct the object
            obj.loadSettings() % Load settings into class instance.
            obj.assignSettingNames() % Todo: move to the load method??
        end
        
        function delete(obj)
            if ~isempty(obj.hSettingsEditor) && isvalid(obj.hSettingsEditor)
                delete(obj.hSettingsEditor)
            end
        end
    end
    
    methods % Public methods
 
        function loadSettings(obj) % Todo: make protected?
        %loadSettings Load settings from file and assign to obj.settings.
           
            if obj.USE_DEFAULT_SETTINGS
                obj.settings = obj.DEFAULT_SETTINGS;
                return
            end
            
            if isempty(obj.DEFAULT_SETTINGS)
                return
            end
            
            % Load settings from file
            loadPath = obj.settingsFilePath;
            
            if isfile(loadPath) % Load settings from file
                
                S = load(loadPath, 'settings');

                % Check if S consists of substructs
                isAllSubstruct = all( structfun(@(s) isstruct(s), obj.DEFAULT_SETTINGS) );
                
                if isAllSubstruct
                    subfields = fieldnames(obj.DEFAULT_SETTINGS);
                    
                    newSettings = struct();
                    
                    for i = 1:numel(subfields)
                        thisField = subfields{i};
                        
                        if isfield(S.settings, thisField)
                            newSettings.(thisField) = obj.updateSettings(...
                                obj.DEFAULT_SETTINGS.(thisField), S.settings.(thisField));
                        else
                            newSettings.(thisField) = obj.DEFAULT_SETTINGS.(thisField);
                        end
                    end
                    
                    obj.settings = newSettings;

                else
                    obj.settings = obj.updateSettings(obj.DEFAULT_SETTINGS, S.settings);
                end

            else % Initialize settings file using default settings
                obj.settings = obj.DEFAULT_SETTINGS;
                saveSettings(obj)
            end
        end
        
        function saveSettings(obj) % Todo: make protected?
        %saveSettings Save obj.settings to file.
        
        % Don't overwrite saved settings if using default settings.
            if obj.USE_DEFAULT_SETTINGS
                return
            end
            
            S.settings = obj.settings;
            save(obj.settingsFilePath, '-struct', 'S');
                        
        end
        
        function editSettings(obj)
        %editSettings Open gui for editing fields of settings.
        
            titleStr = sprintf('Preferences for %s', class(obj));
            doDefault = true; % backward compatibility...
            
            if ~isempty(obj.hSettingsEditor)
                figure(obj.hSettingsEditor.Figure)
                return
            end
            
            % Todo: If obj has plugins, grab all settings from plugin
            % classes as well.
            if isprop(obj, 'plugins')

                hObjects = [{obj}, {obj.plugins.pluginHandle}];
                hasSettings = cellfun(@(h) isprop(h, 'settings'), hObjects);
                
                if sum(hasSettings) > 1
                
                    hObjects = hObjects(hasSettings);
                    settingsStruct = cellfun(@(h) h.settings, hObjects, 'uni', 0);
                    names = cellfun(@(h) class(h), hObjects, 'uni', 0);
                    callbacks = cellfun(@(h) @(name, value) h.changeSettings(name, value), hObjects, 'uni', 0);

                    settingsStruct = tools.editStruct(settingsStruct, nan, titleStr, ...
                        'Callback', callbacks, 'Name', names);

                    obj.settings = settingsStruct{1};
                    obj.saveSettings()

                    for i = 1:numel(hObjects)
                        hObjects{i}.settings = settingsStruct{i};
                        hObjects{i}.saveSettings()
                    end
                    doDefault = false;
                else
                    doDefault = true;
                end
            end

            if doDefault
                try
                    obj.hSettingsEditor = structeditor.App(obj.settings, ...
                        'Title', titleStr, 'Callback', @obj.onSettingsChanged);

                    addlistener(obj.hSettingsEditor, 'AppDestroyed', ...
                        @(s, e) obj.onSettingsEditorClosed);
                catch ME
                    
                    switch ME.identifier
                        case 'MATLAB:class:InvalidSuperClass'

                            if contains(ME.message, 'uiw.mixin.AssignPVPairs')
                                msg = 'Settings window requires the Widgets Toolbox to be installed';
                                errordlg(msg)
                                error(msg)
                            end
                                            
                        otherwise
                            rethrow(ME)

                    end
                end
            end
        end
        
        function changeSettings(obj, name, value)
        % Public access to on settings changed... Not sure what's the point
        % of keeping onSettingsChanged protected.
        %
        % Q: This would be similar setting the settings directly, no?
            obj.onSettingsChanged(name, value)
        end
        
        function resetSettingsToDefault(obj, defaultSettings)
            if nargin < 2
                defaultSettings = obj.DEFAULT_SETTINGS;
            end
            obj.settings = defaultSettings;
            obj.saveSettings()
        end
        
        function waitfor(obj)
        %uiwait Wait for the settings editor (if open)
            if ~isempty(obj.hSettingsEditor)
                obj.hSettingsEditor.waitfor()
            end
        end
    end
    
    methods % Set/get methods
        
        function pathStr = get.settingsFilePath(obj)
        %get.settingsFilePath Get settings-path based on class instance.
        %
        %   Go via a method so that subclasses can redefine how this is
        %   done
            pathStr = obj.getSettingsFilePath();
        end
        
        function set.settings(obj, newSettings)
        %set.settings Set one or more fields of the settings and trigger
        %   the onSettingsChanged callback for each of the fields that are
        %   changed. Skip callback if the source is onSettingsChanged (to
        %   prevent getting stuck in a recursive feedback loop) or
        %   settings_ (to provide a way to change settings without invoking
        %   the callback.
        
            if isempty(obj.settings_) % Initialization
                obj.settings_ = newSettings;
                obj.assignSettingNames()
                return
            end
            
            % This is probably bad practice, but a necessary condition...
            % Basically, if the settings property is changed, this should
            % trigger the onSettingsChanged callback to do necessary
            % updates to the current instance of the class. However, if the
            % settings are changed internally, this should not happen.

            wasCaller = @(fcnName, stack) numel(stack) >= 2 && ...
                contains(stack(2).name, fcnName);
            
            if wasCaller({'onSettingsChanged'}, dbstack)
                obj.settings_ = newSettings; % Update settings and return
            else
                obj.onSettingsSet(newSettings)
            end
            
            if ~isempty(obj.hSettingsEditor)
                obj.hSettingsEditor.replaceEditedStruct(obj.settings_)
            end
        end
        
        function set.settings_(obj, value)
        % Sets the protected property settings_, a way to change one or
        % more fields of settings without triggering the onSettingsChanged
        % callback. For internal use only.
            obj.settings_ = value;
            obj.assignSettingNames()
        end
        
        function S = get.settings(obj)
        % Return the value of the settings property.
            S = obj.settings_;
        end
    end
    
    methods (Access = protected)
        
        function onSettingsSet(obj, newSettings)
        %onSettingsSet Callback when settings is set from external source
            
        % Sets the settings_ property and invokes the onSettingsChanged for
        % each field in settings.
        
            subs = obj.settingsSubs;

            % Trigger onSettingsChanged for each field that changed.
            for i = 1:numel(subs)
               oldValue = subsref( obj.settings_, subs{i});
               newValue = subsref( newSettings, subs{i});

                if ~isequal( oldValue, newValue )
                    obj.settings_ = subsasgn(obj.settings_, subs{i}, newValue);
                    thisName = subs{i}(end).subs; % Note: Only using the last name for identifier. Not ideal, but it done because of legacy...
                    obj.onSettingsChanged(thisName, newValue)
                end
            end
        end
        
        % Is this needed somewhere?
        function updateSettingsValue(obj, name, value)
            % Temp solution to deal with settings struct with two levels.
            superFields = fieldnames(obj.settings);

            for i = 1:numel(superFields)
                thisField = superFields{i};
                if isfield(obj.settings.(thisField), name)
                    obj.settings.(thisField).(name) = value;
                end
            end
        end
        
        function pathStr = getSettingsFilePath(obj)
        %getSettingsFilePath Get settings file path
        %
        %   Subclasses can redefine.
        %
        %   The purpose of this is to call the static method for creating a
        %   filepath for the settings file. A subclass needs to redefine
        %   the reference for calling up the static method.
            
            className = class(obj);
            pathStr = applify.mixin.UserSettings.createFilePath(className);
            
        end
    end
    
    methods (Access = private)
        
        function assignSettingNames(obj)
        %assignSettingNames
        %
        %   Assign settings names using fieldnames recursively, so it
        %   includes fields of all substructs. This function also assigns
        %   the settingsSubs, which makes it easier to assign individual
        %   settings fields without declaring the field names explicitly in
        %   the code. See for example set.Settings for use case
        
            if isempty(obj.settings); return; end
             
            % List all fieldnames using recursive search
            fields = fieldnamesr(obj.settings);
            
            % Only keep fieldnames that are not configuration fields
            keep = ~obj.isConfigField(fields);
            obj.settingsNames = fields(keep);

            getSubs = @(name) struct('type', {'.'}, 'subs', strsplit(name, '.'));
            obj.settingsSubs = cellfun(@(name) getSubs(name), obj.settingsNames, 'uni', 0);
            
        end
        
        function onSettingsEditorClosed(obj)
            
            if ~isvalid(obj.hSettingsEditor); return; end
            
            if obj.hSettingsEditor.wasCanceled
                updatedSettings = obj.hSettingsEditor.dataOrig;
                obj.wasAborted = true;
            else
                updatedSettings = obj.hSettingsEditor.dataEdit;
                obj.wasAborted = false;
            end

            obj.saveSettings()
            
            delete(obj.hSettingsEditor)
            obj.hSettingsEditor = [];
            
            % Delete hSettingsEditor before assigning settings, because
            % assigning settings might sometimes want to make updates to
            % the settings editor, while the figure of settings editor is
            % already closed so that would cause errors
            
            obj.settings = updatedSettings;
            obj.saveSettings()
            
        end
    end
    
    methods (Static, Access = public)
        
        function settings = updateSettings(defaultSettings, loadedSettings)
        %updateSettings Update loaded settings to correspond with defaults.
        %
        %   Check if there are settings which are not loaded from file, e.g
        %   if class/settings definition was updated.
        
        % Todo: Shouldn't this be a protected method?
        
            % Initialize settings from default settings and update values
            % for all fields that are present in the loaded settings.
            settings = defaultSettings;
            
            defaultFields = fieldnames(defaultSettings);
            loadedFields = fieldnames(loadedSettings);

            % Get all fields that are present in the loadedSettings (fields
            % might be missing whenever the default settings definition
            % change)
            
            isLoaded = ismember(defaultFields, loadedFields);
            
            % Ignore Uicontrol configfields. They should always be set
            % according to the default definition.
            ignore = applify.mixin.UserSettings.isConfigField(defaultFields);
            
            fieldsToUpdate = defaultFields(isLoaded & ~ignore);
            
            for i = 1:numel(fieldsToUpdate)
                thisField = fieldsToUpdate{i};
                settings.(thisField) = loadedSettings.(thisField);
            end
        end
        
        function TF = isConfigField(listOfFields)
            
            TF = false(size(listOfFields));
            
            % Temporary function for testing if fields end with underscore
            endsWithUnderscore = @(str) strcmp(str(end), '_');

            % Loop through fields
            for i = 1:numel(listOfFields)
                
                thisField = listOfFields{i};
                subFields = strsplit(thisField, '.');
                
                if any( cellfun(@(str) endsWithUnderscore(str), subFields) )
                    testName = thisField(1:end-1);
                    TF(i) = any(strcmp(testName, listOfFields));
                else
                    continue
                end
            end
        end
        
    end %methods (Static, private)
       
    methods (Static)
        
        function S = getSettings(className)
        %getSettings Get default settings or load settings from file.
            
            % Call the method for getting a settings filepath.
            filePath = applify.mixin.UserSettings.createFilePath(className);
            
            % Call the static load method to load settings for this class.
            S = applify.mixin.UserSettings.staticLoad(className, filePath);
            
        end
        
        function S = staticLoad(className, filePath)
            
            if isfile(filePath) % Load settings from file
                S = load(filePath, 'settings');
                S = S.settings;
            else
                mc = meta.class.fromName(className);
                isProp = strcmp({mc.PropertyList.Name}, 'DEFAULT_SETTINGS');
                S = mc.PropertyList(isProp).DefaultValue;
            end
        end
        
        function pathStr = createFilePath(className)
        %createSettingsPath Create filepath for settings of subclass
            
            % Get folder and filename for settings file.
            [classFolderpath, classFilename] = fileparts( which(className) );
            
            settingsFolderPath = fullfile(classFolderpath, 'user_settings');
            settingsFileName = strcat(classFilename, '_settings.mat');
            
            % Create folder to save settings file in if it does not exist
            if ~isfolder(settingsFolderPath); mkdir(settingsFolderPath); end
            
            % Return the filepath where to save and load settings from
            pathStr = fullfile(settingsFolderPath, settingsFileName);
        end
        
    end %methods (Static)
    
end %classdef
