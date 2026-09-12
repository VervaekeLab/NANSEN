function options = getDefaultOptions()
%GETDEFAULTOPTIONS Summary of this function goes here

    S = nansen.module.twophoton.integration.normcorre.Options.getDefaults;
    options = S;

    className = 'nansen.module.twophoton.integration.normcorre.Processor';
    superOptions = nansen.mixin.HasOptions.getSuperClassOptions(className);
    options = nansen.mixin.HasOptions.combineOptions(options, superOptions{:});
end
