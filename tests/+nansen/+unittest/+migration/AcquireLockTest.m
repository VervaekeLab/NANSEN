classdef AcquireLockTest < matlab.unittest.TestCase
%AcquireLockTest Tests for the lock that lets one MATLAB migrate a directory
%
%   Run tests:
%       runtests('nansen.unittest.migration.AcquireLockTest')

    properties (Constant)
        LOCK_FILENAME = ".nansen_migration.lock"
    end

    properties
        Directory (1,1) string
        LockPath (1,1) string
    end

    methods (TestMethodSetup)
        function createDirectory(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture

            fixture = testCase.applyFixture(TemporaryFolderFixture);
            testCase.Directory = fullfile(fixture.Folder, "userdata");
            testCase.LockPath = fullfile(testCase.Directory, testCase.LOCK_FILENAME);
        end
    end

    methods (Test)

        function testLockFileExistsWhileHeld(testCase)
            releaseLock = nansen.internal.migration.acquireLock(testCase.Directory); %#ok<NASGU>

            testCase.verifyTrue(isfile(testCase.LockPath))
        end

        function testReleasingRemovesTheFile(testCase)
            releaseLock = nansen.internal.migration.acquireLock(testCase.Directory);

            clear releaseLock

            testCase.verifyFalse(isfile(testCase.LockPath))
        end

        function testSecondHolderIsRefusedAfterTheTimeout(testCase)
            releaseLock = nansen.internal.migration.acquireLock(testCase.Directory); %#ok<NASGU>

            testCase.verifyError( ...
                @() nansen.internal.migration.acquireLock(testCase.Directory, TimeoutSeconds=0), ...
                'NANSEN:Migration:LockTimeout')
            testCase.verifyTrue(isfile(testCase.LockPath))
        end

        function testLockCanBeTakenAfterRelease(testCase)
            firstLock = nansen.internal.migration.acquireLock(testCase.Directory);
            clear firstLock

            secondLock = nansen.internal.migration.acquireLock(testCase.Directory, TimeoutSeconds=0); %#ok<NASGU>

            testCase.verifyTrue(isfile(testCase.LockPath))
        end

        function testWaiterGetsTheLockWhenItIsReleased(testCase)
        % Stands in for another MATLAB finishing while this one waits

            mkdir(testCase.Directory)
            fclose(fopen(testCase.LockPath, 'w'));

            removeLater = timer('StartDelay', 0.3, ...
                'TimerFcn', @(~, ~) delete(testCase.LockPath));
            testCase.addTeardown(@() delete(removeLater))
            start(removeLater)

            releaseLock = nansen.internal.migration.acquireLock( ...
                testCase.Directory, TimeoutSeconds=10); %#ok<NASGU>

            testCase.verifyTrue(isfile(testCase.LockPath))
        end
    end
end
