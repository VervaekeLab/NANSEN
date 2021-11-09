classdef isResizable < uim.handle
%isResizeable

% Todo: 
%   [ ] Generalize so that it can be used on any object that implements a
%       position property. Especially virtual containers?
%   [ ] Update references in different apps/scripts/functions

    properties (Abstract)
        Position
    end
    
    properties
        Children = []            % Should maybe not be transient
        isMoveable = true
        isResizeable = true
    end
    
    properties (Hidden, Transient)
        Parent              % (InteractionAxes) % should be protected and hidden....
        SizeChangedFcn      % Function handle. Function must accept two inputs (newPosition, oldPosition)
        DefaultButtonDownFcn = []
        ResizeButtonDownFcn = []
    end
    
    properties (Hidden, Transient, Access = protected)
        PickableParts = 'all'; % When visible... Is set to none when invisible.
        ImrectCallbacks = [];
        rectDestroyedListener = event.listener.empty
    end
    
    properties (Hidden, Transient, Access = public)    
        interactiveRectangle
    end
    
    
    methods (Abstract, Access = protected)
        setDefaultButtonDownFcn(obj, fcnHandle)
        resize(obj, pos)
    end
    
    
    methods 
        
        function delete(obj)
            for i = numel(obj.Children):-1:1
                delete(obj.Children(i))
            end
            
            if ~isempty(obj.interactiveRectangle) && isvalid(obj.interactiveRectangle)
                delete(obj.interactiveRectangle)
            end
        end
        
        
        function createInteractiveRectangle(obj)
            
            % Make an imrect for interactively moving and resizing the 
            % virtualPanel.
            
            if ~isempty(obj.interactiveRectangle)
                delete(obj.interactiveRectangle)
            end
            
            hRect = imrect(obj.Parent, obj.Position);
            
            hRect.setColor([0.7608    0.6471    0.8118]) %obj.rectColors.Default)
            hRect.addNewPositionCallback(@(pos) obj.onSizeChanged(pos));
            
            el = addlistener(hRect, 'ObjectBeingDestroyed', @(src,evt) delete(obj));
            obj.rectDestroyedListener = el;

            
            % todo: work on this....
% % %             hFunc = makeConstrainToRectFcn('imrect', obj.margins([1,3]), obj.margins([2,4]));
% % %             hRect.setPositionConstraintFcn(hFunc);
            

% % %             % Modify button down to also run mousepress callback.
% % %             ptmp = findobj(hRect,'Type', 'patch');
% % %             funhandle = ptmp.ButtonDownFcn;
% % %             set(ptmp, 'ButtonDownFcn', {@obj.mousePressed, funhandle, 'interior'} )
% % %         
% % %             ctmp = findobj(hRect, '-regexp', 'Tag', 'corner');
% % %             set(ctmp, 'ButtonDownFcn', {@obj.mousePressed, ctmp(1).ButtonDownFcn, 'corner'} );
% % % 
% % %             ltmp = findobj(hRect, '-regexp', 'Tag', 'top line');
% % %             set(ltmp, 'ButtonDownFcn', {@obj.mousePressed, ltmp(1).ButtonDownFcn, 'side'} );

        
            % set all context menus for the underlying line and patch objects

