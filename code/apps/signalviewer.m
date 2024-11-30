function hApp = signalviewer(varargin)
%SIGNALVIEWER Open an instance of the signalviewer app
%   Signalviewer is an app for viewing and manipulating signal data
%
%   For more detailed information:
%   See also signalviewer.App

    if nargin == 0
        hApp = signalviewer.App();
    else
        hApp = signalviewer.App(varargin{:});
    end
    
    if ~nargout
        clear hApp
    end
end
