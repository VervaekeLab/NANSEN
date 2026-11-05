function dff = getDff(imArray, roiArray)
%getDff Get dff using methods from nansen with custom settings

    import nansen.module.twophoton.roisignals.extractF
    import nansen.module.twophoton.roisignals.computeDff

    signalOpts = struct('createNeuropilMask', true);
    signalArray = extractF(imArray, roiArray, signalOpts);

    dffOpts = struct('dffFcn', 'dffRoiMinusDffNpil');
    dff = computeDff(signalArray, dffOpts{:});
end
