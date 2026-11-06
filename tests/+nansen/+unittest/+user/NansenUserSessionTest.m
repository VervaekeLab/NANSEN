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

            testCase.verifyClass(userNames, "string");
            testCase.verifyTrue(any(userNames == userName));
        end

        function testListUserNamesIsSorted(testCase)
            % The names are shown to the user next to a name they typed, so
            % they are sorted rather than left in directory order.
            lastName = testCase.createProfileDirectory("zz_unittest_user_");
            firstName = testCase.createProfileDirectory("aa_unittest_user_");

            userNames = nansen.internal.user.NansenUserSession.listUserNames();

            % Locate both names first. Comparing positions straight away
            % would fail with an unrelated error if either were missing.
            testCase.assertTrue(any(userNames == firstName));
            testCase.assertTrue(any(userNames == lastName));

            testCase.verifyLessThan( ...
                find(userNames == firstName), find(userNames == lastName));
        end

        function testListUserNamesExcludesDotEntries(testCase)
            % dir returns "." and ".." for every folder. They are not user
            % profiles and must never reach the confirmation message.
            %
            % The profile is created so that the root directory is known to
            % exist. Without it listUserNames could take its early return
            % and the test would pass without listing anything.
            testCase.createProfileDirectory();

            userNames = nansen.internal.user.NansenUserSession.listUserNames();

            testCase.verifyNotEmpty(userNames);
            testCase.verifyFalse(any(userNames == "."));
            testCase.verifyFalse(any(userNames == ".."));
        end

        function testListUserNamesIncludesProfileWithOnlyUserData(testCase)
            % The preference directory belongs to one MATLAB release. A
            % profile created in another release has only its user data
            % directory here, and must still be listed.
            userName = testCase.createUserDataDirectory();

            userNames = nansen.internal.user.NansenUserSession.listUserNames();

            testCase.verifyTrue(any(userNames == userName));
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
            % A misspelled name has no profile. This is the condition which
            % triggers the confirmation prompt.
            userName = "unittest_user_never_created";

            testCase.verifyFalse( ...
                nansen.internal.user.NansenUserSession.isExistingUser(userName));
        end

        function testIsExistingUserRejectsNameDifferingOnlyByCase(testCase)
            % isfolder matches names case insensitively on macOS and
            % Windows, so a lookup by directory would accept a name that
            % differs from a profile only by capitalisation. The lookup
            % compares the names instead.
            userName = testCase.createProfileDirectory();

            testCase.verifyFalse( ...
                nansen.internal.user.NansenUserSession.isExistingUser(upper(userName)));
        end

        % ----------------------------------------------------------------
        % instance - names that differ from a profile only by case
        % ----------------------------------------------------------------

        function testNameDifferingOnlyByCaseIsRefused(testCase)
            % On macOS and Windows a profile for this name would share the
            % existing profile's directory. The name is refused before the
            % active session is looked at, also when MATLAB runs with -batch.
            import nansen.internal.user.NansenUserSession

            userName = testCase.createProfileDirectory();

            testCase.verifyError( ...
                @() NansenUserSession.instance(upper(userName)), ...
                "NANSEN:UserSession:UserNameCaseMismatch");
        end

        function testNameDifferingOnlyByCaseFromUserDataIsRefused(testCase)
            % The user data directory of a profile from another MATLAB
            % release is matched case insensitively too, so a name that
            % differs from it only by capitalisation would share it.
            import nansen.internal.user.NansenUserSession

            userName = testCase.createUserDataDirectory();

            testCase.verifyError( ...
                @() NansenUserSession.instance(upper(userName)), ...
                "NANSEN:UserSession:UserNameCaseMismatch");
        end

        function testNocreateModeDoesNotCheckTheName(testCase)
            % 'nocreate' creates no profile, so it has no reason to refuse
            % a name in the wrong case.
            import nansen.internal.user.NansenUserSession

            userName = testCase.createProfileDirectory();

            % A singleton left by an earlier test would be returned here
            % instead of an empty result.
            NansenUserSession.instance("", "reset");

            userSession = NansenUserSession.instance(upper(userName), "nocreate");

            testCase.verifyEmpty(userSession);
        end

        % ----------------------------------------------------------------
        % instance - paths which must not prompt for confirmation
        % ----------------------------------------------------------------

        function testProfileIsCreatedWhenConfirmationIsDisabled(testCase)
            % ConfirmNewUser=false is the escape hatch for programmatic
            % callers such as nansen.fixture.ProjectFixture, which create
            % throwaway profiles and must not block on user input.
            import nansen.internal.user.NansenUserSession

            userName = buildUserName();
            profileDirectory = NansenUserSession.getPrefdir(userName);

            % "force" closes any session left open by another test. Under
            % "check" that situation is resolved by prompting, which fails
            % outright in a non-interactive session.
            warnState = warning("off", "NANSEN:UserSession:UserSessionActive");
            testCase.addTeardown(@() warning(warnState));

            % Teardown runs in reverse order: reset the session, and only
            % then remove the preference directory it wrote to. The
            % directory does not exist yet, so guard against a failure
            % before it is created.
            testCase.addTeardown(@() removeDirectoryIfPresent(profileDirectory));
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

            userName = buildUserName();

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

            userName = buildUserName(prefix);
            profileDirectory = ...
                nansen.internal.user.NansenUserSession.getPrefdir(userName);

            mkdir(profileDirectory)
            testCase.addTeardown( ...
                @() removeDirectoryIfPresent(profileDirectory));
        end

        function userName = createUserDataDirectory(testCase)
        % createUserDataDirectory - Create a throwaway user data directory
        %
        %   The directory is created in the default location under MATLAB's
        %   real userpath, without a preference directory, which is what a
        %   profile created in another MATLAB release leaves on disk.

            import nansen.internal.user.NansenUserSession

            testCase.assumeNotEmpty(userpath(), ...
                "Without a userpath the user data directory is the preference directory.")

            userName = buildUserName();
            userDataDirectory = NansenUserSession.getDefaultUserDataDirectory(userName);

            mkdir(userDataDirectory)
            testCase.addTeardown( ...
                @() removeDirectoryIfPresent(userDataDirectory));
        end
    end

end

function userName = buildUserName(prefix)
% buildUserName - Build a name unlikely to collide with a real profile
%
%   The name ends with a uuid. Test processes that start at the same time
%   share prefdir and start from the same random number seed, so a random
%   number could give two of them the same profile.

    arguments
        prefix (1,1) string = "unittest_user_"
    end

    userName = prefix + string(nansen.util.getuuid());
end

function removeDirectoryIfPresent(directoryPath)
% removeDirectoryIfPresent - Remove a directory, tolerating absence
%
%   A test which fails before the directory is created would otherwise
%   report a second, unrelated failure from its teardown.

    if isfolder(directoryPath)
        rmdir(directoryPath, "s")
    end
end
