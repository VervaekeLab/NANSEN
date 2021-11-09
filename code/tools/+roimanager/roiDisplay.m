classdef roiDisplay < uim.handle
%roiDisplay Abstract class for displaying rois and keeping them up to date
% if the underlying roi group is changed.
%
%
% should methods like grow/shrink move etc be part of this class? No???
%
% Work in progress. RoiMap & roiclassifier should inherit from this class...
    
    properties
        % These properties should be gotten from an enum class... Also:
        % Should they be part of this class???
        classificationColors = { [0.174, 0.697, 0.492], ...
                                 [0.920, 0.339, 0.378], ...
                                 [0.176, 0.374, 0.908] }

        classificationLabels = { 'Accepted', 'Rejected', 'Unclear' } 
    end
    
    
    properties
        roiGroup
    end
    
    
    properties (Access = protected)
        roisChangedListener
        roiSelectionChangedListener
        roiClassificationChangedListener
    end
    
    
    methods (Abstract, Access = protected)
        onRoiGroupChanged(obj, evtData)
        onRoiSelectionChanged(obj, evtData)
        onRoiClassificationChanged(obj, evtData)        
    end
    
    
    methods (Abstract)
        addRois(obj)
        removeRois(obj)
    end
    
    
    
    methods 
        function obj = roiDisplay(roiGroup)
            
            obj.roiGroup = roiGroup;
            
            obj.roisChangedListener = event.listener(obj.roiGroup, ...
                'roisChanged', @(s, e) onRoiGroupChanged(obj, e));
            
            obj.roiSelectionChangedListener = event.listener(obj.roiGroup, ...
                'roiSelectionChanged', @(s, e) onRoiSelectionChanged(obj, e));
           
            obj.roiClassificationChangedListener = event.listener(obj.roiGroup, ...
                'classificationChanged', @(s, e) onRoiClassificationChanged(obj, e));
            
        end

    end
    
end