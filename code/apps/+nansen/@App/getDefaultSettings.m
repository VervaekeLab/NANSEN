function S = getDefaultSettings()

% NB: This will not be updated in a class until matlab is restarted or the
% class is cleared and reinitialized.


S = struct();
S.MetadataTable.ShowIgnoredEntries = true;
S.MetadataTable.AllowTableEdits = true;
S.MetadataTable.AutosaveMetaTable = true;

% % S.Session.ExportSessionObjectAs = 'Nansen';
% % S.Session.ExportSessionObjectAs_ = {'Nansen', 'NDI'};
S.Session.SessionObjectWorkspaceName = 'sessionObjects';
S.Session.OptionEditMode = 'Only once';
S.Session.OptionEditMode_ = {'Only once', 'For each session'};
S.Session.SessionTaskDebug = false;

% Task processor settings:
% S.TaskProcessor.TimerPeriod = 10;
S.TaskProcessor.RunTasksWhenQueued = false;
S.TaskProcessor.RunTasksOnStartup = false;

end
