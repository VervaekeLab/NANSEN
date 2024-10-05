function BW = binarizeImages(imArray, params)
%binarizeImages Binarize images for roi segmentation
%
%   BW = binarizeImages(imArray, params) returns a thresholded array given
%       a grayscale image array and a set of parameters.
%
%   INPUTS:
%       imArray : 3D array of images
%       params  : Struct of parameters for thresholding

    optsNames = {'RoiDiameter', 'PrctileForBinarization'};
    bwOpts = utility.struct.substruct(params, optsNames);
    
    switch lower( params.RoiType )
        case 'soma'
            BW = flufinder.binarize.binarizeSomaStack(imArray, bwOpts);
        case 'axonal bouton'
            BW = flufinder.binarize.binarizeAxonStack(imArray, bwOpts);
        otherwise
            error('Unsupported roi type.')
    end
end
