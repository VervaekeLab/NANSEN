function options = getDefaultOptions()
%GETDEFAULTOPTIONS Summary of this function goes here

    S = nansen.wrapper.extract.Options.getDefaults;
    options = S;
    
    className = mfilename('class');
    superOptions = nansen.mixin.HasOptions.getSuperClassOptions(className);
    superOptions = fliplr(superOptions);
    options = nansen.mixin.HasOptions.combineOptions(options, superOptions{:});

end

