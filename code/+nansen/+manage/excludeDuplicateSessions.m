function [sessionArray, excludedSessionTable] = excludeDuplicateSessions(sessionArray, options)
%excludeDuplicateSessions - Remove sessions that share a session ID
%   sessionArray = excludeDuplicateSessions(sessionArray) removes every
%   session whose sessionID occurs more than once in sessionArray.
%
%   sessionArray = excludeDuplicateSessions(sessionArray,KeepFirst=TF)
%   also specifies whether to keep the first session of each group of
%   sessions with the same sessionID. The first session is the one with
%   the lowest index in sessionArray. The default is false.
%
%   [sessionArray,excludedSessionTable] = excludeDuplicateSessions(...)
%   also returns a table with one row for each removed session. The table
%   has the variables of the table that buildDuplicateSessionTable
%   returns. SessionIndex is the index into the input sessionArray.
%
%   See also buildDuplicateSessionTable, uiresolveDuplicateSessions

    arguments
        sessionArray
        options.KeepFirst (1,1) logical = false
    end

    duplicateTable = nansen.manage.buildDuplicateSessionTable(sessionArray);

    if options.KeepFirst
        % DuplicateNumber counts the sessions with the same sessionID in
        % the order of sessionArray, so the value 1 marks the first session.
        isExcluded = duplicateTable.DuplicateNumber > 1;
    else
        isExcluded = true(height(duplicateTable), 1);
    end

    excludedSessionTable = duplicateTable(isExcluded, :);
    sessionArray(excludedSessionTable.SessionIndex) = [];
end
