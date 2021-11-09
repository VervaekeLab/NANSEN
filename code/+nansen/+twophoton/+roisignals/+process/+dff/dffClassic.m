function dff = dffClassic(signalArray, varargin)

%   INPUTS:
%       
%   signalArray : 3D array (numSamples x numSubregions x numRois)
%   varargin : Options as struct or name-value pairs.
%
%   OUTPUT:
%   dff : 2D (numSamples x numRois) 


    P = struct;
    P.baseline = 20;
    
    params = utility.parsenvpairs(P, [], varargin{:});
    
    fRoi = squeeze(signalArray(:, 1, :));

    fRoi0 = prctile(fRoi, params.baseline, 1);
    dff = (fRoi - fRoi0) ./ fRoi0;
    
end