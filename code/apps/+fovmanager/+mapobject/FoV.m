classdef FoV < fovmanager.mapobject.BaseObject
%FoV is a class for registering field of view on a brain surface map

% Save roi coordinates in this database? Why not. Match with uids then...
% Save current session as sessionID, number or duplicate of struct from 
% list of sessions?

% Resolve this...
% Also, should roi coordinates be saved back to roiarray/sdata when
% assigned here....?

% Add displaymessage when adding sessions...
% Should the add session be a method of the gui??? 
% yes and no... Benefit of having it on the Fov is that it automatcally
% ends up in the right fov.... But anyway, the fov has to be selected, and
% that happens in the gui....

% Yes, add session should be a fovmanager method...

% Add fovRegionMajor
% Add fovRegionMinor

    properties
        
        depth
        nRois
        
        currentSession
        listOfSessions = struct.empty; % Struct array of sessions

    end
    
    
    properties (Transient)
       boundaryWidth = 1;
       boundaryColor = 'k';
    end
    
   
    methods
        

% % % % Functions for adding fov image
        
        function obj = FoV(varargin) 
        % Initialize FoV
        %             
        %   FoV(fovmanager, centerPosition, size) creates a new FoV in the 
        %   FoV manager.
        %
        %   FoV(fovmanager, S) where S is a struct of FoV properties will
        %   recreate an already existing FoV.
        %   
        %   FoV(S) creates a FoV object, but does not do any plotting.
        
            if isa(varargin{1}, 'fovmanager.App')
                fmHandle = varargin{1};
                varargin = varargin(2:end);
            elseif isa(varargin{1}, 'matlab.graphics.axis.Axes')
                hAx = varargin{1};
                varargin = varargin(2:end);
            end
            
            if isa(varargin{1}, 'struct')
                obj.fromStruct(varargin{1})
                varargin = varargin(2:end);
            else
                % Assume 1st argument is a position vector
                validateattributes(varargin{1}, {'numeric'}, {'numel', 2})
                centerPosition = varargin{1};
                
                % Assume 2nd argument is a size 
                validateattributes(varargin{2}, {'numeric'}, {'nonzero'})
                fovSize = varargin{2};
                if numel(fovSize) == 1
                    fovSize = repmat(fovSize,1,2);
                end
                
                obj.center = centerPosition;
                obj.shape = 'square';
                
                % Set edge coordinates, starting upper left and ccw (x,y).
                obj.edge = [ [-1;-1;1;1] * fovSize(1)/2,  ...
                             [1;-1;-1;1] * fovSize(2)/2 ] + obj.center;
                varargin = varargin(3:end);
            end
            
            
            % Set orientation if given as optional input.
            if ~isempty(varargin) 
                if contains('orientation', varargin(1:2:end))
                    vInd = find(contains(varargin(1:2:end), 'orientation'));
                    obj.orientation = varargin{(vInd-1)*2+2};
                end
            end
            

            % % % % Temp during transition where list of session is changed
            % from sessionID to struct
            if ~isempty(obj.listOfSessions) && ~isa(obj.listOfSessions, 'struct')
                S = struct;
                for i = 1:numel(obj.listOfSessions)
                    S(i).sessionID = obj.listOfSessions{i};
                end
                obj.listOfSessions = S;
                obj.currentSession = obj.listOfSessions(1).sessionID; 
            end
            
            
            % Plot fov edges and show image if present.
            if exist('fmHandle', 'var')
                obj.displayObject(fmHandle)

            elseif exist('hAx', 'var')
                obj.guiHandle = hggroup(hAx);
                obj.plotBoundary()
            end
            
            
        end
        
        
        function displayName = getDisplayName(obj, keyword) %#ok<MANU>
            
            if nargin < 2; keyword = ''; end
            
            switch keyword
                case 'class'
                    displayName = class(obj);
                    displayName = strrep(displayName, 'fovmanager.mapobject.', '');
                otherwise
                    displayName = 'Fov';
            end
            
        end
        
        
        function infoText = getInfoText(obj)
            
            infoText = '';
            
            
            if ~isempty(obj.currentSession)
                infoText = sprintf('Session ID: %s\n', strrep(obj.currentSession, '_', '-'));
            end
            
            fovLocs = fovmanager.utility.atlas.assignFovLocation(obj);
            infoText = sprintf('%sFov Region: %s\n', infoText, fovLocs{1});
            
            if ~isempty(obj.depth)
                infoText = sprintf('%sFov Depth: %d um\n', infoText, round(mean(obj.depth)));
            end
            
            if ~isempty(obj.nRois)
                infoText = sprintf('%snRois: %d', infoText, round(mean(obj.nRois)));
            end
            
            if ~isempty(infoText) && isequal(double(infoText(end)), 10) % 10 is the newline charater
                infoText = infoText(1:end-1);
            end
            
