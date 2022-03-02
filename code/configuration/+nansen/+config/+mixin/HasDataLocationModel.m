classdef HasDataLocationModel < handle
%HasDataLocationModel Mixin class for GUI that works on DataLocationModel
%
%   This class assigns the DataLocationModel to a property on creation and
%   provides callbacks for when changes are made to the DataLocationModel
    
    properties (Access = protected) % Unsure about access...
        DataLocationModel nansen.config.dloc.DataLocationModel
    end
    
    properties (Access = private)
        DataLocationAddedListener event.listener
        DataLocationModifiedListener event.listener
        DataLocationRemovedListener event.listener
    end
    
    methods
        function obj = HasDataLocationModel(varargin)
        %HasDataLocationModel Constructor
            
            if ~isempty(varargin)
                obj.DataLocationModel = varargin{1};
                obj.onDataLocationModelSet()
            else
                return
            end 

        end
        
        function delete(obj)
            obj.deleteListenersIfActive()
        end
    end
    
    methods 
        function set.DataLocationModel(obj, newValue)
            obj.DataLocationModel = newValue;
            obj.deleteListenersIfActive()
            obj.onDataLocationModelSet()
        end
    end
    
    methods (Access = protected)
        
        function deleteListenersIfActive(obj)
        %deleteListenersIfActive Delete listeners on DataLocationModel    
            
            isActive = @(el) ~isempty(el) && isvalid(el);
            
            if isActive(obj.DataLocationAddedListener)
                delete(obj.DataLocationAddedListener)
            end
            
            if isActive(obj.DataLocationModifiedListener)
                delete(obj.DataLocationModifiedListener)
            end
            
            if isActive(obj.DataLocationRemovedListener)
                delete(obj.DataLocationRemovedListener)
            end
            
            obj.DataLocationAddedListener = event.listener.empty;
            obj.DataLocationModifiedListener = event.listener.empty;
            obj.DataLocationRemovedListener = event.listener.empty;
            
        end
        
        function onDataLocationModelSet(obj)
        %onDataLocationModelSet Add listeners to DataLocationModel events
        
            obj.DataLocationAddedListener = listener(obj.DataLocationModel, ...
                'DataLocationAdded', @obj.onDataLocationAdded);
            
            obj.DataLocationModifiedListener = listener(obj.DataLocationModel, ...
                'DataLocationModified', @obj.onDataLocationModified);
            
            obj.DataLocationRemovedListener = listener(obj.DataLocationModel, ...
                'DataLocationRemoved', @obj.onDataLocationRemoved);
            
        end
        
    end
    
    methods (Access = protected)
        
        % Subclass may override
        function onDataLocationAdded(obj, ~, ~)
        %onDataLocationAdded Callback for DataLocationModel event
        %
        %   This method is inherited from the HasDataLocationModel 
        %   superclass and is triggered by the DataLocationAdded event on 
        %   the DataLocationModel object
        
        end
               
        % Subclass may override
        function onDataLocationModified(obj, ~, ~)
        %onDataLocationModified Callback for DataLocationModel event
        %
        %   This method is inherited from the HasDataLocationModel 
        %   superclass and is triggered by the DataLocationModified event 
        %   on the DataLocationModel object
            
        end
        
        % Subclass may override
        function onDataLocationRemoved(obj, ~, ~)
        %onDataLocationRemoved Callback for DataLocationModel event
        %
        %   This method is inherited from the HasDataLocationModel 
        %   superclass and is triggered by the DataLocationRemoved event on 
        %   the DataLocationModel object
            
        end
        
    end

end