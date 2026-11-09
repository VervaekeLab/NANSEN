classdef RestartMonitorTest < matlab.unittest.TestCase
%RestartMonitorTest Tests for the monitor that notices that a restart is needed
%
%   The monitor is given a test double for the check, and a short period.
%
%   Run tests:
%       runtests('nansen.unittest.user.RestartMonitorTest')

    properties (Constant)
        PERIOD_SECONDS = 0.05
        TIMEOUT_SECONDS = 5
    end

    properties
        NumEvents (1,1) double = 0
        NumChecks (1,1) double = 0
    end

    methods (Test)

        function testEventFiresWhenARestartIsNeeded(testCase)
            testCase.createMonitor(@() true); %#ok<*NASGU>

            testCase.waitUntil(@() testCase.NumEvents > 0)

            testCase.verifyEqual(testCase.NumEvents, 1)
        end

        function testEventFiresOnlyOnce(testCase)
        % The user is asked once, however long the session keeps running

            testCase.createMonitor(@() true);

            testCase.waitUntil(@() testCase.NumEvents > 0)
            pause(5*testCase.PERIOD_SECONDS)

            testCase.verifyEqual(testCase.NumEvents, 1)
        end

        function testNoEventWhileNoRestartIsNeeded(testCase)
            testCase.createMonitor(@() testCase.countCheck(false));

            testCase.waitUntil(@() testCase.NumChecks >= 3)

            testCase.verifyEqual(testCase.NumEvents, 0)
        end

        function testFailedCheckDoesNotStopTheMonitor(testCase)
            testCase.createMonitor(@() testCase.failThenFindRestart());

            testCase.waitUntil(@() testCase.NumEvents > 0)

            testCase.verifyGreaterThan(testCase.NumChecks, 1)
        end

        function testDeletingTheMonitorRemovesItsTimer(testCase)
            monitor = testCase.createMonitor(@() false);

            delete(monitor)

            testCase.verifyEmpty(timerfindall('Name', 'NansenRestartMonitorTimer'))
        end

        function testListenerCanDeleteTheMonitor(testCase)
        % Restarting from the prompt closes the app that owns the monitor

            lastwarn('')

            monitor = testCase.createMonitor(@() true);
            addlistener(monitor, 'RestartNeeded', @(source, ~) delete(source));

            testCase.waitUntil(@() ~isvalid(monitor))

            [~, warningId] = lastwarn();
            testCase.verifyNotEqual(warningId, 'MATLAB:timer:deleterunning')
            testCase.verifyEmpty(timerfindall('Name', 'NansenRestartMonitorTimer'))
        end
    end

    methods (Access = private)

        function monitor = createMonitor(testCase, checkFunction)
            monitor = nansen.internal.user.RestartMonitor(checkFunction, ...
                PeriodSeconds=testCase.PERIOD_SECONDS);
            addlistener(monitor, 'RestartNeeded', @(~, ~) testCase.countEvent());
            testCase.addTeardown(@() delete(monitor))
        end

        function countEvent(testCase)
            testCase.NumEvents = testCase.NumEvents + 1;
        end

        function tf = countCheck(testCase, result)
            testCase.NumChecks = testCase.NumChecks + 1;
            tf = result;
        end

        function tf = failThenFindRestart(testCase)
            testCase.NumChecks = testCase.NumChecks + 1;
            if testCase.NumChecks == 1
                error('Test:CheckProblem', 'The check failed.')
            end
            tf = true;
        end

        function waitUntil(testCase, condition)
        %waitUntil Let the timer run until a condition holds

            waitStart = tic;
            while ~condition() && toc(waitStart) < testCase.TIMEOUT_SECONDS
                pause(testCase.PERIOD_SECONDS)
            end

            testCase.assertTrue(condition(), 'The condition was not reached in time.')
        end
    end
end
