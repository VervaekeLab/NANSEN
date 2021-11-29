classdef RoiClassifier < applify.mixin.AppPlugin
    
    
    properties (Constant, Hidden = true) % Inherited from applify.mixin.UserSettings via AppPlugin
        USE_DEFAULT_SETTINGS = false
        DEFAULT_SETTINGS = imviewer.plugin.RoiClassifier.getDefaultSettings() % Todo... This is classifier settings.I guess these should be settings relevant for connecting the two apps...
    end
    
    properties (Constant) % Inherited from uim.applify.AppPlugin
        Name = 'Roiclassifier'
    end
    
    
    properties
        PrimaryAppName = 'Imviewer';
    end
    
    
    properties
        ClassifierApp
    end
    
    methods (Static)
        S = getDefaultSettings()
    end
    
    methods
        
        function obj = RoiClassifier(imviewerApp)
        %openRoiClassifier Open roiClassifier on request from imviewer

            obj@applify.mixin.AppPlugin(imviewerApp)
            
            % Find roimanager handle
            success=false;
            
            if any( contains({imviewerApp.Plugins.Name}, 'Roimanager') )
                IND = contains({imviewerApp.Plugins.Name}, 'Roimanager');

                h = imviewerApp.Plugins(IND);

                
                % Todo: move to on plugin activated???
                % Get roi group
                roiGroup = h.roiGroup;

                %TODO: Make sure roigroup has images and stat, otherwise generate
                % it

                if isempty(roiGroup.roiImages) || isempty(roiGroup.roiStats)

                    % get roi images/stats
                    
                    roiArray = obj.roiGroup.roiArray;

                    % % Get image stack and rois. Cancel if there are no rois
                    imageData = imviewerApp.ImageStack.getFrameSet('all');
                    
                    imviewerApp.displayMessage('Please wait. Creating thumbnail images of rois and calculating statistics. This might take a minute')

                    imageTypes = {'enhanced average', 'peak dff', 'correlation', 'enhanced correlation'};
                    [roiImages, roiStats] = roimanager.gatherRoiData(imageData, ...
                        roiArray, 'ImageTypes', imageTypes);

                    obj.roiGroup.roiImages = roiImages;
                    obj.roiGroup.roiStats = roiStats;
                    
                    obj.clearMessage();
                        
                    
                end

                tf = roiGroup.validateForClassification();
                
                if roiGroup.roiCount > 0 && tf
                    % Initialize roi classifier
                    hClsf = roiclassifier.App(roiGroup, 'tileUnits', 'scaled');
                    obj.ClassifierApp = hClsf;
                    
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
    
    methods (Access = protected)
        
        function onSettingsChanged(obj, name, value)
            
        end
        
        function onPluginActivated(obj)
            % fprintf('roiclassifier plugin activated...')
            
        end
        
    end
    
    
    methods (Static)       
        function icon = getPluginIcon()
            
        end
    end

end


