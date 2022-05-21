function stats = imageprops(roiImageArray, roiArray, varargin)
%imageprops Measure properties of roi images
%
%   stats = imageprops(dff) Returns struct array with different 
%   (statistical) measurements from a set of roi images.
%
%   INPUT:
%       dff : matrix of dff (numSamples x numRois)
%   
%   OUTPUT: stats is a struct containing the following fields:
%       RoiSalience      : Does roi stand out against background? 
%       RoiEdgyness      : Sum of gradient along roi boundary.
%       MeanImageSimilarity : How similar is the roi activity weighted
%                             image to the average image of all rois (number between 0 and 1 where 1 is most similar)
%       CorrelationSimilarity : How similar is the roi correlation image
%                              image to the average correlation image of all rois (number between 0 and 1 where 1 is most similar)
%
%   Each field values is a column vector with one row per roi.

    % Make sure inputs are valid
    narginchk(1,3)

    params = struct();
    params.Properties = 'all';
    
    params = utility.parsenvpairs(params, 1, varargin{:});
    getAll = ischar(params.Properties) && strcmp(params.Properties, 'all');
    get = @(name) any( strcmp(params.Properties, name) ); %getfcn
    
    [imageHeight, imageWidth, numRois] = size(roiImageArray);
    
    
    % Initialize output
    stats = struct;

    if getAll || get('RoiSalience')
        salience = nansen.twophoton.roi.stats.roiSalience(roiArray, ...
            roiImageArray.Top99thPercentile);
        stats.RoiSalience = salience;
        
        % Todo: This should be improved for soma with a dark nucleus!
        
    end
    
    if getAll || get('RoiEdgyness')

    end
    
    if getAll || get('MeanImageSimilarity')
        IM = roiImageArray.ActivityWeightedMean;
        similarity = nansen.twophoton.roi.stats.templateSimilarity(IM);
        stats.MeanImageSimilarity = similarity;
    end
    
    if getAll || get('CorrelationSimilarity')
        IM = roiImageArray.LocalCorrelation;
        similarity = nansen.twophoton.roi.stats.templateSimilarity(IM);
        stats.CorrelationSimilarity = similarity;
    end
    

end

