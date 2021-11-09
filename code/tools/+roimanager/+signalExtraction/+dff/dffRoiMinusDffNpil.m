function dffOut = dffRoiMinusDffNpil(roisignals, npilsignals, doSmoothing)
% This method needs refinement, but it seems to give a signal without
% neuropil decontamination and also it is well detrended. 
% Input arrays: nSamples x nRois
% Todo: Implement running baseline
% Todo: Fix neuropil subtraction



    if nargin < 3
        doSmoothing = false;
    end

    % Calculate delta f over f.
    f0_Roi = prctile(roisignals, 20);
    f0_Npil = prctile(npilsignals, 20);

    dffRoi = (roisignals - f0_Roi) ./ f0_Roi;
    dffNpil = (npilsignals - f0_Npil) ./ f0_Npil;
    
    difference = smoothdata(dffNpil, 'movmean', 10) - smoothdata(dffRoi, 'movmean', 10);
    
    % When is npil greater than roi? This will give a negative artifact in
    % the final dff for the rois. Will use difference as correction factor.
    
    ignore = difference<0; % ignore all cases where roi dff is bigger than npil dff
    difference(ignore) = 0;
    
    if doSmoothing
        correctionFactor = smoothdata(difference);
        dffOut = smoothdata(dffRoi, 'movmean', 5) - smoothdata(dffNpil, 'movmean', 5) + correctionFactor;
    else
        if ~isa(difference, 'double') || ~isa(dffNpil, 'double')
            difference=double(difference); dffNpil=double(dffNpil);
        end
        correctionFactor = sgolayfilt(difference, 3, 11);
        dffOut = dffRoi - sgolayfilt(dffNpil, 3, 11) + correctionFactor;
    end

end