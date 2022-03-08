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
            
            if any(isMatch)
                thisTaskListNew(jTask) = thisTaskListOld(isMatch);
            end

        end
        
        pipelineArray{i}.TaskList = thisTaskListNew;
        
    end
    
    
    if wasConvertedToCell
        pipelineArray = pipelineArray{1};
    end
    

end