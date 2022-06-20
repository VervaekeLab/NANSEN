function S = getDefaultSettings()

    S = struct();    % GUI settings
%     S.showTags = false;
%     S.showNpMask = false;
%     S.colorRoiBy = 'Validation Status';
%     S.colorRoiBy_ = {'Activity Level', 'Category', 'Validation Status', 'RoiGroup'};

    S.ExperimentInfo = getExperimentSettings();
    S.RoiDisplayPreferences = roimanager.roiDisplayParameters();
    %S.RoiSelectionPreferences = getSelectionSettings();
    S.SignalExtraction = nansen.twophoton.roisignals.extract.getDefaultParameters();
    S.DffOptions = nansen.twophoton.roisignals.computeDff();
    S.Autosegmentation = nansen.twophoton.roimasks.autosegmentationOptions();
    S.RoiCuration = roimanager.getCurationOptions();
    
end


function S = getExperimentSettings()

    S = struct();
    S.ExperimentName = '';
    %S.SampleRate = [];
    
    S.OpenStack = false;
    S.OpenStack_ = struct('type', 'button', 'args', {{'String', 'Open Image Stack...', 'FontWeight', 'bold', 'ForegroundColor', [0.1840    0.7037    0.4863]}});
    
    S.LoadRois = false;
    S.LoadRois_ = struct('type', 'button', 'args', {{'String', 'Load Rois...', 'FontWeight', 'bold', 'ForegroundColor', [0.1840    0.7037    0.4863]}});
    
    S.SaveRois = false;
    S.SaveRois_ = struct('type', 'button', 'args', {{'String', 'Save Rois...', 'FontWeight', 'bold', 'ForegroundColor', [0.1840    0.7037    0.4863]}});

end

function S = getSelectionSettings()

    S = struct();
    
    S.SelectNextRoiOnClassify = false;
    S.NextRoiSelectionMode = 'Next in list';
    S.NextRoiSelectionMode_ = {'None', 'Next in list', 'Next in list with same classification', 'Closest distance', 'Closest distance with same classification'};

    
end