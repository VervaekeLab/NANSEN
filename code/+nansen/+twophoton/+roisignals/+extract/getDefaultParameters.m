function [P, V] = getDefaultParameters()
%getDefaultParameters Get default parameters for signal extraction
%
%   P = nansen.twophoton.roisignals.extract.getDefaultParameters() returns 
%       a struct (P) with default parameters for signal extraction
%
%   [P, V] = nansen.twophoton.roisignals.extract.getDefaultParameters() 
%       returns an additional struct (V) containing assertions for each 
%       parameter, for use with an input parser etc.
%
%   SELECTED PARAMETERS:
%   --------------------
%   roiInd : integer vector in range [1, numRois]
%       List of roi indices (use for extraction of signals from a subset
%       of rois). Default : extract signals from all rois.
%   imageMask : logical matrix (imageHeight x imageWidth)
%       Use for excluding regions of image. Include pixels that are true 
%       and exclude pixels that are false. Default : include all pixels
%   excludeRoiOverlaps : logical scalar
%       Exclude pixels where rois are overlapping. Default = true
%   createNeuropilMask : logical scalar
%       Create mask (and extract signals) for surrounding neuropil regions
%       Default = true
%   excludeRoiFromNeuropil : logical scalar
%       Exclude rois from neuropil regions. Default = true
%
%   Note: for full list of parameters, run function without output, i.e
%       nansen.twophoton.roisignals.extract.getDefaultParameters()


    % - - - - - - - - Specify parameters and default values - - - - - - - - 
    
    % Names                       Values (default)      Description
    P                           = struct();             %
    P.roiInd                    = 'all';                % A list of indices for rois to extract signals from. Default is to use all rois.
    P.imageMask                 = [];                   % Use for excluding regions in image. Logical mask which is false for pixels to ignore when extracting signals.
    P.pixelComputationMethod    = 'mean';               % NOTE: Alternatives not implemented yet.
    P.excludeRoiOverlaps        = true;                 % Exclude pixels where rois are overlapping when extracting signals
    P.createNeuropilMask        = true;                 % Extract signals for a neuropil region (roi neighborhood)
    P.excludeRoiFromNeuropil    = true;                 % Exclude pixels belonging to rois when determining neuropil regions
    P.neuropilExpansionFactor   = 4;                    % Factor that determines how large neuropil regions are relative to rois.
    P.cellNeuropilSeparation    = 0;                    % "Safe zone" between a roi and a nuropil region (in pixels)
    P.numNeuropilSlices         = 1;                    % Number of neuropil slices to split each neuropil reigon in. Default = 1
    P.maxNeuropilRadius         = 50;                   % Maximum radius of neuropil region.
    P.roiMaskFormat             = 'struct';             % Format to use when rois are prepared for signal extraction. Alternatives: 'sparse' | 'struct'. (Should be internal...)
    P.extractFcn                = [];                   % Function handle for function to use for extraction (If using different than inbuilt) (Should be internal..?)
    
    % - - - - - - - - - - Specify customization flags - - - - - - - - - - -
    P.roiInd_                   = 'internal';
    P.imageMask_                = 'internal';
    P.pixelComputationMethod_   = {'mean'};
    P.roiMaskFormat_            = 'internal';
    P.extractFcn_               = 'internal';
    
    % - - - - Specify validation/assertion test for each parameter - - - -
    
    V                           = struct();
    V.roiInd                    = @(x) assert(isempty(x) || (isvector(x) && all(x==round(x))), ...
                                    'Value must be a vector of integers'); 
    V.imageMask                 = @(x) assert(isempty(x) || (ismatrix(x) && islogical(x)), ...
                                    'Value must be a logical matrix');
    V.pixelComputationMethod    = @(x) assert(any(strcmp(x, {'mean', 'median'})), ...
                                    'Value must be ''mean'' or ''median''');  
    V.excludeRoiOverlaps        = @(x) assert( islogical(x) && isscalar(x), ...
                                    'Value must be a logical scalar' );
    V.createNeuropilMask        = @(x) assert( islogical(x) && isscalar(x), ...
                                    'Value must be a logical scalar' );
    V.excludeRoiFromNeuropil    = @(x) assert( islogical(x) && isscalar(x), ...
                                    'Value must be a logical scalar' );  
    V.neuropilExpansionFactor   = @(x) assert( isnumeric(x) && isscalar(x) && x > 0, ...
                                    'Value must be a scalar positive number' );
    V.cellNeuropilSeparation    = @(x) assert( isnumeric(x) && isscalar(x) && x >= 0 && round(x)==x, ...
                                    'Value must be a scalar, non-negative, integer number' );
    V.numNeuropilSlices         = @(x) assert( isnumeric(x) && isscalar(x) && x >= 0 && round(x)==x, ...
                                    'Value must be a scalar, non-negative, integer number' );
    V.maxNeuropilRadius         = @(x) assert( isnumeric(x) && isscalar(x) && x >= 0 && round(x)==x, ...
                                    'Value must be a scalar, non-negative, integer number' );
    V.roiMaskFormat             = @(x) assert(any(strcmp(x, {'sparse', 'struct'})), ...
                                    'Value must be ''sparse'' or ''struct''');
    V.extractFcn                = @(x) assert(isempty(x) || isa(x, 'function_handle'), ...
                                    'Value must be function handle');    
    
    % - - - - - Adapt output to how many outputs are requested - - - - - -
    
    if nargout == 0
        S = utility.convertParamsToStructArray(mfilename('fullpath'));
        T = struct2table(S);
        fprintf('\nSignal extraction default parameters and descriptions:\n\n')
        disp(T)
        
        clear P V
    elseif nargout == 1
        clear V
    end
    
end