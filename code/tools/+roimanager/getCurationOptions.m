function S = getCurationOptions()

    S = struct();
    
% % %     S.selectVariable = 'Area';
% % %     S.selectVariable_ = {'Area', 'PeakT'};
% % %
% % %     S.cutoffValues = [0, 1];
% % %
% % %     S.cutoffValuesRef = struct('Area', [50, 200], 'PeakT', [1,20]);
% % %     S.cutoffValuesRef_ = 'internal';

    S.openClassifierApp = false;
    S.openClassifierApp_ = struct('type', 'button', 'args', {{'String', 'Open Classifier', 'FontWeight', 'bold', 'ForegroundColor', [0.1840    0.7037    0.4863]}});

end
