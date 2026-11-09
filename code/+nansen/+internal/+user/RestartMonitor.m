classdef RestartMonitor < handle
%RestartMonitor Notice that a running session needs a restart
%
%   monitor = nansen.internal.user.RestartMonitor(checkFunction) calls
%   checkFunction once a minute. When it returns true, the monitor stops
%   and fires the event RestartNeeded, so that the user is asked once.
%
%   monitor = RestartMonitor(checkFunction, PeriodSeconds=seconds) checks
%   at another interval.
%
%   A check that throws an error is treated as a check that found nothing,
%   so that a passing problem such as an unmounted drive does not stop the
%   monitoring or interrupt the user.
%
%   See also nansen.internal.user.NansenUserSession/isRestartNeeded

    properties (Access = private)
        Timer
        CheckFunction function_handle
    end

    events
        RestartNeeded
    end

    methods

        function obj = RestartMonitor(checkFunction, options)
            arguments
                checkFunction (1,1) function_handle
                options.PeriodSeconds (1,1) double {mustBePositive} = 60
            end

            obj.CheckFunction = checkFunction;

            obj.Timer = timer( ...
                'Name', 'NansenRestartMonitorTimer', ...
                'ExecutionMode', 'fixedSpacing', ...
                'Period', options.PeriodSeconds, ...
                'StartDelay', options.PeriodSeconds, ...
                'TimerFcn', @(~, ~) obj.check() );

            start(obj.Timer)
        end

        function delete(obj)
            if ~isempty(obj.Timer) && isvalid(obj.Timer)
                stop(obj.Timer)
                delete(obj.Timer)
            end
        end
    end

    methods (Access = private)

        function check(obj)
            try
                isRestartNeeded = obj.CheckFunction();
            catch
                % Nothing was found out this time. The next check tries again.
                return
            end

            if isRestartNeeded
                % Stopped first, because a listener can delete this monitor
                % and MATLAB warns when a running timer is deleted.
                stop(obj.Timer)
                notify(obj, 'RestartNeeded')
            end
        end
    end
end
