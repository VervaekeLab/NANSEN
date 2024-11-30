function hApp = structeditor(varargin)
%STRUCTEDITOR Open app to edit the values of a struct
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
