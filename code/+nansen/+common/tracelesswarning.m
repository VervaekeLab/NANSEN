function tracelesswarning(varargin)
    warningState = warning('off', 'backtrace');
    cleanupObj = onCleanup(@(ws) warning(warningState));
    warning(varargin{:})
end