%             hTxt.String = infoText;
        end
        
        
        function fromStruct(obj, S)
            fromStruct@fovmanager.mapobject.BaseObject(obj, S)
            
            % Fix some unexpected name changes....
            if isfield(S, 'fovImage')
                obj.image = S.fovImage;
            end 
        end
        
        
        function set.boundaryColor(obj, color)
            h = findobj(obj.guiHandle, '-regexp', 'Tag', 'Outline');
            h.EdgeColor = color;
            obj.boundaryColor = color;
        end
        
        
        function set.boundaryWidth(obj, width)
            h = findobj(obj.guiHandle, '-regexp', 'Tag', 'Outline');
            h.LineWidth = width;
            obj.boundaryWidth = width;
        end
        
        
        function hIm = showImage(obj)
            hIm = obj.updateImage();
            if ~nargout; clear hIm; end
        end
        
% % % % Methods for adding sessions to FoV

        function addSessionObject(obj, sessionObjects)
            % Todo: merge with addSessions Method
            
            
            if isempty(obj.listOfSessions); obj.listOfSessions = []; end
            
            obj.listOfSessions = cat(2, obj.listOfSessions, sessionObjects);
            
            mh = findobj(obj.guiHandle.UIContextMenu, 'Text', 'Show Rois');
            if ~isempty(mh)
                mh.Enable = 'on';
            end
            
            % Sort entries
            [~, indSorted] = sort({obj.listOfSessions.sessionID});
            obj.listOfSessions = obj.listOfSessions(indSorted);
            
            
            % Update menu...
            obj.updateSessionContextSubmenu()
            
        end


        function addSession(obj, sessionIDs)
            
            % Request sessionID from user if no sessionID is provided.
            if nargin < 2
                sessionIDs = inputdlg('Enter sessionID');
                if isempty(sessionIDs); return; end
                
                sessionIDs = strsplit(sessionIDs{1}, ','); % Split by comma (if list was given)
                sessionIDs = strsplit(sessionIDs{1}, ' '); % Split by comma (if list was given)
                sessionIDs = strrep(sessionIDs, '''', ''); % Remove extra apostrophes
                sessionIDs = strrep(sessionIDs, ' ', ''); % Remove extra spaces
            end
            
            currentSessionIDs = {obj.listOfSessions.sessionID};
                        
            % Add sessionID, fovImage, roiArray and depth to session struct
            for i = 1:numel(sessionIDs)
                
                % Skip session if it is already in the list
                if contains(sessionIDs{i}, currentSessionIDs)
                    continue
                end
                
                % Skip session if it is not a valid sessionID
                if ~isequal(strfindsid(sessionIDs{i}), sessionIDs{i}) 
                    warning('Invalid sessionID; %s. Session not added.', sessionIDs{i});
                    continue;
                end
                
                n = numel(obj.listOfSessions)+1;
                obj.listOfSessions(n).sessionID = sessionIDs{i};
                
                data = fovmanager.fileio.getdata(sessionIDs{i}, {'roiArray', 'fovDepth', 'fovImage'});
                obj.listOfSessions(n).nRois = numel(data.roiArray);
                obj.listOfSessions(n).depth = data.fovDepth;
                obj.listOfSessions(n).fovImage = data.fovImage;

            end
            
            mh = findobj(obj.guiHandle.UIContextMenu, 'Text', 'Show Rois');
            if ~isempty(mh)
                mh.Enable = 'on';
            end
            
            % Sort entries
            [~, indSorted] = sort({obj.listOfSessions.sessionID});
            obj.listOfSessions = obj.listOfSessions(indSorted);
            
            
            % Update menu...
            obj.updateSessionContextSubmenu()
            
            
        end
        
        
        function removeSession(obj, sessionIDs)
            
            % Request sessionIDs from user if no sessionID is provided.
            if nargin < 2
                currentSessionIDs = {obj.listOfSessions.sessionID};
            
                [IND, ~] = listdlg('ListString', currentSessionIDs, ...
                                    'SelectionMode', 'multi', ...
                                    'ListSize', [250, 200], ...
                                    'Name', 'Select Sessions');

                if isempty(IND); return; end
%                 sessionIDs = currentSessionIDs(IND);
            else
                IND = contains({obj.listOfSessions.sessionID}, sessionIDs);
            end
            
            obj.listOfSessions(IND) = [];
            
            % Update menu...
            obj.updateSessionContextSubmenu()
            
        end
        

        function tf = containsSession(obj, sessionID)
            
            if isa(sessionID, 'char')
                sessionID = {sessionID};
            end
            
            tf = false(size(sessionID));
            if isempty(obj.listOfSessions); return; end

            for i = 1:numel(sessionID)
                tf(i) = contains(sessionID(i), {obj.listOfSessions.sessionID});
            end

        end
        
        
        function changeSession(obj, sessionID)
        
            sInd = find(contains({obj.listOfSessions.sessionID}, sessionID));
            
            currentSessionStruct = obj.listOfSessions(sInd);

            obj.nRois = currentSessionStruct.nRois;
            obj.image = currentSessionStruct.fovImage;
            obj.depth = currentSessionStruct.depth;
            obj.currentSession = currentSessionStruct.sessionID;
            
            % Update Fov Image
            obj.updateImage()
            
            % Update roi plot...
            hRois = findobj(obj.guiHandle, 'Tag', 'Roi Centers');
            
            if isempty(hRois)
                % Skip for now...
%                 obj.plotRois();
            else
                mapCoords = getRoiMapCoordinates(obj, sInd);
                set(hRois, 'XData', mapCoords(:,1), 'YData', mapCoords(:,2))
            end
            
            % Update menu...
            obj.updateSessionContextSubmenu()

            % Update info
            obj.showInfo()
            
        end
        
        
        function updateSessionContextSubmenu(obj, menuHandle)
            
            if nargin < 2
                menuHandle = findobj(obj.guiHandle.UIContextMenu, 'Text', 'Set Current Session');
            end
            
            delete(menuHandle.Children)

            alternatives = {obj.listOfSessions.sessionID};
            alternatives = sort(alternatives);
            
            for i = 1:numel(alternatives)
                tmpItem = uimenu(menuHandle, 'Text', alternatives{i});
                if i == 1 && isempty(obj.currentSession)
                    tmpItem.Checked = 'on'; % Change session...
                elseif strcmp(alternatives{i}, obj.currentSession)
                    tmpItem.Checked = 'on';
                end
                tmpItem.Callback = @(s, e) obj.changeSession(alternatives{i});
            end

            menuHandle.Enable = 'on';
            
            
            if isempty(obj.listOfSessions)
                tmpHandle = findobj(obj.guiHandle.UIContextMenu, 'Text', 'Show Rois');
                set(tmpHandle, 'Enable', 'off')
            end
            
        end
        
        
% % % % Methods for plotting rois

        function toggleShowHideRois(obj, src, ~)
            
            hRois = findobj(obj.guiHandle, 'Tag', 'Roi Centers');
            if isempty(hRois); hRois = obj.plotRois(); end
            
            switch src.Text
                case 'Show Rois'
                    hRois.Visible = 'on';
                    src.Text = 'Hide Rois';
                case 'Hide Rois'
                    hRois.Visible = 'off';
                    src.Text = 'Show Rois';
            end
            
        end
            

        function mapCoords = getRoiMapCoordinates(obj, sInd, sId)
            
            % Todo: consider doing inputs differently here. Its not very
            % clean...
            
            if nargin < 2
                sInd = find(contains({obj.listOfSessions.sessionID}, obj.currentSession));
            end
            
            if nargin < 3
                sId = obj.listOfSessions(sInd).sessionID;
            end
            
            roiArray = fovmanager.fileio.getrois(sId);
                        
            centerCoords = vertcat(roiArray.center);
            
            % Normalize coordinates between 0 and 1
            centerCoords = centerCoords ./ fliplr(roiArray(1).imagesize);
            
            % Center coordinates on image center
            centerCoords = centerCoords - [0.5, 0.5];
            
            % Scale coordinates to have same units as image.
            centerCoords = centerCoords .* [range(obj.edge(:,1)), range(obj.edge(:,2))];
            
            % Mirror and rotate if necessary
            if obj.orientation.isMirroredX
                centerCoords(:, 1) = -1*centerCoords(:,1);
            end
            
            if obj.orientation.isMirroredY
                centerCoords(:, 2) = -1*centerCoords(:,2);
            end
            
            if obj.orientation.theta ~= 0
                [theta, rho] = cart2pol(centerCoords(:, 1), centerCoords(:, 2));
                theta = theta - deg2rad(obj.orientation.theta);
                [xCoords, yCoords] = pol2cart(theta, rho);
            end
            
            xCoords = xCoords + obj.center(1);
            yCoords = yCoords + obj.center(2);
            
            mapCoords = [xCoords, yCoords];
            
        end
        
        
        function hRois = plotRois(obj)
            
            mapCoords = obj.getRoiMapCoordinates();
            xCoords = mapCoords(:, 1);
            yCoords = mapCoords(:, 2);
            
            hRois = plot(obj.guiHandle, xCoords, yCoords, 'o');
            hRois.Color = 'w';
            hRois.HitTest = 'off';
            hRois.PickableParts = 'none';
            hRois.Tag = 'Roi Centers';

        end
        
        
% % % % Context menu on the gui object in fov manager

        function createContextMenu(obj, fmHandle)
            
            %Make sure to create the context menu in the right figure. No
            %input creates in the current figure
            hFig = fmHandle.hFigure;
            m = uicontextmenu(hFig);
            
            if ~isempty(obj.image)
                mitem = uimenu(m, 'Text', 'Replace Fov Image...');
            else
                mitem = uimenu(m, 'Text', 'Add Fov Image...');
            end
            mitem.Callback = @(src, event) obj.addImage();

            
            mitem = uimenu(m, 'Text', 'Show Fov Image');
            mitem.Callback = @obj.toggleShowHideImage;
            mitem.Enable = 'off';
            
            mitem = uimenu(m, 'Text', 'Set Image Transparency');
            mitem.Callback = @fmHandle.showTransparencySlider;
            mitem.Enable = 'off';
            
            mitem = uimenu(m, 'Text', 'Add Session to FoV', 'Separator', 'on');
            mitem.Callback = @(src, event) fmHandle.addSession;
        
            mitem = uimenu(m, 'Text', 'Remove Session from FoV');
            mitem.Callback = @(src, event) fmHandle.removeSession;
            
            
            mitem = uimenu(m, 'Text', 'Set Current Session');
            
            if ~isempty(obj.listOfSessions)
                obj.updateSessionContextSubmenu(mitem)
            else
                mitem.Enable = 'off';
            end
            
            
            mitem = uimenu(m, 'Text', 'Show Rois', 'Separator', 'on');
            if isempty(obj.listOfSessions)
                mitem.Enable = 'off';
            end
            mitem.Callback = @obj.toggleShowHideRois;

            
            if obj.isMovable
                mitem = uimenu(m, 'Text', 'Lock Position', 'Separator', 'on');
            else
                mitem = uimenu(m, 'Text', 'Unlock Position', 'Separator', 'on');
            end
            mitem.Callback = @obj.togglePositionLock;

            mitem = uimenu(m, 'Text', 'Resize FoV');
            mitem.Callback = @fmHandle.startResizeFov;
            
            mitem = uimenu(m, 'Text', 'Delete FoV', 'Separator', 'on');
            mitem.Callback = @obj.requestdelete;
            
            
            obj.guiHandle.UIContextMenu = m;
            
        end
        
             
        function move(obj, shift, forceMove, updateInfo)
        %move Move a fov on the map.
        %
        %   move(obj, shift, forceMove, updateInfo) is used for moving a
        %   fov on the map. Obj refers to the fov object (self), shift is a
        %   2 element vector of shift in x and y and forceMove & updateInfo
        %   are optional boolean flags. Set forceMove to true to move fov
        %   even if the position of the fov is locked. Set updateInfo to
        %   false to skip updating of the FoV info. The latter is useful
        %   for example when the fov is moved because a window is being
        %   moved, and in this case the fov info is not being displayed.
            
            if nargin < 3; forceMove = false; end
            if nargin < 4; updateInfo = true; end
            
            move@fovmanager.mapobject.BaseObject(obj, shift, forceMove)
            if updateInfo
                obj.updateInfo()
            end
        end
        
        
    end
    
    
    methods (Access = protected)
    
        % % % % Plot Functions
        
        function [xCoords, yCoords] = getBoundaryCoords(obj)
            
            xCoords = obj.edge(:, 1); yCoords = obj.edge(:, 2);
            
            if strcmp( obj.shape, 'circle' )
                rho = min([range(xCoords), range(yCoords) ]) ./ 2;
                theta = deg2rad(1:360);
                rho = ones(size(theta)) * rho;
                [xCoords, yCoords] = pol2cart(theta, rho);
                xCoords = xCoords + obj.center(1);
                yCoords = yCoords + obj.center(2);
                 
                obj.edge = [xCoords', yCoords'];
            end
            
            
        end
        
    end
        
        
    methods (Static)
       
        
        function fovSize = getSize()
            % Get fov size in micrometer based on user input.
            % Todo: Is the rule for dividing max fov size by zoom correct?
            % Should effect of destretching be added?
            % Add support for non-square FoVs?
            
            fovSize = [];
            
            % Todo: save these options in a file..
            zoomFactors = [ 1.0000, 1.1250, 1.2500, 1.3750, 1.5000, ...
                            1.6250, 1.7500, 1.8750, 2.0000, 2.1250, ...
                            2.2500, 2.3750, 2.5000, 2.6250, 2.7500, ...
                            2.8750, 3.0000, 4.0000, 5.0000, 6.0000, ...
                            7.0000, 8.0000, 9.0000, 10.0000 ];
                
            % Create options list
            options = arrayfun(@(z) num2str(z, '%.3f'), zoomFactors, 'uni', 0);
            options = cat(2, {'Load ini-file', 'Load sData'}, options, {'Other Zoom', 'Custom Size'});
            
            % Prompt user to select among options
            [selectedInd, tf] = listdlg(...
                    'PromptString', 'Select Zoom Factor:', ...
                    'SelectionMode', 'single', ...
                    'ListString', options, ...
                    'ListSize', [100, 340]);
            if ~tf; return; end
            choice = options{selectedInd};
            
            % Find zoomfactor based on choice
            switch choice
                case 'Load ini-file'
                    folderPath = uigetdir();
                    S = getSciScanMetaData(folderPath);
                    zoomFactor = S.zoomFactor;
                    
                case 'Load sData'
                    error('Not implemented')
                    % Todo
                case 'Other Zoom'
                    input = inputdlg('Enter Zoom Factor');
                    if isempty(input); return; end
                    zoomFactor = str2double(input);
                case 'Custom Size'
                    input = inputdlg({'Enter Width in um', 'Enter Height in um'});
                    if isempty(input); return; end
                    fovSize = [str2double(input{2}), str2double(input{1})];
                otherwise
                    zoomFactor = str2double(choice);
            end
            
            if isempty(fovSize)
                % Calculate Fov size
                fovSize = 1000 / zoomFactor; % in micrometer
            end
            
        end
        
        
    end
 
    
end