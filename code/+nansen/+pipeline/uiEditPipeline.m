function h = uiEditPipeline(pipelineName)
%uiEditPipeline Open the pipeline builder for editing given pipeline

    pipelineModel = nansen.pipeline.PipelineCatalog();

    if nargin < 1
        names = pipelineModel.PipelineNames;
        selection = listdlg('ListString', names, 'SelectionMode','single', 'PromptString', 'Select a pipeline to edit.');
        if isempty(selection); return; end
        pipelineName = names{selection};
    end

    pipelineStruct = pipelineModel.getItem(pipelineName);
    
    % Get session methods catalog, make sure its refreshed and add options
    % alternatives for all session methods.
    smCatalog = nansen.config.SessionMethodsCatalog;
    smCatalog.refresh()
    smCatalog.addOptionsAlternative()
    
    %smCatalog.verifyPipeline(pipelineStruct) %Todo.
    
    h = nansen.pipeline.PipelineBuilderUI(pipelineStruct, smCatalog);
    
    if ~nargout
        clear h
    end
end
