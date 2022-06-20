function BW = binarizeSomaStack(imageArray, varargin)
%binarizeSomaStack Binarize image array with neruonal somata
%
%   Note: This method is ad hoc, designed by trial and error.
    
    % Todo:
    %   [ ] option for getting binarization threshold for each frame individually. 


    % Validate inputs
    assert(ismember( ndims(imageArray), [2,3]), 'Image array must be 2D or 3D')
    
    % Define default parameters and parse name value pairs
    params = struct();
    params.RoiDiameter = 12;
    params.PrctileForBinarization = 92;
    %params.ThresholdMethod = 'all'; % 'single frame', 'all frames'

    
    params = utility.parsenvpairs(params, [], varargin{:});
    
    
    global waitbar
    useWaitbar = ~isempty(waitbar); 
    
    if useWaitbar; waitbar(0, 'Please wait while binarizing images'); end
    
    % Allocate array for output
    BW = false(size(imageArray));
    
    % These are optimized based on rois with diameter of 12 pixels
    nhoodSmall = strel('disk', round(params.RoiDiameter/6) );
    nhoodLarge = strel('disk', round(params.RoiDiameter/3) );

    % Get pixel value for bw threshold 
    T = prctile(imageArray(:), params.PrctileForBinarization);

    % Loop through frames and binarize each frame individually.
    for i = 1:size(imageArray, 3)
        
% %         T = adaptthresh(dffStack(:,:,i), 0.5); %'ForegroundPolarity', 'bright'
% %         BW(:,:,i) = imbinarize(dffStack(:,:,i), T);
% % 
% %         pixelData = dffStack(:,:,i);
% %         T = prctile(pixelData(:), params.PercentileThreshold);

        BW(:,:,i) = imbinarize(imageArray(:,:,i), T);
        BW(:,:,i) = imfill(BW(:,:,i),'holes');

% %         BW(:,:,i) = bwareaopen(BW(:,:,i), 20);
% %         BW(:,:,i) = imclose(BW(:,:,i), nhoodSmall);
    
        BW(:,:,i) = imopen(BW(:,:,i), nhoodSmall);

        BW(:,:,i) = imdilate(BW(:,:,i), nhoodLarge);
        BW(:,:,i) = imclearborder(BW(:,:,i));
        BW(:,:,i) = imerode(BW(:,:,i), nhoodLarge);
        BW(:,:,i) = imopen(BW(:,:,i), nhoodLarge);
    
        
        if useWaitbar && mod(i, 50) == 0
            waitbar(i/size(imageArray, 3))
        end
        
    end
end

