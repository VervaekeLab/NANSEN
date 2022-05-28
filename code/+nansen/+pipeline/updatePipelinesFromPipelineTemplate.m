function pipelineArray = updatePipelinesFromPipelineTemplate(pipelineArray, pipelineTemplate)
%updatePipelinesFromPipelineTemplate Update an array of pipelines given a
%pipeline template.
%
%   pipelineArray = updatePipelinesFromPipelineTemplate(pipelineArray, pipelineTemplate)
%   
%   INPUTS:
%       pipelineArray : cell array of pipeline structs
%       pipelineTemplate : a pipeline template as retrieved from the 
%           getPipelineForSession method of the PipelineCatalog
    
    wasConvertedToCell = false;
    if ~isa(pipelineArray, 'cell') && numel(pipelineArray) == 1
        pipelineArray = {pipelineArray};
        wasConvertedToCell = true;
    end

    templateTaskList = pipelineTemplate.TaskList;

    for i = 1:numel(pipelineArray)
        
        if isempty( pipelineArray{i} )
            continue
        end
        
        if ~strcmp(pipelineArray{i}.Uuid, pipelineTemplate.Uuid)
            continue
        end
        
        thisTaskListNew = templateTaskList;
        thisTaskListOld = pipelineArray{i}.TaskList;
        
        for jTask = 1:numel(templateTaskList)
            
            thisTaskName = templateTaskList(jTask).TaskName;
            
            isMatch = strcmp({thisTaskListOld.TaskName}, thisTaskName);
            
            if sum(isMatch) == 1
                thisTaskListNew(jTask) = thisTaskListOld(isMatch);
            elseif sum(isMatch) > 1
                isMatch = find(isMatch, 1, 'first');
                thisTaskListNew(jTask) = thisTaskListOld(isMatch);
                warning('Duplicate method detected, task state might not be correctly updated')
            end

        end
        
        pipelineArray{i}.TaskList = thisTaskListNew;
        
    end
    
    
    if wasConvertedToCell
        pipelineArray = pipelineArray{1};
    end
    

end