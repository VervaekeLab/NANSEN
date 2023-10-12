function S = getDefaultOptions()

    % Big todo. Implement this in same way as getNormCorreOptions
    %   Also, expand the normcorre options (nansen version) 
    %   to include these.

    S = struct();

    S.Preprocessing.NumFlybackLines = 0;

    S.Preprocessing.BidirectionalCorrection = 'None';
    S.Preprocessing.BidirectionalCorrection_ = {'None', 'Constant', 'Continuous'};
    %S.Preprocessing.BidirectionalCorrection_ = {'None', 'One Time', 'Continuous'};
    
    S.General.correctDrift = false;
    
    
    S.Preview.firstFrame = 1;
    S.Preview.numFrames = 500;
    S.Preview.saveResults = false;
    S.Preview.showResults = true;
    S.Preview.run = false;
    S.Preview.run_ = struct('type', 'button', 'args', {{'String', 'Run Preview'}});

    S.Export = struct();
    %S.Export.saveParemetersToFile_ = 'uiputfile';
    %S.Export.saveParemetersToFile = '';
    %S.Export.PreviewSaveFolder_ = 'uigetdir';
    %S.Export.PreviewSaveFolder = '';
    
    S.Export.FileName = '';
    S.Export.FileName_ = 'transient';
    S.Export.SaveDirectory = '';
    S.Export.SaveDirectory_ = 'uigetdir';  %internal  
    S.Export.OutputDataType = 'uint8';
    S.Export.OutputDataType_ = {'uint8', 'uint16'};
    S.Export.IntensityAdjustmentPercentile = 0.005;
    S.Export.IntensityAdjustmentPercentile_ = {0.05, 0.005, 0};
    S.Export.IntensityAdjustmentMode = 'mean for all frames';
    S.Export.IntensityAdjustmentMode_ = {'mean for all frames', 'brightest/darkest frame'};
    S.Export.OutputFormat = 'Tiff';
    S.Export.OutputFormat_ = {'Binary', 'Tiff'};
    S.Export.saveAverageProjection = true;
    S.Export.saveMaximumProjection = true;
    
    
% %     S.numFramesPerPart = 1000; % Image stack method...
% %     S.OutputDataType = 'uint8';
% %     S.OutputDataType_ = {'uint8', 'uint16', 'uint32'};
% %     S.OutputFileFormat = 'raw';
% % 
% %     
% %     
% %     S.NumFlybackLines = 0;  % Remove lines in top of image (if the flyback is sampled)
% %     S.BidirectionalCorrection = 'None';
% %     S.BidirectionalCorrection_ = {'None', 'Constant', 'Time Dependent'};
% %     S.correctDrift = false;
% % 
% % 
% % 
% % 
% %     S.saveAverageProjection = true;
% %     S.saveMaximumProjection = true;
% % 
% % 
% %     S.RedoAligning = false;  % Redo aligning if it already was performed...
% %     S.partsToAlign = [];
% % 
% %     S.updateTemplate = true;
% %     S.frameNumForInitialTemplate = 1:200;
% % 
% % 
% %     S.RecastOutput = true; % Internal...

end