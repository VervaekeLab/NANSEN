function [dec, den, opt] = deconvolveDff(dff, varargin)

    [P, V] = nansen.twophoton.roisignals.getDeconvolutionParameters();
    P.deconvolutionMethod = 'caiman';
    
    params = utility.parsenvpairs(P, V, varargin{:});
    
    deconvPackage = 'nansen.twophoton.roisignals.process.deconvolve';
    deconvFunction = str2func( strjoin({deconvPackage, params.deconvolutionMethod}, '.') );
    
    % dff must be nRois x nSamples for deconvolution method...
    wasTransposed = false;
    if size(dff, 1) > size(dff, 2)
        dff = transpose(dff);
        wasTransposed = true;
    end
    
    [dec, den, opt] = deconvFunction(dff, params);
    
    if wasTransposed
        dec = transpose(dec);
        den = transpose(den);
    end
end
