function h = uiCreatePipeline()
    
    h = [];
    answer = inputdlg('Enter name for pipeline');
    if isempty(answer); return; end
    
    newName = answer{1};
    
    % Todo: specify which pipeline to work with.
    pipelineModel = nansen.pipeline.PipelineCatalog;
    
    pipelineItem = pipelineModel.getBlankItem();
    pipelineItem.PipelineName = newName;
    
    pipelineModel.insertItem(pipelineItem);
    
    pipelineStruct = pipelineModel.getItem(newName);
    
    % Get session methods catalog, make sure its refreshed and add options
    % alternatives for all session methods.
    smCatalog = nansen.config.SessionMethodsCatalog;
    smCatalog.refresh()
    smCatalog.addOptionsAlternative()
    
    h = nansen.pipeline.PipelineBuilderUI(pipelineStruct, smCatalog);

    if ~nargout
        clear h
    end
end


