function S = getDefaultSettings()

    S = struct();    % GUI settings
%     S.showTags = false;
%     S.showNpMask = false;
%     S.colorRoiBy = 'Validation Status';
%     S.colorRoiBy_ = {'Activity Level', 'Category', 'Validation Status', 'RoiGroup'};

    S.ExperimentInfo = struct('FrameRate', 20);
    S.RoiDisplayPreferences = roimanager.roiDisplayParameters();
    S.SignalExtraction = nansen.twophoton.roisignals.extract.getDefaultParameters();
    S.DffOptions = nansen.twophoton.roisignals.computeDff();
    S.Autosegmentation = nansen.twophoton.roimasks.autosegmentationOptions();
    S.RoiCuration = roimanager.getCurationOptions();
    
end