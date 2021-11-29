function options = getDefaultOptions()
%GETDEFAULTOPTIONS Summary of this function goes here

    % Todo: This is the same as for normcorre, except for the sub-package
    % name. Can this be generalized further??

    S = nansen.module.flowreg.presets.Default;
    options = S.Options;
    
    className = mfilename('class');
    superOptions = nansen.mixin.HasOptions.getSuperClassOptions(className);
    options = nansen.mixin.HasOptions.combineOptions(options, superOptions{:});

end

