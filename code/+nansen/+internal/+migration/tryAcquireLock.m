function releaseLock = tryAcquireLock(directory)
%tryAcquireLock Take the migration lock, unless the directory can not be written to
%
%   releaseLock = tryAcquireLock(directory) returns what
%   nansen.internal.migration.acquireLock returns, or [] when the lock file
%   could not be created. A directory that can not be written to needs no
%   lock, because nothing can migrate it, and the code that tries to will
%   report the failure in its own terms.
%
%   Throws NANSEN:Migration:LockTimeout when another MATLAB holds the lock
%   for too long.

    arguments
        directory (1,1) string
    end

    releaseLock = [];

    try
        releaseLock = nansen.internal.migration.acquireLock(directory);
    catch ME
        if strcmp(ME.identifier, 'NANSEN:Migration:LockTimeout')
            rethrow(ME)
        end
    end
end
