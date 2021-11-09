function sessionID = validateSessionObject(sessionID, mode)
%validateSessionID Validate a sessionObject or list of sessionObjects
%
%   sessionID = validateSessionID(sessionID, mode) validates a sessionID or
%   a list of sessionIDs using the rules in strfindsid. sessionID is either
%   a character vector or a cell array of character vectors. mode is a 
%   character vector of either 'single', 'multi' or 'any' and determines if 
%   one or several sessionIDs are accepted. An error is thrown if the
%   sessionID is invalid or if it does not match the mode.
%
%   Returns sessionID where sessionID is a char if mode is 'single' and a 
%   cell array if mode is 'multi' or 'any'.
%
%   The purpose of this function is to throw an error in a caller function
%   if sessionID has the wrong form, either being an invalid sessionID or
%   being of a mode not accepted in the caller function.



switch mode
    
    case 'single'
             
        if isa(sessionID, 'cell') && numel(sessionID) == 1
            sessionID = sessionID{1};
        end
        
        isSessionObj = isa(sessionID, 'nansen.metadata.schema.generic.Session');
        isValid = true; %contains(sessionID, strfindsid(sessionID));
                
        if ~(isSessionObj && isValid)
            ME = MException('VLab:InvalidSessionInput:singleSessionRequired', 'This function requires a single session to work');
            throwAsCaller(ME)
        end
        
    case 'multi'
       
        if isa(sessionID, 'cell')
            sessionID = [sessionID{:}];
        end
        
        isSessionObj = isa(sessionID, 'nansen.metadata.schema.generic.Session');
        isMulti = numel(sessionID) > 1;
        
        if ~(isSessionObj && isMulti)
            ME = MException('VLab:InvalidSessionInput:multipleSessionsRequired', 'This function requires multiple sessions to work');
            throwAsCaller(ME)
        end
        
    case 'any'
        
        ME = MException('VLab:InvalidArg:NotImplentedYet', 'Not implemented yet');
        throwAsCaller(ME)
        
        
        if isa(sessionID, 'char')
            isValid = contains(sessionID, strfindsid(sessionID));
        elseif isa(sessionID, 'cell')
            isValid = all(cellfun(@(sid) contains(sid, strfindsid(sid)), sessionID));
        else
            isValid = false;
        end
        
        if ~isValid 
            ME = MException('VLab:InvalidSessionInput:invalidSessionID', 'One or more sessionIDs are not valid.');
            throwAsCaller(ME)
        end
        
        if isa(sessionID, 'char'); sessionID = {sessionID}; end

end


if ~nargout
    clear sessionID
end



end