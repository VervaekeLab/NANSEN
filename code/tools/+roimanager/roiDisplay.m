classdef roiDisplay < uim.handle
%roiDisplay Superclass implementing a display interface for a RoiGroup.
%
%   This class will listen to events on a RoiGroup object and trigger
%   callback methods that can be implemented by subclasses. Furthermore,
%   the class handles selection and visibility of rois in the roidisplay
%   and lets subclasses implement methods for adding and/or removing rois.
%
%
%   Methods that may be implemented by a subclass:
%
%       onRoiGroupChanged          : handle changes that should occur on 
%                                    the roi display if the one or more 
%                                    rois are modified
%
%       onRoiClassificationChanged : handle changes that should occur on
%                                    the roi display if classification of
%                                    one or more rois are changed
%
%       onRoiSelectionChanged      : handle changes on the roi display
%                                    when one or more rois are selected or
%                                    deselected
%
%       onVisibleRoisChanged       : handle changes on the roi display
%                                    when the visibility of one or more
%                                    rois are changed
%                                     
%       addRois                    : handle changes on the roi display 
%                                    when rois are added to RoiGroup
%
%       removeRois                 : handle changes on the roi display
%                                    when rois are removed from RoiGroup
%
%       onRoiGroupSet              : handle changes on the roi display
%                                    when a RoiGroup is set.
%                                   


%   TODO: 
%       [ ] selectRois should be a method of the roidisplay
%       [ ] hittest (or similar name) should be a method of the roi display
%       [ ] Should have a onRoisSelected method 




% Work in progress.
    
    properties
        % These properties should be gotten from an enum class... Also:
        % Should they be part of this class???
        classificationLabels = { 'Accepted', 'Rejected', 'Unresolved' }
        classificationColors = { [0.174, 0.697, 0.492], ...
                                 [0.920, 0.339, 0.378], ...
                                 [0.176, 0.374, 0.908] }

    end
    
    properties % Options
        % NB: RoiTable subclass already implements a property with this name.
        %SelectionMode = 'multiple' % 'single' | 'multiple' (Not implemented yet)
    end
    
    properties
        RoiGroup            % The handle of a roigroup object
    end
    
    properties (SetAccess = protected)
        SelectedRois        % Vector with indices of selected rois
        VisibleRois         % Vector with indices of visible rois
    end
    
    properties (Access = protected) % RoiGroup event listeners
        RoisChangedListener event.listener
        RoiSelectionChangedListener event.listener
        RoiClassificationChangedListener event.listener
        VisibleRoisChangedListener event.listener
    end
    
    methods (Access = protected) % RoiGroup event callbacks
        
        % These methods will be invoked when each of the corresponding
        % events of the roiGroup is triggered.
        
        function onRoiGroupChanged(obj, evtData)
            % Subclasses may override
        end
        
        function onRoiSelectionChanged(obj, evtData)
            % Subclasses may override
        end
        
        function onRoiClassificationChanged(obj, evtData)
            % Subclasses may override
        end
        
        function onVisibleRoisChanged(obj, evtData)
            % Subclasses may override
        end
    end
    
    
    methods % Todo: Should these be public?
        function addRois(obj)
            % Subclass should implement if subclass can add more rois to a
            % RoiGroup.
        end
        
        function removeRois(obj)
            % Subclass should implement if subclass can remove rois from a
            % RoiGroup.
        end
        
        function classifyRois(obj, classification, roiInd)
        %ClassifyRois Change classification state for selected rois
            if nargin < 3 
                roiInd = obj.SelectedRois;
            end
            
            newClass = repmat(classification, size(roiInd));
            
            obj.RoiGroup.setRoiClassification(roiInd, newClass)
        end
        
    end
    
    methods % Constructor
        
        function obj = roiDisplay(roiGroup)
        %roiDisplay Constructor for roi display
        
            if ~nargin; return; end
        
            obj.RoiGroup = roiGroup;

        end
        
        function delete(obj)
            obj.resetListeners()
        end

    end

    methods % Set/get
        
        function set.RoiGroup(obj, newValue)
            
            msg = 'RoiGroup must be a roimanager.roiGroup object';
            assert( isa(newValue, 'roimanager.roiGroup'), ...
                'RoiDisplay:InvalidPropertyValue', msg )
            
            obj.resetListeners()
            obj.RoiGroup = newValue;
            obj.createListeners()
            
            obj.onRoiGroupSet()
            
        end
        
        function set.SelectedRois(obj, newValue)
            
            % Make sure the selected indices is a row vector.
            if iscolumn(newValue)
                newValue = transpose(newValue);
            end
            
            newValue = unique(newValue, 'stable');
            obj.SelectedRois = newValue;
            
        end
        
        function set.VisibleRois(obj, newValue)
            
            % Make sure the selected indices is a row vector.
            if iscolumn(newValue)
                newValue = transpose(newValue);
            end
            
            newValue = unique(newValue);
            obj.VisibleRois = newValue;
        end
        
    end
    
    methods (Access = protected)
        
        function onRoiGroupSet(obj)
            % Subclasses may implement
        end
        
        function updateVisibleRois(obj, roiInd, eventType)
                                
            visibleRois = obj.VisibleRois;

            switch eventType
                
                case 'initialize'
                    visibleRois = 1:numel(roiInd);
                
                case {'insert', 'append'}
                    for i = sort(roiInd, 'ascend')
                        visibleRois(visibleRois>=i) = visibleRois(visibleRois>=i) + 1;
                    end
                    visibleRois = [visibleRois, roiInd];

                case 'remove'
                    
                    for i = sort(roiInd, 'descend')
                        if ismember(i, visibleRois)
                            visibleRois(visibleRois==i)=[];
                        end
                        visibleRois(visibleRois>i) = visibleRois(visibleRois>i)-1;
                    end

            end
            
            obj.VisibleRois = visibleRois;

        end
        
    end
    
    methods (Access = private)
        
        function tf = hasListeners(obj)
            % All listeners should be set if one is set.
            tf = ~isempty(obj.RoisChangedListener);
        end
        
        function createListeners(obj)
        %createListeners Create listeners for events on RoiGroup    
        
            obj.RoisChangedListener = event.listener(obj.RoiGroup, ...
                'roisChanged', @(s, e) onRoiGroupChanged(obj, e));
            
            obj.RoiSelectionChangedListener = event.listener(obj.RoiGroup, ...
                'roiSelectionChanged', @(s, e) onRoiSelectionChanged(obj, e));
           
            obj.RoiClassificationChangedListener = event.listener(obj.RoiGroup, ...
                'classificationChanged', @(s, e) onRoiClassificationChanged(obj, e));
            
            obj.VisibleRoisChangedListener = event.listener(obj.RoiGroup, ...
                'VisibleRoisChanged', @(s, e) onVisibleRoisChanged(obj, e));
        end
        
        function resetListeners(obj)
            
            if ~obj.hasListeners; return; end
            
            delete( obj.RoisChangedListener )
            delete( obj.RoiSelectionChangedListener )
            delete( obj.RoiClassificationChangedListener )
            delete( obj.VisibleRoisChangedListener )
            
            obj.RoisChangedListener = event.listener.empty;
            obj.RoiSelectionChangedListener = event.listener.empty;
            obj.RoiClassificationChangedListener = event.listener.empty;
            obj.VisibleRoisChangedListener = event.listener.empty;
            
        end
        
    end
    
end