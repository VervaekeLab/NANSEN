function warningCleanupObj = suppressWarning(warningId)
% suppressWarning - Temporarily suppress warning with given warning id
%
% Example usage:
%
%   warningIdentifier = 'MATLAB:callback:error';
%   warningCleanup = nansen.common.suppressWarning(warningIdentifier); %#ok<NASGU>

    arguments
        warningId (1,:) char
    end
    warnState = warning('off', warningId);
    warningCleanupObj = onCleanup(@() warning(warnState));
end
