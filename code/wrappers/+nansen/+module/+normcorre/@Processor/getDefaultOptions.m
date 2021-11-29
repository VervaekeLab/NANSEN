function options = getDefaultOptions()
%GETDEFAULTOPTIONS Summary of this function goes here

    S = nansen.module.normcorre.presets.Default;
    options = S.Options;
    
    className = mfilename('class');
    superOptions = nansen.mixin.HasOptions.getSuperClassOptions(className);
    options = nansen.mixin.HasOptions.combineOptions(options, superOptions{:});

end

