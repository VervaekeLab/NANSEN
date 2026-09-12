function options = getDefaultOptions()
%GETDEFAULTOPTIONS Summary of this function goes here

    S = nansen.module.twophoton.autosegmentation.flufinder.Options.getDefaults;
    options = S;

    className = mfilename('class');
    superOptions = nansen.mixin.HasOptions.getSuperClassOptions(className);
    options = nansen.mixin.HasOptions.combineOptions(options, superOptions{:});
end
