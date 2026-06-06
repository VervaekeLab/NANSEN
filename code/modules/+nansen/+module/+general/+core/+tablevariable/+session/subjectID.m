function value = subjectID(sessionObj)
%subjectID Table variable function for the session subjectID column.
%
%   value = subjectID() returns '' as the null/default value. Called by
%       the table variable update machinery to determine the expected data
%       type before processing any session objects.
%
%   value = subjectID(sessionObj) re-extracts the subject ID from the
%       session's stored data location path using the current
%       DataLocationModel, bypassing the empty-check guard applied on
%       initial table construction.
%
%   This function is registered as the UpdateFunctionName for the built-in
%   subjectID column, which causes it to appear in the "Update Column
%   Variable" context menu without requiring any additional plumbing.
%
%   See also nansen.metadata.type.Session.extractSubjectId,
%            nansen.metadata.type.Session.reassignSubjectId

    if nargin < 1
        value = {'N/A'};
        return
    end
    value = nansen.metadata.type.Session.extractSubjectId(sessionObj);
end
