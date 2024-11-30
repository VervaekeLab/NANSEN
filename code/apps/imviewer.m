function hApp = imviewer(varargin)
%IMVIEWER Open app for viewing and manipulating videos & image stacks
%
%   hApp = IMVIEWER() without any inputs opens a browser for locating tiff file or
%   avi files. Loads files in virtual mode, reading those frames that are
%   requested.
%
%   IMVIEWER(filepath) opens file specified by path.
%
%   IMVIEWER(varName) opens imviewer with a variable from the workspace,
%   i.e an an array containing image data.
%
%   IMVIEWER([]) opens an empty imviewer instance where images from files
%   or from another imviewer instance can be dropped.
%
%   For more detailed information:
%   See also imviewer.App

    if nargin == 0
        hApp = imviewer.App();
    else
        hApp = imviewer.App(varargin{:});
    end
    
    if ~nargout
        clear hApp
    end
end
