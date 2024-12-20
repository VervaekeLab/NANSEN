function tracelesswarning(varargin)
    warningState = warning();
    cleanupObj = onCleanup(@(ws) warning(warningState));
    warning('off', 'backtrace');
    warning(varargin{:})
end
