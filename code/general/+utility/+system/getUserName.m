function username = getUserName()
%GETUSERNAME Return username for current user
%
%   username = GETUSERNAME()


% Find username of current user
if ismac || isunix
    [~, username] = system('whoami');
    username = username(1:end-1); % remove new-line char at end
elseif ispc
    username = getenv('USERNAME');
else
    username = 'unknown_user';
end

end