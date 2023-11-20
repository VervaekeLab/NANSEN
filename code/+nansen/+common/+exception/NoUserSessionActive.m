function ME = NoUserSessionActive()
    msgID = 'NANSEN:NoUserSessionActive';
    msgText = 'No user session is active. Please start nansen and try again.';
    ME = MException(msgID, msgText);
end