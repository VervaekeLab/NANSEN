function BW = binarizeAxonStack(imageArray, varargin)
%binarizeAxonStack Binarize image array with neruonal axonal boutons
%
%   Note: This method is ad hoc, designed by trial and error.
    
 
    % Validate inputs
    assert(ndims(imageArray) == 3, 'Image array must be 3D')
    
    % Define default parameters and parse name value pairs
    params = struct();
    params.PrctileForBinarization = 95;
    params.RoiDiameter = 5;

    params = utility.parsenvpairs(params, [], varargin{:});

    global waitbar; useWaitbar = ~isempty(waitbar); 
    if useWaitbar; waitbar(0, 'Please wait while binarizing images'); end
    
    roiAreaPixels = pi .*  (params.RoiDiameter./2) .^ 2;
    minAreaPixels = round(roiAreaPixels ./ 4);
    
    
    T = prctile( imageArray(:), params.PrctileForBinarization );
    BW = false(size(imageArray));
    
    % Loop through frames, binarize and apply binary operations
    for i = 1:size(imageArray, 3)

        BW(:,:,i) = imbinarize(imageArray(:,:,i), T);

        BW(:,:,i) = imclearborder(BW(:,:,i));
        BW(:,:,i) = bwareaopen(BW(:,:,i), minAreaPixels);
        
        if useWaitbar && mod(i,50) == 0
            waitbar(i/size(imageArray, 3))
        end
    end

end
