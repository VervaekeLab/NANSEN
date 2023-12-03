function createFunctionFromTemplate(datalocation, identifierName, functionName)
%createFunctionFromTemplate -  Create a function for retrieving data
%identifiers from a path string in a DataLocationModel.
%
%   Supported identifiers:
%       subjectId
%       sessionId
%       experimentDate
%       experimentTime

    caseBlockTemplate = '        case ''%s'' %% <%s> [Do not remove]\n';

    caseBlocks = cell(1, numel(datalocation));
    for i = 1:numel(datalocation)
        caseBlocks{i} = sprintf(caseBlockTemplate, datalocation(i).Name, datalocation(i).Uuid);
    end
    caseBlocks = strjoin(caseBlocks, newline);

    rootDir = fileparts(mfilename('fullpath'));
    templatePath = fullfile(rootDir, 'templates', 'getDataIdTemplateFunction.mtemplate');
    functionTemplateStr = fileread(templatePath);
    
    functionTemplateStr = strrep(functionTemplateStr, '{{function_name}}', functionName);
    functionTemplateStr = strrep(functionTemplateStr, '{{identifier_name}}', identifierName);
    functionTemplateStr = strrep(functionTemplateStr, '{{case_blocks}}', caseBlocks);

    pm = nansen.ProjectManager();
    p = pm.getCurrentProject();
    fileName = sprintf('%s.m', functionName);
    filePath = fullfile(p.getModuleFolder(), '+datalocation', fileName);
    utility.filewrite(filePath, functionTemplateStr)
end
