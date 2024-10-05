function imArray = gauss2d(imArray, n, varargin)
%gauss2d Wrapper for using imgaussfilt on a 3D array

    % Do we need loop at all?
    
    if nargin < 2 || isempty(n)
        n = 0.5;
    end

    nFrames = size(imArray, 3);

    for i = 1:nFrames
        imArray(:,:,i) = imgaussfilt(imArray(:,:,i), n, varargin{:});
    end
end
