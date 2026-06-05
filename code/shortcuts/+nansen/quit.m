% Close nansen app
nansen.App.quit()

% Reset cached MetaTable instances
nansen.metadata.MetaTableCache.instance("reset");

% Reset data cache
nansen.cache.DataCache.instance("reset");

% Reset user session
nansen.internal.user.NansenUserSession.instance('', 'reset');
