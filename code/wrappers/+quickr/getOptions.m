function S = getOptions(varargin)


    S = struct();
    
    S.RoiDiameter = [12, 12];
    S.MaxNumRois = 300; % For axonal data...?
    S.MinimumDiameter = [4,4];
    S.MaximumDiameter = [16,16];
    
% %     Image loading : General autosegmentation options.
% %     S.FirstFrame = 1;
% %     S.NumFrames = inf; % I.e only use subset of frames for estimationt
% %     S.BatchSize = 2000;
% %     
% %     S.TemporalDownsampling = 10;
    
    S.MorphologicalSearch = true;
    S.MorphologicalFeatures = 'ring';
    S.MorphologicalFeatures_ = {'ring', 'disk'};
    S.MorphologicalSearchFrequency = 1; % I.e Do this for an average of each chunk, or only once, or something in between??
    
    
    % Background subtraction
    S.TemporalDownsamplingFactor = 10;
    S.TemporalDownsamplingMethod = 'maximum';
    S.SpatialFilterKernel = 20; % For gaussian smoothing when creating BG  
    S.PrctileForBaseline = 25; % For background when computing Dff stack..

    % Binarization
    S.PrctileForThresholding = 93;
    
    % Todo: Options that separate axonal from somas...
    
    
    
    
end



