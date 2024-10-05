function dff = dffRoiMinusDffNpil(signalArray, varargin)

%   INPUTS:
%
%   signalArray : 3D array (numSamples x numSubregions x numRois)
%   varargin : Options as struct or name-value pairs.
    
% This method needs refinement, but it seems to give a signal without
% neuropil decontamination and also it is well detrended.

    % Todo:
    %   [ ] Implement running baseline
    %   [ ] Fix neuropil subtraction
    
    P = struct;
    P.baseline = 20;
    P.smoothSignals = false;
    
    params = utility.parsenvpairs(P, [], varargin{:});

    % % Prepare roi and neuropil signals
    fRoi = squeeze(signalArray(:, 1, :));
    
    numSubregions = size(signalArray, 2);

    if numSubregions == 2
        fPil = squeeze(signalArray(:, 2, :));
    elseif numSubregions > 2
        fPil = squeeze( mean(signalArray(:, 2:end, :), 2));
    end
    
    % Calculate delta f over f.
    f0_Roi = prctile(fRoi, params.baseline, 1);
    f0_Npil = prctile(fPil, params.baseline, 1);

    dffRoi = (fRoi - f0_Roi) ./ f0_Roi;
    dffNpil = (fPil - f0_Npil) ./ f0_Npil;
    
    deltaDff = smoothdata(dffNpil, 'movmean', 10) - smoothdata(dffRoi, 'movmean', 10);
    
    % When is npil greater than roi? This will give a negative artifact in
    % the final dff for the rois. Will use difference as correction factor.
    
    ignore = deltaDff < 0; % ignore all cases where roi dff is bigger than npil dff
    deltaDff(ignore) = 0;
    
    if params.smoothSignals
        baselineCorrection = smoothdata(deltaDff);
        dff = smoothdata(dffRoi, 'movmean', 5) - smoothdata(dffNpil, 'movmean', 5) + baselineCorrection;
    else
        if ~isa(deltaDff, 'double') || ~isa(dffNpil, 'double')
            deltaDff = double(deltaDff); dffNpil = double(dffNpil);
        end
        baselineCorrection = sgolayfilt(deltaDff, 3, 11);
        dff = dffRoi - sgolayfilt(dffNpil, 3, 11) + baselineCorrection;
    end
