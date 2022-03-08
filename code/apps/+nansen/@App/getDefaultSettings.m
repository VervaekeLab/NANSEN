function S = getDefaultSettings()

% NB: This will not be updated in a class until matlab is restarted or the
% class is cleared and reinitialized.


S = struct();
S.MetadataTable.ShowIgnoredEntries = true;
S.MetadataTable.AllowTableEdits = true;

S.TaskProcessor.TimerPeriod = 10;
S.TaskProcessor.RunTasksWhenQueued = false;
S.TaskProcessor.RunTasksOnStartup = false;



end
