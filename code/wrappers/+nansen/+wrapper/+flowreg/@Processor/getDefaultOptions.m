function options = getDefaultOptions()
%GETDEFAULTOPTIONS Summary of this function goes here

    % Todo: This is the same as for normcorre, except for the sub-package
    % name. Can this be generalized further??

    S = nansen.wrapper.flowreg.presets.Default;
    options = S.Options;
    
    %className = mfilename('class');
    className = 'nansen.wrapper.flowreg.Processor';
    superOptions = nansen.mixin.HasOptions.getSuperClassOptions(className);
    options = nansen.mixin.HasOptions.combineOptions(options, superOptions{:});

end

