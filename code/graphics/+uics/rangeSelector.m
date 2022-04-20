classdef rangeSelector <  uim.handle & uiw.mixin.AssignPVPairs
    
    
    properties
        Parent
        Callback
        CallbackRefreshRate = inf
    end
    
  
    properties (Dependent)
        Low
        High
        
        Minimum
        Maximum
            
        Position
        Visible
        
    end
    
    properties (Access = private)
        Low_ = 0
        High_ = 100
        
        Minimum_ = 0
        Maximum_ = 100
        
        Position_ = [1,1,200,25]        
    end
    
    properties (Access = private)

        hPanel
        
        hRangeSlidebar
        hEditFieldLow
        hEditFieldHigh
        
        WindowMousePressListener
        
    end
        
    
    
    
    methods
        
        function obj = rangeSelector(varargin)
            
            % Check if first input is a valid container
             
            [h, varargin] = obj.lookForUiContainer(varargin{:});

            if isempty(h)
                obj.Parent = figure;
            else
                obj.Parent = h;
            end
            
            obj.assignPVPairs(varargin{:})
            
            
            obj.createPanel()
            obj.createRangebar()
            obj.createValueInputFields()
            
            obj.updateComponentPositions()
            
        end
        
        function delete(obj)
    
        end
        
    end
    
    methods
        function reset(obj)
            obj.Low_ = obj.Minimum;
            obj.High_ = obj.Maximum;
            obj.updateLowValueField(obj.Low_)
            obj.updateHighValueField(obj.High_)
            
            obj.hRangeSlidebar.Low = obj.Low_;
            obj.hRangeSlidebar.High = obj.High_;
        end
        
    end
    
    methods % Set/get methods
        
        function set.Visible(obj, newValue)
            if ~isempty(obj.hPanel)
                obj.hPanel.Visible = newValue;
            end
        end
        
        function visible = get.Visible(obj)
            
            if isempty(obj.hPanel)
                visible = 'off';
            else
                visible = obj.hPanel.Visible;
            end
            
        end
                
        function pos = get.Position(obj)
            pos = obj.Position_;
        end
        function set.Position(obj, newValue)
            obj.Position_ = newValue;
            obj.onPositionChanged()
        end
        
        function min = get.Minimum(obj)
            min = obj.Minimum_;
        end
        function set.Minimum(obj, value)
            obj.Minimum_ = value;
            obj.onMinValuePropertySet()
        end
        
        
        function max = get.Maximum(obj)
            max = obj.Maximum_;
        end
        function set.Maximum(obj, value)
            obj.Maximum_ = value;
            obj.onMaxValuePropertySet()
        end
        
        
%         function set.Low(obj, newLow)
%             %newLow = obj.Min_;
%             assert(newLow >= obj.Min_, 'Slider lower value must be greater than slider lower limit')
%             assert(newLow <= obj.High_, 'Slider lower value must be smaller than slider upper value')
%             
%             if newLow ~= obj.Low_
%                 obj.Low_ = newLow;
%                 obj.onValueChanged()
%             end
%             
%         end
        
        function low = get.Low(obj)
            low = obj.Low_;
        end
        
%         function set.High(obj, newHigh)
%             assert(newHigh <= obj.Max_, 'Slider upper value must be smaller than slider upper limit')
%             assert(newHigh >= obj.Low_, 'Slider upper value must be larger than slider lower value')
%                         
%             if newHigh ~= obj.High_
%                 obj.High_ = newHigh;
%                 obj.onValueChanged()
%             end
%             
%         end
        
        function high = get.High(obj)
            high = obj.High_;
        end
        
    end
    
    methods (Access = private) % Component creation
        
        function createPanel(obj)
            
            obj.hPanel = uipanel(obj.Parent);
            obj.hPanel.BorderType = 'none';
            obj.hPanel.Units = 'pixels';
            obj.hPanel.Position = obj.Position;
            obj.hPanel.Tag = 'Range Selector Widget';
            uicc = uim.UIComponentCanvas(obj.hPanel);
        end
        
        function createRangebar(obj)
            
            uicc = getappdata(obj.hPanel,'UIComponentCanvas');

            obj.hRangeSlidebar = uim.widget.rangeslider(uicc, 'Min', obj.Minimum, ...
                'Max', obj.Maximum,  'Size', [120, 25], 'ShowLabel', false, ...
                'KnobEdgeColorActive', [0.5922    0.7804    0.9804], ...
                'CallbackRefreshRate', obj.CallbackRefreshRate);
            obj.hRangeSlidebar.Position(2) = 5;
            obj.hRangeSlidebar.Position(4) = 20;
            
            obj.hRangeSlidebar.updateLocation('manual')
            
            obj.hRangeSlidebar.Callback = @obj.onSliderValueChanged;
            obj.hRangeSlidebar.ValueChangingFcn = @obj.onSliderValueChanging;
            
        end
        
        function createValueInputFields(obj)
            
            obj.hEditFieldLow = uicontrol(obj.hPanel, 'style', 'edit');
            obj.hEditFieldLow.String = num2str(obj.Minimum);
            obj.hEditFieldLow.Position(2) = 5;
            obj.hEditFieldLow.Position(4) = 20;
            obj.hEditFieldLow.Callback = @obj.onLowValueInputChanged;
            obj.hEditFieldLow.UserData.PreviousValue = obj.hEditFieldLow.String;
            
            obj.hEditFieldHigh = uicontrol(obj.hPanel, 'style', 'edit');
            obj.hEditFieldHigh.String = num2str(obj.Maximum);
            obj.hEditFieldHigh.Position(2) = 5;
            obj.hEditFieldHigh.Position(4) = 20;
            obj.hEditFieldHigh.Callback = @obj.onHighValueInputChanged;
            obj.hEditFieldHigh.UserData.PreviousValue = obj.hEditFieldHigh.String;
        end

        function createWindowButtonListener(obj)
            
            obj.WindowMousePressListener = listener(ancestor(obj.hPanel, 'figure'), ...
                'WindowMousePress', @obj.onMousePressedInFigure );
            
        end
    end
    
    methods (Access = private) % Internal component callbacks
            
        function onMousePressedInFigure(obj, src, evt)
            
            % The purpose of this callback is to hide the control if the
            % mouse is pressed outside of it. not perfect, since the
            % callback is not invoked when mouse is pressed on
            % uicontrols...
            
            point = src.CurrentPoint;
            %point = point - src.Position(1:2);
            position = getpixelposition(obj.hPanel, true);
            
