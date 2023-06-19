classdef RoiDisplayInputHandler < handle
%RoiDisplayInputHandler Handler for mouse/keyboard inputs on a roidisplay
    %   Detailed explanation goes here
    
    properties
        RoiDisplay roimanager.roiDisplay
    end
    
    methods
        function obj = RoiDisplayInputHandler(roiDisplay)
            %RoiDisplayInputHandler Construct an instance of this class
            %   Detailed explanation goes here
            
            if ~nargin; return; end
            obj.RoiDisplay = roiDisplay;
        end
    end
    
    
    methods 
        
        function wasCaptured = roiKeypressHandler(obj, src, event)
            
            wasCaptured = false;
            
            if isempty(obj.RoiDisplay); return; end
            if isempty(obj.RoiDisplay.SelectedRois); return; end
            
            % Set flag to true. Instead of setting flag to true for each 
            % case where key event is captured, it is set to false for each 
            % case where it is not.
            wasCaptured = true;

            % Keypress events that should only be handled if roi is selected:
            switch event.Key

                case {'1', '2', '3', '4', '5', '6', '7', '8', '9', '0'}
                    if isempty(event.Modifier)
                        obj.RoiDisplay.classifyRois(str2double(event.Key));
                    else
                        wasCaptured = false;
                    end
                    % Todo: change roi type using shift click??
                    
                case {'backspace', '⌫'}
                    obj.RoiDisplay.removeRois();
                                
                case 'e'
                    if strcmp(event.Modifier, 'shift')
                        obj.RoiDisplay.changeCellType('excitatory')    
                    end

                case 'i'
                    if strcmp(event.Modifier, 'shift')
                        obj.RoiDisplay.changeCellType('inhibitory')
                    elseif isempty(event.Modifier)
                        obj.RoiDisplay.improveRois();
                    end
                case 'a'
                    if strcmp(event.Modifier, 'shift')
                        obj.RoiDisplay.changeCellType('axon')
                    end
                case 'g'
                    obj.RoiDisplay.growRois();
                    
                case 'h'
                    obj.RoiDisplay.shrinkRois();
                
% %                 case 'n' % For testing...
% %                     obj.RoiDisplay.selectNeighbors()
                    
                case 'c'
                    if strcmp(event.Modifier, 'shift')
                        obj.RoiDisplay.connectRois() % Todo: delegate to roimanager instead?
                    else
                        wasCaptured = false;
                    end
                    
                case 'm'
                    if strcmp(event.Modifier, 'shift')
                        
                    else
                        wasCaptured = false;
                    end
                    % todo....
%                     if strcmp(event.Modifier, 'shift')
%                         obj.RoiDisplay.mergeRois() % Todo: delegate to roimanager instead?
%                     end
                    
                %todo: arrowkeys for moving rois.
                case obj.getArrowKeyCharacterVectors()
                    
                    shift = obj.keyname2shift(strrep(event.Key, 'arrow', ''));
                    
                    if strcmp(event.Modifier, 'shift')
                        shift = shift*5;
                    end

                    obj.RoiDisplay.moveRoi(shift)
                    
                    
                otherwise
                    wasCaptured = false;
            end
        end
        
    end
    
    methods (Static, Access = private)
        
        function arrowKeys = getArrowKeyCharacterVectors()
        %getArrowKeyCharacterVectors Get list of chars for all arrow keys
            
            arrowKeys = { ...
                'leftarrow',  '←', ...
                'rightarrow', '→', ...
                'uparrow',    '↑', ...
                'downarrow',  '↓'  ...
                        };
        end
        
        function shift = keyname2shift(direction)
        %keyname2shift Convert arrow character vector to xy shift vector
            % Todo: Enumerator?
            switch direction
                case {'left', '←'}
                    shift = [-1, 0];
                case {'right', '→'}
                    shift = [1, 0];
                case {'up', '↑'}
                    shift = [0, -1];
                case {'down', '↓'}
                    shift = [0, 1]; 
            end
        end
        
    end
    
end