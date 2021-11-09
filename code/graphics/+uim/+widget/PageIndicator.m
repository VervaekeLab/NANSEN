classdef PageIndicator < uim.abstract.virtualContainer & uim.mixin.assignProperties
    

    % Todo: generalize so that it can be used as tab header for tabgroups
    % Todo: subclass from uim.abstract.Container instead

    properties
       PageNames = {''}
       CurrentPage = 1;
       FontColor = 'k'
       FontSize = 12
       IndicatorSize = 10
       IndicatorColor = ones(1,3) * 0.5
       BarColor = 'k'
       Spacing = 8
       ChangePageFcn = [];
    end
   
    properties (Hidden, Access = private, Transient)
        hPageButtons = gobjects(0)
        hPageLabels = gobjects(0)
        hHBar = gobjects(0)
        hVBar = gobjects(0)
    end
   
    methods
        function obj = PageIndicator(hParent, pageNames, varargin)
            
            
            el = listener(hParent, 'SizeChanged', ...
                @obj.onParentContainerSizeChanged);
            obj.ParentContainerSizeChangedListener = el;
            
            obj.Parent = hParent;
            obj.Canvas = hParent;
            obj.hAxes = obj.Canvas.Axes;
            
            obj.parseInputs(varargin{:})
            obj.PageNames = pageNames;

            obj.createIndicator()

            obj.IsConstructed = true;

            
            % Call updateSize to trigger size update (call before location)
            obj.updateSize('auto')
            
            % Call updateLocation to trigger location update
            obj.updateLocation('auto')
            

        end
        
        
        function delete(obj)
            delete(obj.hPageButtons)
            delete(obj.hPageLabels)
            delete(obj.hHBar)
            delete(obj.hVBar)
        end
        
    end
    
    methods % Set property values
        
        function set.BarColor(obj, newValue)
            
            obj.BarColor = newValue;
            obj.onAppearanceChanged()
        end
        
        function set.FontColor(obj, newValue)

            obj.FontColor = newValue;
            obj.onAppearanceChanged()
        end
        
        function set.IndicatorColor(obj, newValue)

            obj.IndicatorColor = newValue;
            obj.onAppearanceChanged()
        end

    end
    
    
    methods (Access = private)
        
        function createIndicator(obj)
            
            R = obj.IndicatorSize/2;
            S = R*3/4;
            
            pos = obj.Position(1:2);
            
            xInit = pos(1);

            
            [X,Y] = uim.shape.circle(R);
            
            % Coordinates for bars:
            y1 = max(Y);
            y2 = pos(2)+3*R;
            
            for i = 1:numel(obj.PageNames)
                
                X_ = X + pos(1);
                Y_ = Y;
                
                obj.hPageButtons(i) = patch(obj.hAxes, X_, Y_, obj.IndicatorColor);
                obj.setPointerBehavior(obj.hPageButtons(i))
                obj.hPageButtons(i).ButtonDownFcn = @obj.onPageButtonPressed;
                
                % Todo: Use a button
