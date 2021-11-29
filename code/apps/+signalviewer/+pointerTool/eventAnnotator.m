classdef eventAnnotator < uim.interface.abstractPointer
        
    % Behavior:
    %
    %   1. Double click a point to add? Or shift/ctrl click?
    %   2. Double click a point to edit?
    %       - Replace data point in plotted event vector with nan and use
    %         a separate handle for the point which is being edited.
    %       - Finish using enter and update event vector.
    %   3. Plot with marker and a vertical line
    %   4. Drag marker to move it.
    %   5. Mouse over effect when mouse moves close to a point?
    
    properties (Constant)
        exitMode = 'default';
    end
    
    properties
        TimeSeriesIndex = []
        XCoordinates = []
    end
    
    properties
        TimeSeriesViewer
        Axes
        
        EventVector
        EventVectorName

        xLimOrig
    end
    
    properties (Access = private)
        hEventVector
        hEditMarker
        MarkerColor
        MarkerType
        
        hRectangle
    end
    
    events
        EventModified
    end
    
    methods 
        function obj = eventAnnotator(hAxes)
            obj.hAxes = hAxes;
            obj.hFigure = ancestor(hAxes, 'figure');
            
            obj.xLimOrig = obj.hAxes.XLim;
        end
        
        function delete(obj)
            
        end
        
        function activate(obj)
            activate@uim.interface.abstractPointer(obj)
        end
        
        function deactivate(obj)
            deactivate@uim.interface.abstractPointer(obj)
            
            %deleteRectangle(obj)
            if ~isempty(obj.hRectangle)
                rcc = round( obj.hRectangle.Position );
                newCoords = rcc(1) + (1:rcc(3)) - 1;
               
                evtData = signalviewer.event.EventVectorChangedData(...
                    obj.TimeSeriesIndex, newCoords);
                
                obj.notify('EventModified', evtData)
                
                delete(obj.hRectangle)
                obj.hRectangle = [];
                
            end
            
            obj.isActive = false;
            
            obj.TimeSeriesIndex = [];
            obj.XCoordinates = [];
        end

        function setPointerSymbol(obj)
            %obj.hFigure.Pointer = 'arrow';
        end

    end

    methods % Public methods...
        
        function startEdit(obj, eventVectorData)
            
            if ~isempty(obj.hRectangle); return; end
            
            obj.TimeSeriesIndex = eventVectorData.TimeSeriesIndex;
            obj.XCoordinates = eventVectorData.XCoordinates;
            
            rccInit = [obj.XCoordinates(1), 0, numel(obj.XCoordinates), 1];
            
            h = drawrectangle(obj.hAxes, 'Position', rccInit);
            %h.Color = plotColor;
            h.DrawingArea = [obj.xLimOrig(1), 0, obj.xLimOrig(2), 1];
            
            addlistener(h, 'MovingROI', @obj.onRectanglePositionChanging);
            addlistener(h, 'ObjectBeingDestroyed', @(s,e) obj.deactivate);
            
            obj.hRectangle = h;
            obj.isActive = true;
        end
        
        function onRectanglePositionChanging(obj, src, evtData)
           obj.hRectangle.Position([2,4]) = [0,1];
        end
        function set.EventVectorName(obj, newName)
        
        end
        
    end
    
    methods (Access = public) % Methods for mouse interactive callbacks
                
        function onButtonDown(obj, src, event)
        end
        
        function onButtonMotion(obj, src, event)
        end

        function onButtonUp(obj, src, event)
        end
        
    end
    
    methods (Access = protected)
        
        function plotMarker(obj)
        end
        
        function updateMarker(obj)
        end

    end
    
    
end