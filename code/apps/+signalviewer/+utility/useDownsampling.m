function tf = useDownsampling(numSamples, numTraces, dpPerPixel)
%useDownsampling Determine if downsampling should be used
%
%   tf = useDownsampling(numSamples, dpPerPixel) returns 1 (true)
%   if downsampling should be used for data with given number of
%   samples (numSamples) for the specified number of datapoints
%   per pixel (dpPerPixel). Otherwise returns false.

    % Ad hoc...
    tf = numSamples * numTraces > 1e6;
    
    % % Alternative, much stricter:
    % screenSize = get(0, 'ScreenSize');
    % screenResolution = screenSize(3:4);
    
    % tf =  obj.ScreenResolution(1) .* dpPerPixel < numSamples;

end
