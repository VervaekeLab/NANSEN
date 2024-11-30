function S = removeConfigFields(S)

    TF = applify.mixin.UserSettings.isConfigField(fieldnames(S));

    names = fieldnames(S);
    fieldsToRemove = names(TF);

    S = rmfield(S, fieldsToRemove);
end
