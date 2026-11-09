function releaseLock = acquireLock(directory, options)
%acquireLock Let only one MATLAB at a time migrate a directory
%
%   releaseLock = acquireLock(directory) creates the file
%   .nansen_migration.lock in directory, creating directory if needed, and
%   returns an onCleanup object that removes the file when it is cleared
%   or goes out of scope. While another MATLAB holds the file, this
%   function waits for it to be removed.
%
%   The file is created with java.io.File.createNewFile, which checks that
%   the file does not exist and creates it as one atomic operation, so two
%   MATLAB sessions that start together can not both get the lock.
%
%   A lock is not taken over automatically, because a holder that is slow
%   can not be told apart from one that has stopped.
%
%   Name-value arguments:
%       TimeoutSeconds - How long to wait for another MATLAB. Default 120.
%
%   Throws NANSEN:Migration:LockTimeout when the wait runs out.

    arguments
        directory (1,1) string
        options.TimeoutSeconds (1,1) double {mustBeNonnegative} = 120
    end

    % Another session can create the folder first, and with outputs mkdir
    % does not warn about that
    if ~isfolder(directory)
        [~, ~] = mkdir(directory);
    end

    lockPath = fullfile(directory, ".nansen_migration.lock");
    lockFile = java.io.File(char(lockPath));

    waitStart = tic;
    hasAnnouncedWait = false;

    while ~lockFile.createNewFile()
        if toc(waitStart) >= options.TimeoutSeconds
            error('NANSEN:Migration:LockTimeout', ...
                ['Another MATLAB is updating the NANSEN data in "%s". Wait for ' ...
                 'it to finish and start NANSEN again. If no other MATLAB is ' ...
                 'running NANSEN, delete the file "%s".'], directory, lockPath)
        end

        if ~hasAnnouncedWait
            fprintf('Waiting for another MATLAB that is updating the NANSEN data...\n')
            hasAnnouncedWait = true;
        end

        pause(0.2)
    end

    releaseLock = onCleanup(@() delete(lockPath));
end
