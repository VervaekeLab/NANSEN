classdef Preferences < nansen.config.abstract.Preferences

    properties (Constant, Hidden)
        PreferenceGroupName = "NansenUserSession"
    end

    properties (SetObservable)
        CurrentProjectName

        InteractionMode (1,1) string ...
            { mustBeMember(InteractionMode, ["API", "GUI"]) } = "API"

        UserdataDirectory = userpath
        %PreferredDateFormat = "yyyy.mm.dd"
        %PreferredTimeFormat = "HH:MM:SS"
    end
    
    methods (Access = ?nansen.internal.user.NansenUserSession)

        function obj = Preferences(preferenceDirectory)
            import nansen.internal.user.Preferences
            
            if ~nargin || isempty(preferenceDirectory)
                preferenceDirectory = prefdir;
            end

            preferenceFilename = Preferences.buildFilePath(preferenceDirectory);
            obj@nansen.config.abstract.Preferences(preferenceFilename)
        end
        
    end

    methods (Static, Access = public)
        
        function filePath = buildFilePath(preferenceDirectory)
            % - Setup preference directory 
            if ~isfolder(preferenceDirectory); mkdir(preferenceDirectory); end

            filename = nansen.internal.user.Preferences.createFilename();
            filePath = fullfile(preferenceDirectory, filename);
        end

        function filename = createFilename()
        %Create filename for a preference file.
            classname = mfilename('class');
            prefGroupName = eval(sprintf('%s.PreferenceGroupName', classname));
            prefGroupName = matlab.lang.makeValidName(prefGroupName);
            filename = fullfile(sprintf('%s_Preferences.mat', prefGroupName));
        end
        
    end
    
end