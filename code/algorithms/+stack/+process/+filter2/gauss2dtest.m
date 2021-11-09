function varargout = gauss2dtest(imArray, varargin)
% wrapper for imgaussfilt...


    param = struct();
    param.kernelSize = 1;
    param.kernelSize_ = struct('type', 'slider', 'args', {{'Min', 0.5, 'Max', 10, 'nTicks', 19}});
    
    if nargin == 0
        varargout = {param}; return
    end
    
    param = utility.parsenvpairs(param, [], varargin);
    n = param.kernelSize;
    

    nFrames = size(imArray, 3);

    for i = 1:nFrames
        imArray(:,:,i) = imgaussfilt(imArray(:,:,i), n);
    end
    
    varargout = {imArray};
    
end


