function options = getDefaultOptions()
%GETDEFAULTOPTIONS Summary of this function goes here

    S = nansen.wrapper.normcorre.Options.getDefaults;
    options = S;
    
    className = 'nansen.wrapper.normcorre.Processor';
    superOptions = nansen.mixin.HasOptions.getSuperClassOptions(className);
    options = nansen.mixin.HasOptions.combineOptions(options, superOptions{:});
end

