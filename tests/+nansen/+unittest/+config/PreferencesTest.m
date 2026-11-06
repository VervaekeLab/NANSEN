classdef PreferencesTest < matlab.unittest.TestCase
% PreferencesTest - Tests for reading a user's saved preferences
%
%   A user session reads the preference file of its profile when it
%   starts. Each test writes that file for a throwaway profile, starts a
%   session for the profile and checks what the session's preferences hold.
%
%   Run tests:
%       runtests('nansen.unittest.config.PreferencesTest')

    properties
        % ProfileName - User profile whose preference file the test writes
        ProfileName (1,1) string

        % PreferenceDirectory - Folder holding the profile's preference file
        PreferenceDirectory (1,1) string
    end

    methods (TestMethodSetup)
        function createProfile(testCase)
            import nansen.internal.user.NansenUserSession

            % The "test" prefix keeps leftover profiles recognisable
            testCase.ProfileName = sprintf("test_%s", nansen.util.getuuid());
            testCase.PreferenceDirectory = ...
                NansenUserSession.getPrefdir(testCase.ProfileName);
            testCase.addTeardown(@() testCase.deleteProfile())
        end
    end

    methods (Test)

        function testSavedPreferencesAreRead(testCase)
        % A value in the file replaces the declared default

            testCase.writePreferenceFile(struct( ...
                'CurrentProjectName', '', ...
                'InteractionMode', "GUI"))

            userSession = testCase.startSession();

            testCase.verifyEqual(userSession.Preferences.InteractionMode, "GUI")
        end

        function testUnknownSavedPreferenceIsSkipped(testCase)
        % A file written by another version of NANSEN can name a preference
        % this version does not declare. The session must still start, and
        % the preferences this version declares must still be read.

            testCase.writePreferenceFile(struct( ...
                'CurrentProjectName', '', ...
                'InteractionMode', "GUI", ...
                'RemovedPreference', 42))

            userSession = testCase.startSession();

            testCase.verifyEqual(userSession.Preferences.InteractionMode, "GUI")
        end
    end

    methods (Access = private)

        function writePreferenceFile(testCase, preferences)
        % Write the struct as the profile's preference file. The file holds
        % one variable named "preferences", which is the name the
        % Preferences class loads.

            filePath = nansen.internal.user.Preferences.buildFilePath( ...
                testCase.PreferenceDirectory);
            save(filePath, 'preferences')
        end

        function userSession = startSession(testCase)
        % Start a session for the test profile. The profile has no
        % projects, so the project check is skipped.

            import nansen.internal.user.NansenUserSession

            skipProjectCheck = true;
            userSession = NansenUserSession.instance( ...
                testCase.ProfileName, "force", skipProjectCheck);
        end

        function deleteProfile(testCase)
            import nansen.internal.user.NansenUserSession

            NansenUserSession.instance(testCase.ProfileName, "reset");
            if isfolder(testCase.PreferenceDirectory)
                rmdir(testCase.PreferenceDirectory, "s")
            end
        end
    end
end
