function fillTemplate(templateString, templateVariables)
% fillTemplate - Fill in template variables in a template

    arguments
        templateString (1,1) string
        templateVariables (1,1) struct
    end

    templateVariableNames = fieldnames(templateVariables);
    
    for i = 1:numel(templateVariableNames)
        thisName = templateVariableNames{i};
        thisValue = templateVariables.(thisName);

        expression = sprintf('{{%s}}', thisName);

        replacement = ...
            nansen.internal.templating.getStringRepresentationForValue( ...
                thisValue );

        templateString = strrep(templateString, expression, replacement);
    end
end
