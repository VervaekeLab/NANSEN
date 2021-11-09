classdef RoiClassifier < uim.applify.AppPlugin
    
    
    properties (Constant, Hidden = true) % Inherited from applify.mixin.UserSettings via AppPlugin
        USE_DEFAULT_SETTINGS = false
        DEFAULT_SETTINGS = imviewer.plugin.RoiManager.getDefaultSettings()
    end
    
    properties (Constant) % Inherited from uim.applify.AppPlugin
        Name = 'Roimanager'
    end
    
    
    properties
        PrimaryAppName = 'Imviewer';
    end
    
    
    properties
        ClassifierApp
    end
    
    
    
    methods
        
        function obj = RoiClassifier(imviewerApp)
        %openRoiClassifier Open roiClassifier on request from imviewer

            obj@uim.applify.AppPlugin(imviewerApp)
            
            
            % Find roimanager handle
            success=false;
            if any( contains({imviewerApp.plugins.pluginName}, 'flufinder') )
                IND = contains({imviewerApp.plugins.pluginName}, 'flufinder');

                h = imviewerApp.plugins(IND).pluginHandle;

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
                    roiclassifier.roiClassifier(h.roiGroup, 'tileUnits', 'scaled')
                    success = true;
                end

            end

            if ~success
                imviewerApp.displayMessage('Error: No rois are present')
            end


        end
        
        function delete(obj)
            
        end
        
    end
    
    
    methods 
        
    end

end


