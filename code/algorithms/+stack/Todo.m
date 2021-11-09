% FrameCache: Update when currentChannel or currentPlane changes.

% FileAdapter Constructor. 
%   Video and tiff should open file connection before assigning properties
%   about size and class, but binary formats (raw) need to do it in the 
%   opposite order. Ad hoc fix is to open files in assignFilePaths in
%   video/tiff, but should find a better way.