function hApp = structeditor(varargin)
%STRUCTEDITOR Open an instance of the structeditor app
%   Structeditor is an app for viewing and editing fields of a struct
%
%   For more detailed information:
%   See also structeditor.App

    if nargin == 0
        hApp = structeditor.App();
    else
        hApp = structeditor.App(varargin{:});
    end
    
    if ~nargout
        clear hApp
    end

end