% %                 h = uim.control.Button(obj.Parent, ...
% %                     'Position', [pos(1:2)+10, 10*R, 10*R], 'Size', [2*R, 2*R], ...
% %                     'PositionMode', 'manual', 'CornerRadius', 6, 'Style', uim.style.nansenPageButton);
                
                
                obj.hPageLabels(i) = text(obj.hAxes, pos(1), pos(2)+3*R, obj.PageNames{i}, 'Color', obj.FontColor);
                obj.hPageLabels(i).FontUnits = 'pixel';
                obj.hPageLabels(i).FontSize = 12;
                
                
                obj.hVBar(i) = plot(obj.hAxes, ones(1,2)*(pos(1)+R), [y1, y2]);
                
                if i == 1
                    obj.hPageButtons(i).FaceColor = obj.BarColor;
                else
                    obj.hPageLabels(i).Visible = 'off';
                    obj.hVBar(i).Visible = 'off';
                end
                
                pos(1) = pos(1) + 2*R + S;
                
            end
            
            xEnd = pos(1) - S;
            obj.hHBar = plot(obj.hAxes, [xInit, xEnd], ones(1,2) * y2 );
            
            set([obj.hHBar, obj.hVBar], 'Color', obj.BarColor)
            set([obj.hHBar, obj.hVBar], 'LineWidth', 1.5)
            set([obj.hPageButtons, obj.hVBar], 'LineWidth', 1)


            centerPosX = xInit + (xEnd-xInit) / 2;
            
            set(obj.hPageLabels, 'VerticalAlignment', 'Bottom', 'HorizontalAlignment', 'center')
            set(obj.hPageLabels, 'FontSize', obj.FontSize)
            for i = 1:numel(obj.hPageLabels)
                obj.hPageLabels(i).Position(1) = centerPosX;
            end
            
        end
        
        function shiftComponents(obj, shift)
            
            for i = 1:numel(obj.PageNames)
                obj.hPageButtons(i).XData = obj.hPageButtons(i).XData + shift(1);
                obj.hPageButtons(i).YData = obj.hPageButtons(i).YData + shift(2);
                obj.hVBar(i).XData = obj.hVBar(i).XData + shift(1);
                obj.hVBar(i).YData = obj.hVBar(i).YData + shift(2);                
                obj.hPageLabels(i).Position(1:2) = obj.hPageLabels(i).Position(1:2) + shift(1:2);
            end
            
            obj.hHBar.XData = obj.hHBar.XData + shift(1);
            obj.hHBar.YData = obj.hHBar.YData + shift(2);                           
            
        end
    end
    
    
    methods
        
        function restyle(obj)
            
        end
        
        function redraw(obj)
            
        end
        
        function relocate(obj, shift)
            relocate@uim.abstract.virtualContainer(obj, shift)
            obj.shiftComponents(shift)
        end
        
        function changePage(obj, newPageNumber)
            
            switch newPageNumber
                case 'next'
                    newPageNumber = obj.CurrentPage + 1;
                case 'previous'
                    newPageNumber = obj.CurrentPage - 1;
            end
            
            if newPageNumber < 1 || newPageNumber > numel(obj.PageNames)
                return
            end
    
            % Deactivate current page
            obj.hPageButtons(obj.CurrentPage).FaceColor = obj.IndicatorColor;
            obj.hPageLabels(obj.CurrentPage).Visible = 'off';
            obj.hVBar(obj.CurrentPage).Visible = 'off';

            % Activate new page
            obj.hPageButtons(newPageNumber).FaceColor = obj.BarColor;
            obj.hPageLabels(newPageNumber).Visible = 'on';
            obj.hVBar(newPageNumber).Visible = 'on';
            
            obj.CurrentPage = newPageNumber;
        end
        
        function onMouseOverIndicator(obj)
            
        end
        
        function onStyleChanged(obj)

        end
        
        function onAppearanceChanged(obj)

            if ~obj.IsConstructed; return; end
            
            set(obj.hPageButtons, 'FaceColor', obj.IndicatorColor)
            set(obj.hPageLabels, 'Color', obj.FontColor)
            set([obj.hHBar, obj.hVBar], 'Color', obj.BarColor)
            obj.hPageButtons(obj.CurrentPage).FaceColor = obj.BarColor;
        
        end
        
        function onVisibleChanged(obj, newValue)
            if obj.IsConstructed
                set(obj.hHBar, 'Visible', obj.Visible)
                set(obj.hPageButtons, 'Visible', obj.Visible)
                
                set(obj.hVBar(obj.CurrentPage), 'Visible', obj.Visible)
                set(obj.hPageLabels(obj.CurrentPage), 'Visible', obj.Visible)
            end
        end
        
        function setPointerBehavior(obj, h)
        %setPointerBehavior Set pointer behavior of background.

            pointerBehavior.enterFcn    = @(s,e) obj.onMouseEntered(s, h);
            pointerBehavior.exitFcn     = @(s,e) obj.onMouseExited(s, h);
            pointerBehavior.traverseFcn = [];%@obj.moving;
            
            iptSetPointerBehavior(h, pointerBehavior);
            iptPointerManager(ancestor(h, 'figure'));

        end
        
        function onMouseEntered(obj, hFig, h)
            h.EdgeColor = obj.BarColor;
            hFig.Pointer = 'hand';
            
            isCurrent = ismember(obj.hPageButtons, h);
            obj.hPageLabels(obj.CurrentPage).Visible = 'off';
            obj.hPageLabels(isCurrent).Visible = 'on';
        end

        function onMouseExited(obj, hFig, h)
            h.EdgeColor = 'k';
            hFig.Pointer = 'arrow';
            
            isCurrent = ismember(obj.hPageButtons, h);
            obj.hPageLabels(isCurrent).Visible = 'off';
            obj.hPageLabels(obj.CurrentPage).Visible = 'on';

        end
        
        function onPageButtonPressed(obj, src, evt)
            
            oldPageNumber = obj.CurrentPage;
            newPageNumber = find( ismember(obj.hPageButtons, src) );
            
            evtData = uiw.event.EventData('OldPageNumber', oldPageNumber, ...
                'NewPageNumber', newPageNumber);
            
            if ~isempty(obj.ChangePageFcn)
                obj.ChangePageFcn(obj, evtData);
            end
            
        end
        
    end
   
   
end