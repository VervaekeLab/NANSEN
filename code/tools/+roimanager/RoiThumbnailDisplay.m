classdef RoiThumbnailDisplay < handle & roimanager.roiDisplay
%RoiThumbnailDisplay Widget for displaying a roi image    

    properties
        Dashboard
        Parent
    end
    
    properties 
        ImageStack
        DisplayedRoiIdx
    end
    
    properties (Access = private)
        hAxes
        hRoiImage
        hRoiOutline
    end
    
    
    methods % Constructor
        
        function obj = RoiThumbnailDisplay(hParent, roiGroup)
            
            obj@roimanager.roiDisplay(roiGroup)
            
            obj.Parent = hParent;
            obj.createImageDisplay()

        end
        
    end
    
    methods (Access = private)
        
        function createImageDisplay(obj)
            
            % Create axes.
            obj.hAxes = axes('Parent', obj.Parent);
            obj.hAxes.Position = [0.05, 0.05, 0.9, 0.9];
            obj.hAxes.XTick = []; 
            obj.hAxes.YTick = [];
            obj.hAxes.Tag = 'Roi Thumbnail Display';
            obj.hAxes.Color = obj.Parent.BackgroundColor;
            obj.hAxes.Visible = 'off';
        end
        
        function updateImageDisplay(obj, roiObj)
            
            im = roiObj.enhancedImage;
            
            if all(im(:) == 0 )
                im = obj.createRoiImage(roiObj);
                if isempty(im); return; end
            end
            
            roiObj.enhancedImage = im;
            
            usFactor = 4; % Upsampling factor
            im = imresize(im, usFactor);
            
            if isempty(obj.hRoiImage) % First time initialization. Create image object
                obj.hRoiImage = imshow(im, [0, 255], 'Parent', obj.hAxes, 'InitialMagnification', 'fit');
%                 set(obj.himageCurrentRoi, 'ButtonDownFcn', @obj.mousePress)
               
                if ~ishold(obj.hAxes)  
                    hold(obj.hAxes, 'on') 
                end
                
            else
                set(obj.hRoiImage, 'cdata', im);
            end
            
            ul = roiObj.getUpperLeftCorner();
            roiBoundary = fliplr(roiObj.boundary{1});
            roiBoundary = (roiBoundary - ul + [1,1]) * usFactor;
            
            if isempty(obj.hRoiOutline)
                obj.hRoiOutline = plot(obj.hAxes, roiBoundary(:,1), roiBoundary(:,2), 'LineStyle', '-', 'Marker', 'None', 'LineWidth', 2);
            else
                set(obj.hRoiOutline, 'XData', roiBoundary(:,1), 'YData', roiBoundary(:,2))
            end
            
            imSize = size(im);
            
            % To avoid erroring
            clims = [min(im(:)), max(im(:))];
            if clims(2) <= clims(1)
                clims(2) = clims(1) + 1;
            end
            
            
            set(obj.hAxes, 'XLim', [1,imSize(2)]+0.5, ...
                           'YLim', [1,imSize(1)]+0.5, ...
                           'CLim', clims );
            
        end
        
        function im = createRoiImage(obj, roiObj)
            % Add average images of roi
            imArray = obj.ImageStack.getFrameSet('cache');
            
            if size(imArray, 3) < 100
                obj.Dashboard.displayMessage('Can not update roi image because there are not enough image frames in memory')
                im = [];
                return
            end
            
            f = nansen.twophoton.roisignals.extractF(imArray, roiObj);
            dff = nansen.twophoton.roisignals.computeDff(f, 'dffFcn', 'dffRoiMinusDffNpil');
            im = roimanager.autosegment.extractRoiImages(imArray, roiObj, dff'); 
        end
        
    end
    
    methods (Access = protected) % Inherited from roimanager.roiDisplay
        
        function onRoiGroupChanged(obj, evtData)
            
            % Update roiimage if roi groups is changing...
            
            % Take action for this EventType
            switch lower(evtData.eventType)

                case {'modify', 'reshape'}
                    
                    if isempty(evtData.roiIndices)
                        return
                    end
                    
                    roiIdx = evtData.roiIndices(end);
                    if isequal(roiIdx, obj.DisplayedRoiIdx)
                        roi = obj.roiGroup.roiArray(roiIdx);
                        obj.updateImageDisplay(roi)
                    end
                otherwise
                    % Do nothing....
            end
            
        end
        
        function onRoiSelectionChanged(obj, evtData)
            % Update image for roi
            
        
            if isempty(evtData.roiIndices)
                return
            end
            
            roiIdx = evtData.roiIndices(end);

            roi = obj.roiGroup.roiArray(roiIdx);
            obj.updateImageDisplay(roi)
            obj.DisplayedRoiIdx = roiIdx;
        end
        
        function onRoiClassificationChanged(obj, evtData)
            % Do nothing
        end
    end
    
    methods % Implement abstract methods from
        function addRois(~)
            % This class can not add rois
        end
        
        function removeRois(obj)
            % This class can not remove rois
        end
    end
    
    
end