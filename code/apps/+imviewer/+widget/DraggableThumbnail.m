classdef DraggableThumbnail < handle
    
    % Create an image thumbnail that can be dragged around the screen.
    
    properties
        hFigure
        hJFrame
        hAxes
        hImage
        
        initPos
        initPosJava
        buttonDown=false
    end
    
    methods
        
        function obj = DraggableThumbnail(hFig, im, initPos, cMap)
            warning('off', 'MATLAB:HandleGraphics:ObsoletedProperty:JavaFrame');
            warning('off', 'MATLAB:ui:javaframe:PropertyToBeRemoved')
            screenSize = get(0, 'ScreenSize');
            
            sz = [128, 128];
%             x = initPos(1)-sz(1)/2;
%             y = initPos(2)-sz(2)/2;
            
            x = hFig.Position(1) + hFig.Position(3)/2;
            y = hFig.Position(2) + hFig.Position(4)/2;
            
            jFrame = get(hFig, 'JavaFrame');
            jClient = jFrame.fHG2Client;
            jWindow = jClient.getWindow;
            jWindow.setAlwaysOnTop(true)
            
            obj.hFigure = figure('Menubar', 'none', 'Position', [x,y,sz]);
            obj.hAxes = axes(obj.hFigure);
            colormap(obj.hFigure, cMap)
            obj.hImage = image(obj.hAxes, im, 'CDataMapping', 'scaled');
            obj.hAxes.Visible = 'off';
            
            hold(obj.hAxes, 'on');
            plot(obj.hAxes, obj.hAxes.XLim([1,1,2,2,1]), obj.hAxes.YLim([1,2,2,1,1]), 'LineWidth', 1, 'Color', ones(1,3)*0.5)
            
            %obj.hAxes.XLim = [0, size(im, 2)];
            
            obj.hJFrame = undecorateFig(obj.hFigure);
            
            obj.hJFrame.setSize(java.awt.Dimension(sz(1), sz(2)));

            obj.hAxes.Position = [0, 0, 1, 1];

            x = initPos(1)-sz(1)/2;
            y = screenSize(4) - initPos(2)-sz(2)/2;

            obj.hJFrame.setLocation(java.awt.Point(x, y));
            obj.hJFrame.setOpacity(0.8)
            
            %obj.hFigure.WindowButtonDownFcn = @obj.startMoveWindow;
            obj.hFigure.WindowKeyPressFcn = @obj.onKeyPressed;

            jWindow.setAlwaysOnTop(false)
            figure(obj.hFigure)
            
            obj.initPos = initPos;
            obj.initPosJava = [x,y];
            
            %obj.startMoveWindow
            warning('on', 'MATLAB:HandleGraphics:ObsoletedProperty:JavaFrame');
            warning('on', 'MATLAB:ui:javaframe:PropertyToBeRemoved')
            
            obj.hFigure.WindowButtonUpFcn = @obj.stopMoveWindow;

        end
        
        function delete(obj)
            close(obj.hFigure)
        end
        
        function onKeyPressed(obj, ~, event)
           
            switch event.Key
                case 'x'
                    delete(obj)
            end
        end

        function startMoveWindow(obj, ~, ~)
            %startMovePos = get(obj.hFigure, 'CurrentPoint');
            startMovePos = get(0, 'PointerLocation');
            obj.buttonDown = true;
            
            if strcmp( obj.hFigure.SelectionType, 'alt')
                delete(obj); return
            end
            
            if isempty(obj.hJFrame)
                initFigPos = obj.hFigure.Position(1:2);
            else
                initFigPos = obj.hJFrame.getLocation;
                initFigPos = [initFigPos.x, initFigPos.y];
            end
            
            obj.initPos = startMovePos;
            obj.initPosJava = initFigPos;
            
%             obj.hFigure.WindowButtonMotionFcn = @obj.moveWindow;
%             obj.hFigure.WindowButtonUpFcn = @obj.stopMoveWindow;
        end
        
        function moveWindow(obj, ~, ~)
                            
            %mousePoint = get(obj.hFigure, 'CurrentPoint');
            mousePoint = get(0, 'PointerLocation');

            shift = mousePoint - obj.initPos;
            
            if isempty(obj.hJFrame)
%                 obj.hFigure.Position(1:2) = initFigPos + shift;
%                   bug here...
            else
                newPos = obj.initPosJava + shift.*[1,-1];
                obj.hJFrame.setLocation(java.awt.Point(newPos(1), newPos(2)));
            end
        end
        
        function stopMoveWindow(obj, ~, ~)
            obj.buttonDown = false;
            obj.hFigure.WindowButtonMotionFcn = [];
            obj.hFigure.WindowButtonUpFcn = [];
            
            el1 = getappdata( obj.hFigure, 'el1');
            el2 = getappdata( obj.hFigure, 'el2');
            delete(el1)
            delete(el2)
            delete(obj)
        end
    end
end
