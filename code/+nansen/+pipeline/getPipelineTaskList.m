function taskList = getPipelineTaskList(pipelineStruct, mode)
%GETPIPELINETASKLIST Get list of tasks from a pipeline struct
%
%   taskList = getPipelineTaskList(pipelineStruct, mode) returns a task
%   list from the provided pipelineStruct. mode can be 'Queuable' or
%   'Manual'. pipelineStruct must be a struct that have a field called
%   TaskList (TaskList is a structarray of task items).
%
%   The task list will be the uncompleted tasks in the list which is of
%   the specified type, i.e Manual or Queuable directly following any
%   completed tasks.
    
    if isempty(pipelineStruct); taskList = []; return; end
    
    assertMsg = 'The input pipelineStruct must have a field "TaskList"';
    assert(isfield(pipelineStruct, 'TaskList'), assertMsg)
    
    pipeTaskList = pipelineStruct.TaskList;
    
    idxFinished = find( [pipeTaskList.IsFinished] );
    
    idxManual =  find( [pipeTaskList.IsManual] );
    idxAuto = find( ~[pipeTaskList.IsManual] );

    idxManual = setdiff(idxManual, idxFinished);
    idxAuto = setdiff(idxAuto, idxFinished);

    % If no tasks of this type exists, assign number of tasks + 1
    if isempty(idxManual); idxManual = numel(pipeTaskList)+1; end
    if isempty(idxAuto); idxAuto = numel(pipeTaskList)+1; end

    % Determine which indices to use for selecting tasks.
    switch mode
        case 'Queuable'
            selectedIdx = idxAuto(idxAuto < min(idxManual) );
        case 'Manual'
            selectedIdx = idxManual(idxManual < min(idxAuto) );
    end

    taskList = pipeTaskList(selectedIdx);
    
end
