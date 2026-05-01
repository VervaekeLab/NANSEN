classdef RoiClassifier < applify.mixin.AppBridgePlugin

    properties (Constant) % Inherited from uim.applify.AppPlugin
        Name = 'Roiclassifier'
    end

    properties
        ClassifierApp
    end

    properties (Access = private)
        ClassifierDestroyedListener event.listener
    end

    methods
        
        function obj = RoiClassifier(imviewerApp, varargin)
        %openRoiClassifier Open roiClassifier on request from imviewer

            obj@applify.mixin.AppBridgePlugin(imviewerApp, varargin{:})
            
            % Find roimanager handle
            success=false;
            
            if any( contains({imviewerApp.Plugins.Name}, 'Roimanager') )
                IND = contains({imviewerApp.Plugins.Name}, 'Roimanager');

                h = imviewerApp.Plugins(IND);
                
                % Todo: move to on plugin activated???
                % Get roi group
                roiGroup = h.RoiGroup;

                if numel(roiGroup) > 1
                    roiGroup = roimanager.CompositeRoiGroup(roiGroup);
                end

                %TODO: Make sure roigroup has images and stat, otherwise generate
                % it
                
                hasRoiData = roiGroup.validateForClassification();

                if ~hasRoiData

                    % get roi images/stats
                    
                    roiArray = roiGroup.roiArray;

                    % % Get image stack and rois. Cancel if there are no rois
                    
                    frameIdx = 1:min([5000, imviewerApp.ImageStack.NumTimepoints]);
                    
                    imviewerApp.displayMessage('Please wait. Loading image frames. This might take a minute')
                    imageData = imviewerApp.ImageStack.getFrameSet(frameIdx);
                    
                    imviewerApp.displayMessage('Please wait. Creating thumbnail images of rois and calculating statistics. This might take a minute')
                    
                    import('nansen.twophoton.roi.getRoiAppData')
                    [roiImages, roiStats] = getRoiAppData(imageData, roiArray);       % Imported function

% %                     imageTypes = {'enhancedAverage', 'peakDff', 'correlation', 'enhancedCorrelation'};
% %                     [roiImages, roiStats] = roimanager.gatherRoiData(imageData, ...
% %                         roiArray, 'ImageTypes', imageTypes);

                    roiArray = roiArray.setappdata('roiImages', roiImages);
                    roiArray = roiArray.setappdata('roiStats', roiStats);
                    %roiArray = roiArray.setappdata('roiClassification', zeros(1, numel(roiArray)));
                    
                    roiGroup.addRois(roiArray, [], 'replace')
                    
                    % Todo: set to appdata of roiarray...
% %                     roiGroup.roiImages = roiImages;
% %                     roiGroup.roiStats = roiStats;
% %                     roiGroup.roiClassification = zeros(1, roiGroup.roiCount);
                    
                    imviewerApp.clearMessage();
                    
                    hasRoiData = roiGroup.validateForClassification();

                end
                
                if roiGroup.roiCount > 0 && hasRoiData
                    % Initialize roi classifier
                    hClsf = roiclassifier.App(roiGroup, 'tileUnits', 'scaled');
                    obj.ClassifierApp = hClsf;
                    obj.ClassifierDestroyedListener = addlistener(hClsf, ...
                        'ObjectBeingDestroyed', @(s,e) obj.onClassifierAppDestroyed());
                    
                    success = true;
                end
            end

            if ~success
                imviewerApp.displayMessage('Error: No rois are present')
                delete(obj)
            end
        end
        
        function delete(obj)
            if ~isempty(obj.ClassifierDestroyedListener) && isvalid(obj.ClassifierDestroyedListener)
                delete(obj.ClassifierDestroyedListener)
            end
            if ~isempty(obj.ClassifierApp) && isvalid(obj.ClassifierApp)
                delete(obj.ClassifierApp)
            end
        end
    end
    
    methods
        
        function setFilePath(obj, filePath)
            if ~isempty(obj.ClassifierApp) && isvalid(obj.ClassifierApp)
                obj.ClassifierApp.dataFilePath = filePath;
            end
        end
    end

    methods (Access = private)

        function onClassifierAppDestroyed(obj)
            obj.ClassifierDestroyedListener = event.listener.empty;
            obj.ClassifierApp = [];
            if isvalid(obj)
                delete(obj)
            end
        end

    end
end
