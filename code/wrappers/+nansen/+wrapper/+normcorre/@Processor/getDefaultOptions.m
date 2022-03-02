function options = getDefaultOptions()
%GETDEFAULTOPTIONS Summary of this function goes here

    S = nansen.wrapper.normcorre.presets.Default;
    options = S.Options;
    
    %className = mfilename('class');
    className = 'nansen.wrapper.normcorre.Processor';
    superOptions = nansen.mixin.HasOptions.getSuperClassOptions(className);
    options = nansen.mixin.HasOptions.combineOptions(options, superOptions{:});

end

