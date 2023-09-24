function S = getDefaultTableVariableAttribute()
    
    S = struct(...
        'Name', '', ...
        'TableType', '', ...
        'IsCustom', false, ...
        'IsEditable', false, ...
        'HasUpdateFunction', false, ...
        'UpdateFunctionName', '', ...
        'HasRendererFunction', false, ...
        'RendererFunctionName', '', ...
        'HasOptions', false, ...
        'OptionsList', {{}} );
end