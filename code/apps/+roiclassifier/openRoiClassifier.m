function openRoiClassifier(imviewerRef)
%openRoiClassifier Open roiClassifier on request from imviewer
    
    % Find roimanager handle
    success=false;
    if any( contains({imviewerRef.plugins.pluginName}, 'flufinder') )
        IND = contains({imviewerRef.plugins.pluginName}, 'flufinder');
        
        h = imviewerRef.plugins(IND).pluginHandle;
        
        % Get roi group
        roiGroup = h.roiGroup;
        
        %TODO: Make sure roigroup has images and stat, otherwise generate
        % it
        
        
        tf = roiGroup.validateForClassification();
        if isempty(roiGroup.roiImages) || isempty(roiGroup.roiStats)
            % get roi images/stats
            error('Images and stats are missing')
        end
        
        
        if roiGroup.roiCount > 0
            % Initialize roi classifier
            roiClassifier(h.roiGroup, 'tileUnits', 'scaled')
            success = true;
        end

    end
    
    if ~success
        imviewerRef.displayMessage('Error: No rois are present')
    end
    

end