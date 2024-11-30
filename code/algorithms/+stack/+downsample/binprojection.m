function imDataOut = binprojection(imDataIn, n, method, dim)
%
%
%   downsample image data along dim (3) by binning frames and computing a
%   projection of frames within each bin.
%
%   method

%   Todo:
%       [ ] Add support for filtering data before projection of bins

    if nargin < 4 || isempty(dim)
        dim = 3; % todo:
    else
        error('Dim not implemented yet')
    end
    
    if nargin < 3
        method = 'mean';
    end
    
    % Find size/resolution of data
    [h, w, ~] = size(imDataIn);

    % Bin data along selected dimension through reshaping.
    imDataIn = reshape(imDataIn, h, w, n, []);
            
    % Todo: Add filter operations before binning?
    
    % Calculate projections for each bin.
    switch method
        case 'min'
            imDataOut = squeeze( min(imDataIn, [], 3) );
        case 'max'
            imDataOut = squeeze( max(imDataIn, [], 3) );
        case 'mean'
            imDataOut = squeeze( mean(imDataIn, 3) );
            imDataOut = cast(imDataOut, 'like', imDataIn);
    end
end
