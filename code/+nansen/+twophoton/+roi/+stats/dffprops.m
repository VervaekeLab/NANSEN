function stats = dffprops(dff, varargin)
%dffprops Measure properties from an array of dff signals
%
%   stats = dffprops(dff) Returns struct array with different (statistical)
%   measurements from a dff roi signal array.
%
%   stats = dffprops(dff, name1, ...) Returns struct array with specified 
%   statistical measurements (Only specified fields are returned). 
%
%   INPUT:
%       dff : matrix of dff (numSamples x numRois)
%   
%   OUTPUT: stats is a struct containing the following fields:
%       DffPeak          : Peak dff of the roi time series. 
%       DffSkewness      : How assymmetric is the distribution of the signal
%                          around the mean? Positive values for right tail
%       DffSnr           : Signal to noise ratio of dff
%       DffSnrStd
%       DffActivityLevel : Percent of time signal is above baseline + noise
%   
%   Each field values is a column vector with one row per roi.

    % Make sure inputs are valid
    narginchk(1,3)
    validateattributes(dff, {'numeric'}, {'real','2d'}, mfilename, 'dff', 1);

    params = struct();
    params.Properties = 'all';
    
    params = utility.parsenvpairs(params, 1, varargin{:});
    getAll = ischar(params.Properties) && strcmp(params.Properties, 'all');
    get = @(name) any( strcmp(params.Properties, name) ); %getfcn
    
    [nSamples, nRois] = size(dff);
    
    
    % Initialize output
    stats = struct;

    if getAll || get('DffPeak')
        % Get peak DFF of all rois.
        peakDff = double( max(dff, [], 1) );
        stats.DffPeak = transpose( peakDff ); % Submit as column vec
    end
    
    if getAll || get('DffSnr') || get('DffActivityLevel') || get('DffStdSnr')
        noiseLevel =  zeros(nRois, 1);
        for i = 1:nRois
            if any(isnan(dff(:, i))) || any(isinf(dff(:, i)))
                noiseLevel(i) = nan;
            else
                noiseLevel(i) = real(GetSn( dff(:, i)) );
            end
        end
        stats.DffNoiseStd = noiseLevel; % Submit as column vec
    end
    
    if (getAll || get('DffSnr')) && exist('snr', 'file')
        % Get SNR of all Rois.
        signalToNoise = zeros(nRois, 1);
        for i = 1:nRois
            if ~isnan(noiseLevel(i))
                noiseVector = ones(nSamples, 1) * noiseLevel(i);
                signalToNoise(i) = snr(dff(:, i), noiseVector);
            else
                signalToNoise(i) = nan;
            end
        end
        stats.DffSnr = signalToNoise; % Submit as column vec
    end
    
    if (getAll || get('DffSnr')) && ~exist('snr', 'file') || get('DffStdSnr')
        % Get SNR of all Rois.
        signalToNoise = zeros(nRois, 1);
        for i = 1:nRois
            signalToNoise(i) = std(dff(:, i), 0) / noiseLevel(i);
        end
        stats.DffStdSnr = signalToNoise; % Submit as column vec
    end
    
    if getAll || get('DffActivityLevel')
        % Get fraction of time above noise level
        dffSmooth = smoothdata(dff, 1, 'movmean', 9); % Todo, set N
        baseline = median(dff, 1);
        isHigh = dffSmooth > baseline + transpose(noiseLevel);
        activityLevel = sum(isHigh, 1) ./ nSamples;
        stats.DffActivityLevel = transpose(activityLevel); % -> column vec
    end
    
    if getAll || get('DffSkewness')
        dffSkew = double( skewness(dff, 1, 1) );
        stats.DffSkewness = transpose(dffSkew); % submit as columnvec
    end
    
end


function sn = GetSn(Y, range_ff, method)
%% Estimate noise standard deviation

%% inputs:
%   Y: N X T matrix, fluorescence trace
%   range_ff : 1 x 2 vector, nonnegative, max value <= 0.5, range of frequency (x Nyquist rate) over which the spectrum is averaged
%   method: string, method of averaging: Mean, median, exponentiated mean of logvalues (default)

%% outputs:
%   sn: scalar, std of the noise

%% Authors: Pengcheng Zhou, Carnegie Mellon University, 2016
% adapted from the MATLAB implemention by Eftychios Pnevmatikakis and the
% Python implementation from Johannes Friedrich

%% References
% Pnevmatikakis E. et.al., Neuron 2016, Simultaneous Denoising, Deconvolution, and Demixing of Calcium Imaging Data

%% input arguments
if ~exist('range_ff', 'var') || isempty(range_ff)
    range_ff = [.25, .5];
end
if ~exist('method', 'var') || isempty(method)
    method = 'logmexp';
end
if any(size(Y)==1)
    Y = reshape(Y, [], 1);
else
    Y = Y';
end

%% estimate the noise
[psdx, ff] = pwelch(Y, [],[],[], 1);
indf = and(ff>=range_ff(1), ff<=range_ff(2));
switch method
    case 'mean'
        sn=sqrt(mean(psdx(indf, :)/2));
    case 'median'
        sn=sqrt(median(psdx(indf,:)/2));
    case 'logmexp'
        sn = sqrt(exp(mean(log(psdx(indf,:)/2))));    
    otherwise
        fprintf('wrong method! use logmexp instead.\n'); 
        sn = sqrt(exp(mean(log(psdx(indf,:)/2))));
end
sn = sn';
end