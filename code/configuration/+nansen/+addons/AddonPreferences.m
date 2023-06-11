classdef AddonPreferences < nansen.external.fex.utility.Preferences
    
    properties (Constant, Hidden)
        PreferenceGroupName = 'NansenAddonManager'
    end

    properties
        % Directory to save Nansen Addons
        AddonDirectory = fullfile(userpath, 'Nansen-Addons')
    end

    methods (Access = ?nansen.external.fex.utility.Preferences)
        function obj = AddonPreferences()
            obj@nansen.external.fex.utility.Preferences()
        end
    end

    methods (Static, Hidden)
        function singletonObj = getSingleton()
            import nansen.external.fex.utility.Preferences
            thisClassName = mfilename('class');
            singletonObj = Preferences.getSingleton(thisClassName);
        end
    end
    
end