% %             % Press outside this widget
% %             if point(1)<position(1) || point(1) > sum( position([1,3]) )
% %                 if point(2)<position(2) || point(2) > sum( position([2,4]) )
% %                     obj.AllowSetInvisible = true;
% %                     obj.Visible = 'off';
% %                 end
% %             end
            
        end
        
        function onPositionChanged(obj)
            
            if ~isempty(obj.hPanel)
                obj.hPanel.Position = obj.Position_;
                obj.updateComponentPositions();
            end
            
        end
        
        function onSliderValueChanging(obj, src, evt)
            obj.updateLowValueField(src.Low)
            obj.updateHighValueField(src.High)
            
            obj.Low_ = src.Low;
            obj.High_ = src.High;
        end
        
        function onSliderValueChanged(obj, src, evt)
            obj.updateLowValueField(src.Low)
            obj.updateHighValueField(src.High)
            
            obj.Low_ = src.Low;
            obj.High_ = src.High;
            
            if ~isempty(obj.Callback)
                obj.Callback(obj, evt)
            end
            
        end
        
        function onMaxValuePropertySet(obj)
            %obj.updateHighValueField(obj.Maximum)
            obj.hRangeSlidebar.Max = obj.Maximum;
            
        end
        
        function onMinValuePropertySet(obj)
            %obj.updateLowValueField(obj.Minimum)
            obj.hRangeSlidebar.Max = obj.Minimum;
            
        end
        
        
        function onHighValueInputChanged(obj, src, evt)
            
            val = str2double( src.String );
            
            if val > obj.Low && val <= obj.Maximum
                obj.hRangeSlidebar.High = val;
                obj.hEditFieldHigh.UserData.PreviousValue = src.String;
            else
                src.String = obj.hEditFieldHigh.UserData.PreviousValue;
            end
        end
        
        function onLowValueInputChanged(obj, src, evt)
    
            val = str2double( src.String );
            
            if val >= obj.Minimum && val < obj.High
                obj.hRangeSlidebar.Low = val;
                obj.hEditFieldLow.UserData.PreviousValue = src.String;
            else
                src.String = obj.hEditFieldLow.UserData.PreviousValue;
            end
                        
        end
    end
    
    methods (Access = private) % Component update

        function updateComponentPositions(obj)
            
            import uim.utility.layout.subdividePosition
            
            containerpos = getpixelposition(obj.hPanel);
            w = containerpos(3) - 10;
            
            [x, w] = subdividePosition(5, w, [25, 1, 25], 15);
            
            obj.hEditFieldLow.Position([1,3]) = [x(1), w(1)];
            obj.hRangeSlidebar.Position([1,3]) = [x(2), w(2)];
            obj.hEditFieldHigh.Position([1,3]) = [x(3), w(3)];
            
            obj.hRangeSlidebar.updateSize()
            obj.hRangeSlidebar.updateLocation()
            
        end
        
        function updateLowValueField(obj, newValue)
            obj.hEditFieldLow.String = num2str( round( newValue ) ) ;
            obj.hEditFieldHigh.UserData.PreviousValue = obj.hEditFieldLow.String; 
        end
        
        function updateHighValueField(obj, newValue)
            obj.hEditFieldHigh.String = num2str( round( newValue ) );
            obj.hEditFieldHigh.UserData.PreviousValue = obj.hEditFieldHigh.String;
        end
        
    end
    
    methods (Static)
        function [h, remVarargin] = lookForUiContainer(varargin)
            
           if isa(varargin{1}, 'matlab.ui.Figure') || ...
                isa(varargin{1}, 'matlab.ui.container.Panel')|| ...
                    isa(varargin{1}, 'matlab.ui.container.Tab')
                h = varargin{1};
                remVarargin = varargin(2:end);
           else
               h = [];
               remVarargin = varargin;
           end
           
        end
    end

end