function options = getOptions(imSize, roiSize)
    
    if nargin < 1; imSize = [512,512,1];end
    if nargin < 2; roiSize = 6; end

    d1 = imSize(1);                     % dimensions of dataset
    d2 = imSize(2);                     % dimensions of dataset
    T = imSize(3);                      % dimensions of dataset
    d = d1*d2;                        	% total number of pixels in one frame

    % Set parameters
    tau = roiSize;                     % std of gaussian kernel (size (radius) of neuron)
    p = 2;                             % order of autoregressive system (p = 0 no dynamics, p=1 just decay, p = 2, both rise and decay)
    merge_thr = 0.8;                   % merging threshold

    % Set options
    options = CNMFSetParms(...
        'd1',d1,'d2',d2,...                         % dimensions of datasets
        'search_method','dilate', ...
        'dist',3,...                                % search locations when updating spatial components
        'deconv_method','constrained_foopsi',...    % activity deconvolution method
        'temporal_iter',2,...                       % number of block-coordinate descent steps
        'fudge_factor',0.98,...                     % bias correction for AR coefficients
        'merge_thr',merge_thr,...                   % merging threshold
        'gSig',tau ...                              % half size of neurons to be found (default: [5,5])
        );
    
    options.d = d;
    options.nFrames = T;
    
end
