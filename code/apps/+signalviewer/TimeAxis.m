classdef TimeAxis < handle
%TimeAxis Provide time axis for axes where data is plotted against samples
%
%   This class creates a hidden axes that mirrors many of the properties of
%   the axes where data is plotted, but where the xaxis can be set using a
%   datetime vector

    properties (Dependent)
        Visible     % State of visibility
        Color       % Color of axis line and labels
    end
    
    properties
        TimeVector  % Store time vector for the datetime ruler
        TimeStep    % Time step of the time vector
    end
    
    properties (Access = private)
        TimeAxisAxes    % Axes to hold datetime xaxis ruler
        ReferenceAxes   % Reference axes which the datetime ruler should mirror
        ContextMenu     % Store context menu items (for app that implements)
        ReferenceAxisXLimListener % Listener to update xaxis limits.
    end
    
    methods
        
        function obj = TimeAxis(timeVector, referenceAxes)
        %TimeAxis Create a time axis object...
        
            obj.ReferenceAxes = referenceAxes;
            obj.TimeVector = timeVector;
            
            obj.TimeStep = mean(diff(obj.TimeVector));
            
            % Create an axes with a datetime ruler
            obj.TimeAxisAxes = axes(obj.ReferenceAxes.Parent);
            obj.TimeAxisAxes.Units = 'pixels';
            obj.TimeAxisAxes.Position = obj.ReferenceAxes.Position;
            
            plot(obj.TimeAxisAxes, timeVector([1,end]), [nan, nan]);
            hold(obj.TimeAxisAxes, 'on');
            
            obj.TimeAxisAxes.PickableParts = 'none';
            obj.TimeAxisAxes.HitTest = 'off';
            obj.TimeAxisAxes.HandleVisibility = 'off';
            
            obj.TimeAxisAxes.YAxis.Visible = 'off';
            obj.TimeAxisAxes.XAxis.Visible = 'off';
            obj.TimeAxisAxes.Color = 'none';
            
            disableDefaultInteractivity(obj.TimeAxisAxes)
            obj.TimeAxisAxes.Interactions = [];
            obj.TimeAxisAxes.Toolbar = [];
            uistack(obj.TimeAxisAxes, 'bottom');
            
            obj.createContextMenuItems(obj.ReferenceAxes.UIContextMenu)
            
            obj.ReferenceAxisXLimListener = listener(obj.ReferenceAxes, ...
                'XLim', 'PostSet', @obj.onAxisLimitsChanged);
            
            obj.onAxisLimitsChanged()
        
        end
        
        function delete(obj)
            delete(obj.ReferenceAxisXLimListener)
            delete(obj.TimeAxisAxes)
        end
    end
    
    methods
        function set.Color(obj, newValue)
            obj.TimeAxisAxes.XAxis.Color = newValue;
        end
        
        function set.Visible(obj, newValue)
            obj.setTimeAxisVisibility(newValue)
        end
        
        function visibleState = get.Visible(obj)
            visibleState = obj.TimeAxisAxes.XAxis.Visible;
        end
    end
    
    methods
        
        function setTimeAxisVisibility(obj, timeAxisVisible)
        %setTimeAxisVisibility Set visibility of time axis.
            switch timeAxisVisible
                case 'on'
                    referenceAxisVisible = 'off';
                case 'off'
                    referenceAxisVisible = 'on';
            end
            
            if ~isempty(obj.ContextMenu) && isfield(obj.ContextMenu, 'ShowSample')
                obj.ContextMenu.ShowSample.Checked = referenceAxisVisible;
                obj.ContextMenu.ShowTime.Checked = timeAxisVisible;
            end
            
            obj.ReferenceAxes.XAxis.Visible = referenceAxisVisible;
            obj.TimeAxisAxes.XAxis.Visible = timeAxisVisible;
        end
        
        function createContextMenuItems(obj, hMenu)
            
            hMenuItem = uimenu(hMenu, 'Text', 'XAxis');
            
            hMenuSubItem = uimenu(hMenuItem, 'Text', 'Show Time');
            hMenuSubItem.Checked = 'off';
            hMenuSubItem.Callback = @obj.onMenuItemClicked;
            obj.ContextMenu.ShowTime = hMenuSubItem;
            
            hMenuSubItem = uimenu(hMenuItem, 'Text', 'Show Sample Number');
            hMenuSubItem.Callback = @obj.onMenuItemClicked;
            hMenuSubItem.Checked = 'on';
            obj.ContextMenu.ShowSample = hMenuSubItem;
            
        end
        
        function onMenuItemClicked(obj, src, evt)

            switch src.Text
                case 'Show Time'
                    newValue = 'on';
                case 'Show Sample Number'
                    newValue = 'off';

            end
            
            obj.setTimeAxisVisibility(newValue)
            
        end
        
        function onAxisLimitsChanged(obj, src, evt)
            sampleLimits = obj.ReferenceAxes.XLim;
            timeLimits = obj.TimeVector(1) + (sampleLimits - 1) .* obj.TimeStep;
            obj.TimeAxisAxes.XLim = timeLimits;
        end
    end
end
