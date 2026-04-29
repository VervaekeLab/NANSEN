function value = update(sessionObject)
%update Return a simple session label for registry tests.

    if nargin == 0
        value = '';
    else
        value = sessionObject.sessionID;
    end
end
