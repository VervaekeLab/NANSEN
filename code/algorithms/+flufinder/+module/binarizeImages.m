function BW = binarizeImages(imArray, params)
%binarizeImages Binarize images for roi segmentation
%
%   BW = binarizeImages(imArray, params) returns a thresholded array given
%       a grayscale image array and a set of parameters.
%
%   INPUTS: 
%       imArray : 3D array of images
%       params  : Struct of parameters for thresholding

    optsNames = {'RoiDiameter', 'BwThresholdPercentile'};
    bwOpts = utility.struct.substruct(params, optsNames);
    
    % Todo: Decide on parameter name
    params.RoiType = params.MorphologicalStructure;
    
    switch lower( params.RoiType )
        case 'soma'
            BW = flufinder.binarize.binarizeSomaStack(imArray, bwOpts);
        case 'axon'
            BW = flufinder.binarize.binarizeAxonStack(imArray, bwOpts);
        otherwise 
            error('Unsupported roi type.')
    end
    
end