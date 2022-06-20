function pipelineArray = updatePipelinesFromPipelineTemplate(pipelineArray, pipelineTemplate)
%updatePipelinesFromPipelineTemplate Update an array of pipelines given a
%pipeline template.
%
%   pipelineArray = updatePipelinesFromPipelineTemplate(pipelineArray, pipelineTemplate)
%       update a list of pipeline items (from session objects) based on a
%       pipeline template. Useful if the pipeline template has been
%       modified.
%   
%   INPUTS:
%       pipelineArray : cell array of pipeline structs
%       pipelineTemplate : a pipeline template as retrieved from the 
%           getPipelineForSession method of the PipelineCatalog
    
    wasConvertedToCell = false; % Add pipeline item to cell array
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
        
        % Loop through tasks and update the task state for each task that
        % is still in the new pipeline.
        thisTaskListNew = templateTaskList;
        thisTaskListOld = pipelineArray{i}.TaskList;
        
        for jTask = 1:numel(templateTaskList)
            
            thisTaskName = templateTaskList(jTask).TaskName;
            
            isMatch = strcmp({thisTaskListOld.TaskName}, thisTaskName);
            
            if sum(isMatch) == 1
                oldTask = thisTaskListOld(isMatch);
            elseif sum(isMatch) > 1
                isMatch = find(isMatch, 1, 'first');
                oldTask = thisTaskListOld(isMatch);
                warning('Duplicate method detected, task state might not be correctly updated')
            end

            if any(isMatch) % Update task state
                thisTaskListNew(jTask).IsFinished = oldTask.IsFinished;
                thisTaskListNew(jTask).DateFinished = oldTask.DateFinished;
            end
        end
        
        pipelineArray{i}.TaskList = thisTaskListNew;
    end
    
    if wasConvertedToCell % If pipeline item was placed in a cell array 
        % before updating, extract if from the cell array before returning.
        pipelineArray = pipelineArray{1};
    end
end