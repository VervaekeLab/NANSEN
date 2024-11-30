% Close nansen app
nansen.App.quit()

% Reset user session
nansen.internal.user.NansenUserSession.instance('', 'reset');
