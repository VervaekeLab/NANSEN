function varargout = gauss3d(imArray, varargin)
% wrapper for imgaussfilt...

    param = struct();
    param.sigma = [1,1,1];
    %param.sigma_ = struct('type', 'slider', 'args', {{'Min', 0.5, 'Max', 10, 'nTicks', 19}});
    
    if nargin == 0
        varargout = {param}; return
    end
    
    param = utility.parsenvpairs(param, [], varargin);

    % Todo: multichannel..
    
    imArray = imgaussfilt3(imArray, param.sigma);
        
    varargout = {imArray};

end