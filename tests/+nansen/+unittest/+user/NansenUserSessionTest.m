classdef NansenUserSessionTest < matlab.unittest.TestCase
    %NansenUserSessionTest Unit tests for nansen.internal.user.NansenUserSession.
    %
    %   Covers the user profile lookup helpers and the paths through
    %   instance() which must not ask the user to confirm a new profile.
    %   The interactive confirmation itself is not covered, because input
    %   cannot be substituted from a test.
    %
    %   Note: Some tests replace the NansenUserSession singleton, so an
    %   interactive session which is open while the tests run is closed.
    %
    %   Run tests:
    %       runtests('nansen.unittest.user.NansenUserSessionTest')

    methods (Test)

        % ----------------------------------------------------------------
        % listUserNames
        % ----------------------------------------------------------------

        function testListUserNamesIncludesExistingProfile(testCase)
            % A profile is recognised by the presence of its preference
            % directory, so a bare directory is enough to be listed.
            userName = testCase.createProfileDirectory();

            userNames = nansen.internal.user.NansenUserSession.listUserNames();

            testCase.verifyClass(userNames, 'string');
            testCase.verifyTrue(any(userNames == userName));
        end

        function testListUserNamesIsSorted(testCase)
            % The names are shown to the user next to a name they typed, so
            % they are sorted rather than left in directory order.
            lastName = testCase.createProfileDirectory("zz_unittest_user_");
            firstName = testCase.createProfileDirectory("aa_unittest_user_");

            userNames = nansen.internal.user.NansenUserSession.listUserNames();

            testCase.verifyLessThan( ...
                find(userNames == firstName), find(userNames == lastName));
        end

        function testListUserNamesExcludesDotEntries(testCase)
            % dir returns "." and ".." for every folder. They are not user
            % profiles and must never reach the confirmation message.
            testCase.createProfileDirectory();

            userNames = nansen.internal.user.NansenUserSession.listUserNames();

            testCase.verifyFalse(any(userNames == "."));
            testCase.verifyFalse(any(userNames == ".."));
        end

        % ----------------------------------------------------------------
        % isExistingUser
        % ----------------------------------------------------------------

        function testIsExistingUserDetectsExistingProfile(testCase)
            userName = testCase.createProfileDirectory();

            testCase.verifyTrue( ...
                nansen.internal.user.NansenUserSession.isExistingUser(userName));
        end

        function testIsExistingUserRejectsUnknownName(testCase)
            % A misspelled name has no preference directory. This is the
            % condition which triggers the confirmation prompt.
            userName = "unittest_user_never_created";

            testCase.verifyFalse( ...
                nansen.internal.user.NansenUserSession.isExistingUser(userName));
        end

        % ----------------------------------------------------------------
        % instance - paths which must not prompt for confirmation
        % ----------------------------------------------------------------

        function testProfileIsCreatedWhenConfirmationIsDisabled(testCase)
            % ConfirmNewUser=false is the escape hatch for programmatic
            % callers such as nansen.fixture.ProjectFixture, which create
            % throwaway profiles and must not block on user input.
            import nansen.internal.user.NansenUserSession

            userName = testCase.buildUserName();
            profileDirectory = NansenUserSession.getPrefdir(userName);

            % Teardown runs in reverse order: reset the session, and only
            % then remove the preference directory it wrote to.
            testCase.addTeardown(@() rmdir(profileDirectory, "s"));
            testCase.addTeardown(@() NansenUserSession.instance("", "reset"));

            userSession = NansenUserSession.instance( ...
                userName, "force", true, ConfirmNewUser=false);

            testCase.verifyEqual(userSession.CurrentUserName, userName);
            testCase.verifyTrue(isfolder(profileDirectory));
        end

        function testNocreateModeReturnsEmptyForUnknownUser(testCase)
            % 'nocreate' asks whether a session is active. It must neither
            % prompt nor leave a profile behind for an unknown name.
            import nansen.internal.user.NansenUserSession

            userName = testCase.buildUserName();

            % A singleton left by an earlier test would be returned here
            % instead of an empty result.
            NansenUserSession.instance("", "reset");

            userSession = NansenUserSession.instance(userName, "nocreate");

            testCase.verifyEmpty(userSession);
            testCase.verifyFalse(isfolder(NansenUserSession.getPrefdir(userName)));
        end
    end

    methods (Access = private)

        function userName = createProfileDirectory(testCase, prefix)
        % createProfileDirectory - Create a throwaway user profile directory
        %
        %   The directory is created under MATLAB's real preference
        %   directory, because getPrefdir derives its path from prefdir,
        %   which can not be redirected from a running session.

            arguments
                testCase
                prefix (1,1) string = "unittest_user_"
            end

            userName = testCase.buildUserName(prefix);
            profileDirectory = ...
                nansen.internal.user.NansenUserSession.getPrefdir(userName);

            mkdir(profileDirectory)
            testCase.addTeardown(@() rmdir(profileDirectory, "s"));
        end

        function userName = buildUserName(~, prefix)
        % buildUserName - Build a name unlikely to collide with a real profile

            arguments
                ~
                prefix (1,1) string = "unittest_user_"
            end

            userName = prefix + string(randi([1e8, 1e9-1]));
        end
    end
end
