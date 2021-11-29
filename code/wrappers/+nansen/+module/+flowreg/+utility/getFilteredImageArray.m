function C1 = getFilteredImageArray(Y, options, varargin)
%getFilteredImageArray Get 3D gaussian filtered grayscale images
%
%   Applies a 3D gaussian filter on the image array and converts
%   the output to a grayscale image array. 

    defaultParams = struct(...
        'sigmaOffset', [0,0,0], ...
        'normalizationRef', [] );

    params = utility.parsenvpairs(defaultParams, 1, varargin);

    % Filter input image array using 3d gaussian filter
    Y = imgaussfilt3_multichannel(Y, options, params.sigmaOffset);

    % Convert output to grayscale image array with values in [0,1]
    if strcmp(options.channel_normalization, 'separate')
        if ~isempty(params.normalizationRef)
            C1 = mat2gray_multichannel(Y, params.normalizationRef);
        else
            C1 = mat2gray_multichannel(Y);
        end
    else
        if ~isempty(params.normalizationRef)
            min_ref = double(min( params.normalizationRef(:) ));
            max_ref = double(max( params.normalizationRef(:) ));

            C1 = (Y - min_ref) / (max_ref - min_ref);
            % C1 = mat2gray(Y, [min_ref, max_ref]); Same result?
        else
            C1 = mat2gray(Y);
        end
    end

end
        