% % %             % Edit the context menu of the rectangle. TODO: Add customs..
% % %             hComp = findobj(hRect, 'Type', 'line', '-or', 'Type', 'patch');
% % %             
% % %             cmHandle = obj.configContextMenu(hComp(1).UIContextMenu);
% % %             set(hComp, 'uicontextmenu', cmHandle);
            
            
            
            % Find the hggroup of the imrect. Move it down in the stack so
            % that the imrect for the margins will stay on top.
            imrectGroup = findobj(hRect, 'Type', 'hggroup', 'Tag', 'imrect');
            %uistack(imrectGroup, 'down')
            
            obj.interactiveRectangle = hRect;
            
         end
        
        
        function hideInteractiveRectangle(obj)
            imrectGroup = findobj(obj.interactiveRectangle, ...
                'Type', 'hggroup', 'Tag', 'imrect');
            set(imrectGroup, 'Visible', 'off');
            
            pTmp = findobj(obj.interactiveRectangle, 'Type', 'patch');
            pTmp.HitTest = 'off';
            pTmp.PickableParts = 'none';
        end
        
        
        function showInteractiveRectangle(obj)
            
                    
            if obj.isResizeable
                imrectGroup = findobj(obj.interactiveRectangle, ...
                    'Type', 'hggroup', 'Tag', 'imrect');
                set(imrectGroup, 'Visible', 'on');
            end
            
            if obj.isMoveable || obj.isResizeable
                pTmp = findobj(obj.interactiveRectangle, 'Type', 'patch');
                pTmp.HitTest = 'on';
                pTmp.PickableParts = obj.PickableParts;
            end
            
            
        end
        
        
        function setPositionConstraintFcn(obj, hFunc)
            obj.interactiveRectangle.setPositionConstraintFcn(hFunc);
        end
        
        
        function setPosition(obj, newPosition, mode)
            
            if nargin < 3 || isempty(mode)
                mode = 'constrained';
            end
            
            if strcmp(mode, 'constrained')
                obj.interactiveRectangle.setConstrainedPosition(newPosition)
            elseif strcmp(mode, 'unconstrained') 
                obj.interactiveRectangle.setPosition(newPosition)
            end
        end
        
        
        function setColor(obj, newColor)
        %setColor Set color of imrect
            obj.interactiveRectangle.setColor(newColor)
        end
        
        
        function pos = getPosition(obj)
            pos = obj.interactiveRectangle.getPosition();
        end
        
        
        function lim = getPositionLimits(obj)
            lim = obj.Position([1,2,1,2]) + [0, 0, obj.Position(3:4)];
        end
        
        
        function pixelpos = getpixelposition(obj)
            pixelPosParent = getpixelposition(obj.Parent);
            pixelpos = pixelPosParent([1,2,1,2]) + ...
                            pixelPosParent([3,4,3,4])*obj.Position;
        end
        
        
        function hArray = getImrectHandles(obj)
            hArray = findobj( obj.interactiveRectangle, ...
                                'Type', 'line', '-or', 'Type', 'patch');
        end
        
        
        function set.ResizeButtonDownFcn(obj, newFunc)
            obj.configNewResizeButtonDownFcn(newFunc)
            obj.ResizeButtonDownFcn = newFunc;
        end
        
        
        function set.DefaultButtonDownFcn(obj, newValue)
            obj.DefaultButtonDownFcn = newValue;
            
            % Call subclass method
            obj.setDefaultButtonDownFcn(newValue)
        end
        
        
        function resizeChildren(obj, newPosition, oldPosition)
            
            hFig = ancestor(obj.Parent, 'figure');
            
            oldLim = [oldPosition(1:2), oldPosition(1:2) + oldPosition(3:4)];
            newLim = [newPosition(1:2), newPosition(1:2) + newPosition(3:4)];
            
            
            % Calculate normalized change in position and size of panels 
            % based on change in the canvas.
            dW = (diff(newLim([1,3])) - diff(oldLim([1,3]))) / diff(oldLim([1,3]));
            dH = (diff(newLim([2,4])) - diff(oldLim([2,4]))) / diff(oldLim([2,4]));
            dx = newLim(1) - oldLim(1);
            dy = newLim(2) - oldLim(2); 
            
            %fprintf('dH: %g, dW: %g\n', dH, dW)
            isResized = abs(dH) > 1e-9 || abs(dW) > 1e-9; % Take care of imprecision
            isMoved = (dx ~= 0 || dy ~= 0) && ~isResized;
            
            if isResized && strcmp(hFig.SelectionType, 'extend'); return; end
            
            %xLim = [newPosition(1), sum(newPosition([1,3]))];
            %yLim = [newPosition(2), sum(newPosition([2,4]))];
            %fcn = makeConstrainToRectFcn('imrect', xLim, yLim);
            
            for i = 1:numel(obj.Children)
                
                % setPositionConstraintFcn(obj.Children(i), fcn);
                iPosition = obj.Children(i).Position;

                % Calculate new position for object
                newPosTmp = iPosition;
                newPosTmp(3) = newPosTmp(3) + dW*newPosTmp(3);
                if dx == 0
                    newPosTmp(1) = newPosTmp(1) + dW*(newPosTmp(1)-newPosition(1));
                else
                    newPosTmp(1) = newPosTmp(1) + dx + dW*(newPosTmp(1)+dx-newPosition(1));
                end
                
                newPosTmp(4) = newPosTmp(4) + dH*newPosTmp(4);
                
                if dy == 0
                    newPosTmp(2) = newPosTmp(2) + dH*(newPosTmp(2)-newPosition(2));
                else
                    newPosTmp(2) = newPosTmp(2) + dy + dH*(newPosTmp(2)+dy-newPosition(2));
                end

                obj.Children(i).setPosition(newPosTmp, 'unconstrained')
            end            
            
        end
        
    end
    
    
    methods (Access = protected)
        
        % Work in progress.
        function onSizeChanged(obj, newPosition)
        %onSizeChanged
            
            oldPosition = obj.Position;
            
            % Assign new position to the position property. Do this before
            % calling the resize method, because this method will depend on
            % the position property.
            obj.Position = newPosition;
            
            % Call the resize method. This is an abstract method, so each
            % subclass will have its own implementation
            obj.resize(newPosition, oldPosition)
            
            if ~isempty(obj.Children)
                obj.resizeChildren(newPosition, oldPosition)
            end
            
            if ~isempty(obj.SizeChangedFcn)
                obj.SizeChangedFcn(newPosition, oldPosition)
            end

        end
        
        
        function configNewResizeButtonDownFcn(obj, newFunc)
        %configNewResizeButtonDownFcn
        
            if isempty(obj.interactiveRectangle); return; end
            
            pTmp = findobj(obj.interactiveRectangle, 'Type', 'patch');
            cTmp = findobj(obj.interactiveRectangle, '-regexp', 'Tag', 'corner');
            lTmp = findobj(obj.interactiveRectangle, '-regexp', 'Tag', 'top line');

            if isempty(obj.ImrectCallbacks)
                obj.ImrectCallbacks = {pTmp.ButtonDownFcn, ...
                    cTmp(1).ButtonDownFcn, lTmp(1).ButtonDownFcn};
            end
            
            set(pTmp, 'ButtonDownFcn', {newFunc, obj.ImrectCallbacks{1}, obj, 'interior'} )
            set(cTmp, 'ButtonDownFcn', {newFunc, obj.ImrectCallbacks{2}, obj, 'corner'} );
            set(lTmp, 'ButtonDownFcn', {newFunc, obj.ImrectCallbacks{3}, obj, 'side'} );
            
        end
        
        
    end
    
    
    methods (Static)
        
        function rect2pos(rectCoords)
            
        end
        
        function pos2rect(posCoords)
            
        end
        
        
        function BW = rect2mask(rectCoords, maskSize)
           
            maskSize = round(maskSize); 
            
            BW = false(maskSize(2), maskSize(1));
            pos = round(rectCoords .* [maskSize, maskSize]);
            pos(3:4) = pos(1:2) + pos(3:4);
            
            pos(pos<1) = 1;
            if pos(3) > maskSize(1); pos(3)=maskSize(1); end
            if pos(4) > maskSize(2); pos(4)=maskSize(2); end
            
            BW(pos(2):pos(4), pos(1):pos(3)) = true;
            
        end
        
        
        function newPosition = getChildPosition(oldPosition, deltaPosition)
            
            
        end
        
        
    end
    
    
    
end