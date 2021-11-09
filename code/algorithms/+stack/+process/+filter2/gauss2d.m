function imArray = gauss2d(imArray, n, varargin)
% wrapper for imgaussfilt...

    % todo: implement varargin
    if ~isempty(varargin)
        warning('name value pairs not implemented')
    end

    if nargin < 2 || isempty(n)
        n = 0.5;
    end

    nFrames = size(imArray, 3);

    for i = 1:nFrames
        imArray(:,:,i) = imgaussfilt(imArray(:,:,i), n);
    end
    
    
end