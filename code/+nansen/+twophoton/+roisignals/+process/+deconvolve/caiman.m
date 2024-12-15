function [cia_dec, cia_den, cia_opt] = caiman(dff, varargin)
%getCaImAnDeconvolvedDff Use CaImAn to deconvolve dff signal.
%
%   [cia_dec, cia_den, cia_opt] = caiman(dff, opt)
%
%   INPUTS:
%       dff : matrix (nRois x nTimePoints/nSamples)
%           matrix containing delta f over f signal for rois
%       opt : struct
%           struct with parameters for deconvolution
%
%   See also nansen.twophoton.roisignals.getDeconvolutionParameters

%TODO:
    % [ ] Use hardcoded timeconstants or optimize?
    % [ ] Individual time constants per roi
    % [ ] CVX dependency?
    
    [P, V] = nansen.twophoton.roisignals.getDeconvolutionParameters();
    
    % Parse potential parameters from input arguments
    opt = utility.parsenvpairs(P, V, varargin{:});
    
    % Preallocate arrays for output
    [cia_dec, cia_den] = deal( nan(size(dff)) );
    
    nRois = size(dff, 1);
    cia_opt = cell(nRois, 1);
    
    % todo...
    prevstr = [];
    starttime = tic;
    if isempty(gcp('nocreate'))
        dispProgress = true;
    else
        dispProgress = false;
    end
    
    if nRois < 5
        dispProgress = false;
    end
    
    % Convert time constants to framerate of data...
    opt.tauRise = opt.tauRise ./ 1000 .* opt.sampleRate;
    opt.tauDecay = opt.tauDecay ./ 1000 .* opt.sampleRate;

    % %Set time constants
    switch lower(opt.modelType)
        case 'ar1'
    %         g = nthroot(0.5, opt.tauDecay);
            g = exp( -1 / opt.tauDecay );
            opt.modelParams = g;
        case 'ar2'
            opt.modelParams = exp2ar( [opt.tauDecay, opt.tauRise] );
        case 'exp2'
            opt.modelParams = [opt.tauDecay, opt.tauRise];
        case 'kernel'
            error('Not implemented')
            
        otherwise
            if opt.sampleRate > 15
                opt.modelType = 'ar2';
            else
                opt.modelType = 'ar1';
            end
            opt.modelParams = [];
    end
    
    if opt.estimateTimeConstants
        opt.modelParams = [];
    end

    % Loop through all cells
for r = 1:nRois
    
    roiSignal = squeeze(dff(r, :));
        
    if any(isnan(roiSignal))
        cia_opt{r} = struct;
        continue
    end
    
    fr = opt.sampleRate;
    decay_time = 0.5;  % default value in CNMF: 0.4; Maybe this is for f?
    
% %     a = GetSn(roiSignal, [.25, .5]);
% %     b = GetSn(roiSignal, [0, .25]);
% %     fprintf('Signal: %.3f    Noise: %.3f \n', b, a)

    % Compute values for deconvolution
    spkmin = opt.spikeSnr * GetSn(roiSignal);   % GetSn = Noise Standard Deviation
    lam = choose_lambda(exp(-1/(fr*decay_time)), GetSn(roiSignal), opt.lambdaPr);
    
    switch opt.modelType
        case 'ar1'
            deconvolutionOptions = {'ar1', 'method', 'thresholded', ...
                 'lambda', lam, 'smin', spkmin, 'optimize_b', true, ...
                 'pars', opt.modelParams(1), ...
                 'optimize_pars', opt.optimizeTimeConstants };
                
        case 'ar2'
            deconvolutionOptions = {'ar2', 'method', 'thresholded', ...
                 'lambda', lam, 'smin', spkmin, 'optimize_b', true, ...
                 'pars', opt.modelParams, ...
                 'optimize_pars', opt.optimizeTimeConstants };
             
        case 'exp2'
            deconvolutionOptions = {'exp2', 'method', 'thresholded', ...
                 'lambda', lam, 'smin', spkmin, ...
                 'pars', opt.modelParams, ...
                 'optimize_pars', opt.optimizeTimeConstants };
             
        case 'autoar'
            deconvolutionOptions = {'ar2', 'method', 'thresholded', ...
                'lambda', lam, 'smin', spkmin, 'optimize_b', true, ...
                'optimize_pars', opt.optimizeTimeConstants};

    end
    
    [cc,spk,opts_oasis] = deconvolveCa(roiSignal, deconvolutionOptions{:});
                            
    baseline = opts_oasis.b;
    den_df = cc(:) + baseline;
    dec_df = spk(:);
    
    if dispProgress
        dt = toc(starttime);
        newstr = sprintf('Deconvolving signal for RoI %d/%d. Elapsed time: %02d:%02d', r, nRois, floor(dt/60), round(mod(dt, 60)));
        refreshdisp(newstr, prevstr, r)
        prevstr = newstr;
    end
    
    cia_dec(r, :) = dec_df;
    cia_den(r, :) = den_df;
    cia_opt{r} = opt;
    cia_opt{r}.pars = opts_oasis.pars;
    
end

if dispProgress
refreshdisp('', prevstr, r)
msg = sprintf('Signal deconvolution finished in %02d:%02d\n', floor(dt/60), round(mod(dt, 60)));
fprintf(msg)
end
end
                  
