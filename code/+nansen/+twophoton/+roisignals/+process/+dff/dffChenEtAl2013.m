function dff_true = dffChenEtAl2013(signalArray, varargin)
% dF/F is calculated according to the method used by Chen et al (2013,
% Nature) by subtracting neuropil at a weight of 70%. However, while not
% specified in the Chen paper, here the baseline of the neuropil is added
% back into the signal as to not subtract too much.

%   signalArray is nSamples x nSubregions x nRois

    fRoi = squeeze(signalArray(:, 1, :));
       
    numSubregions = size(signalArray, 2);

    if numSubregions == 2
        fPil = squeeze(signalArray(:, 2, :));
    elseif numSubregions > 2
        fPil = squeeze( mean(signalArray(:, 2:end, :), 2) );
    end
    
    npil_true0 = prctile(fPil, 20);
    f_true = fRoi - (0.7*fPil) + npil_true0;
    f_true0 = prctile(f_true, 20);
    dff_true = (f_true - f_true0) ./ f_true0;
    
end