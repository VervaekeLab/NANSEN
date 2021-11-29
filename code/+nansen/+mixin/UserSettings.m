classdef UserSettings < applify.mixin.UserSettings
%nansen.mixin.UserSettings Subclass the applify.mixin.UserSettings to redefine
%   the default saving policy for settings files. Settings will be saved to 
%   the nansen _userdata folder instead of being saved locally next the 
%   owning class file definition.
%
%   Any class that inherits this class must implement the following:
%     * Properties:     USE_DEFAULT_SETTINGS, DEFAULT_SETTINGS (Constant, Hidden)
%     * Methods:        onSettingsChanged(obj, name, value) (protected)
%
%   Subclasses can implement a static getSettings method like this:
%       function S = getSettings()
%           S = getSettings@nansen.mixin.UserSettings('subclass_name');
%       end
%   Then settings can be loaded without creating a class object first.
%
%   See also uim.mixin.UserSettings

    methods (Access = protected)
        
        function pathStr = getSettingsFilePath(obj)
        %getSettingsFilePath Get settings file path
        %
        %   Override superclass method.
        %
        %   The purpose of this is to call the static method for creating a
        %   filepath for the settings file. A subclass needs to redefine
        %   the reference for calling up the static method.
            
            className = class(obj);
            pathStr = nansen.mixin.UserSettings.createFilePath(className); 
            
        end
    end
    
    methods (Static)
        
        function S = getSettings(className)
        %getSettings Get default settings or load settings from file.
            
            % Get the filepath where the settings are saved.
            filePath = nansen.mixin.UserSettings.createFilePath(className);
            
            % Use the static load method to get settings for this class
            S = applify.mixin.UserSettings.staticLoad(className, filePath);
        end
        
        function pathStr = createFilePath(className)
        %createSettingsPath Create filepath for settings of subclass 
            
            % Save settings into the nansen/_userdata folder.
            nansenPath = utility.path.getAncestorDir(nansen.rootpath, 1);
            settingsFolderPath = fullfile(nansenPath, '_userdata', 'settings');
        
            % Create a filename
            className = lower( strrep(className, '.', '_') );
            settingsFileName = strcat(className, '_settings.mat');
            
            % Create folder to save settings file in if it does not exist
            if ~exist(settingsFolderPath, 'dir'); mkdir(settingsFolderPath); end
            
            % Return the filepath where to save and load settings from
            pathStr = fullfile(settingsFolderPath, settingsFileName);
        end
        
    end

end