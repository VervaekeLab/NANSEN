function hApp = fovmanager(varargin)
%FOVMANAGER Open an instance of the fovmanager app
%   Fovmanager is an app for registering FoVs on a brain atlas
%
%   For more detailed information:
%   See also fovmanager.App

    if nargin == 0
        hApp = fovmanager.App();
    else
        hApp = fovmanager.App(varargin{:});
    end
    
    if ~nargout
        clear hApp
    end

end