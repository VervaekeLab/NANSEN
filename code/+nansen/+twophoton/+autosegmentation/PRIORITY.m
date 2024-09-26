% Establish a system for plugin tools




% Three things:
% 
% 1. How to define and retrieve options. Should be simple.
%    For each of these cases:
%         a) options for an external toolbox method. requires conversion
%         b) options for a function (returning options when called without inputs)
%         c) options for session methods
%         d) Get options / presets in ONE command with minimal input, i.e
%             not the whole package link
%         
%
%    What to do for suite2p/caiman etc where there are many methods, like
%    segmentation, refinement, signal extraction, deconvolution etc? 
%    I.e what's the hierarchy?
%
%       twophoton.autosegmentation.suite2p
%       twophoton.autosegmentation.cnmf
%       twophoton.deconvolution.suite2p
%       twophoton.deconvolution.cnmf
%
%   OR
%       twophoton.suite2p.autosegmentation
%       twophoton.suite2p.deconvolution
%       twophoton.cnmf.autosegmentation
%       twophoton.cnmf.deconvolution
%
%
% 2. How to organize code for a toolbox
%       a) When running from roimanager
%       b) When editing options connected to a viewer (i.e imviewer/signalviewer)
%       c) When running as a sessionMethod (On an image Stack)
%       d) Should onSettingsChanged be part of the options definition
%          class? Should there be a separate for imviewer plugins etc?



