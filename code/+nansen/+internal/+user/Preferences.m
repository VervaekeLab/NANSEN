classdef Preferences < nansen.config.abstract.Preferences

    properties (Constant, Hidden)
        PreferenceGroupName = "NansenUserSession"
    end

    properties (SetObservable)
        CurrentProjectName

        InteractionMode (1,1) string ...
            { mustBeMember(InteractionMode, ["API", "GUI"]) } = "API"

        % UserDataDirectory - Directory holding this user's NANSEN data.
        % Holds the project catalog and, alongside it, the configurations
        % that belong to this user rather than to a MATLAB release. An
        % empty value means the default location under MATLAB's userpath
        % is used. Set it to keep everything in one place across MATLAB
        % releases, or to put it on a shared or synchronized folder.
        UserDataDirectory (1,1) string = ""
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
            prefGroupName = nansen.internal.introspection.getConstantPropertyValue(classname, 'PreferenceGroupName');
            prefGroupName = matlab.lang.makeValidName(prefGroupName);
            filename = fullfile(sprintf('%s_Preferences.mat', prefGroupName));
        end

        function value = readValue(preferenceDirectory, preferenceName)
        %readValue Read one preference value from a user's preference file
        %
        %   value = readValue(preferenceDirectory, preferenceName) returns
        %   the value of the named preference for the user whose
        %   preferences are stored in preferenceDirectory. The declared
        %   default is returned if no preference file exists yet, or if the
        %   file was written before the preference was introduced.
        %
        %   Note: The value is read from file instead of from the singleton
        %   instance because a caller may need a preference while the user
        %   session is still being constructed, that is, before the session
        %   singleton can be reached. Reading from file is consistent with
        %   the instance, because every preference assignment is written to
        %   file immediately.
        %
        %   See also nansen.config.abstract.Preferences

            arguments
                preferenceDirectory (1,1) string
                preferenceName (1,1) string
            end

            import nansen.internal.user.Preferences

            value = Preferences.getDeclaredDefault(preferenceName);

            filePath = fullfile(preferenceDirectory, Preferences.createFilename());
            if ~isfile(filePath); return; end

            S = load(filePath, 'preferences');
            if isfield(S, 'preferences') && isfield(S.preferences, preferenceName)
                value = S.preferences.(preferenceName);
            end
        end
    end

    methods (Static, Access = private)

        function value = getDeclaredDefault(preferenceName)
        %getDeclaredDefault Get the default value declared for a preference

            metaClass = ?nansen.internal.user.Preferences;
            propertyList = metaClass.PropertyList;

            isMatch = strcmp({propertyList.Name}, preferenceName);
            if ~any(isMatch)
                error('NANSEN:Preferences:UnknownPreference', ...
                    ['There is no preference named "%s". Check the ' ...
                     'spelling of the preference name.'], preferenceName)
            end

            if propertyList(isMatch).HasDefault
                value = propertyList(isMatch).DefaultValue;
            else
                value = [];
            end
        end
    end
end
