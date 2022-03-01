function taskList = getPipelineTaskList(pipelineStruct, mode)
%GETPIPELINETASKLIST Get list of tasks from a pipeline struct
%
%   taskList = getPipelineTaskList(pipelineStruct, mode) returns a task
%   list from the provided pipelineStruct. mode can be 'Queuable' or 
%   'Manual'.
%
%   The task list will be the next uncompleted tasks in the list which is
%   of the specified type, i.e Manual or Queuable
    
    
    if isempty(pipelineStruct); taskList = []; return; end

    idxFinished = find( [pipelineStruct.IsFinished] );

    idxManual =  find( [pipelineStruct.IsManual] );
    idxAuto = find( ~[pipelineStruct.IsManual] );

    idxManual = setdiff(idxManual, idxFinished);
    idxAuto = setdiff(idxAuto, idxFinished);

    switch mode
        case 'Queuable'
            selectedIdx = idxAuto(idxAuto < min(idxManual) );
        case 'Manual'
            selectedIdx = idxManual(idxManual < min(idxAuto) );
    end

    taskList = pipelineStruct(selectedIdx);
    
end

