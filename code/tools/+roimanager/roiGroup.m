classdef roiGroup < handle
%roiGroup Class that stores rois and associated data and broadcasts events 
% whenever rois are added, removed or modified.
%
%   This class is used to give shared access to rois across multiple apps 
%   and uses events to let other apps know of changes to the rois.
%
%   It also keeps track of some roi application data, namely
%   roiClassification, roiStats and roiImages.

%   NOTE: 
%   The roiClassification, roiStats and roiImages are "externalized"
%   from the rois for two reasons. 1) they should be customizable, i.e not
%   all rois might not have the same images or stats etc and 2) for
%   scalability. It might be useful to get rois without loading
%   "application" data.
%
%   For these reasons, even though the variables above are added to rois in
%   appdata, it is the job of this class to make sure all rois of a
%   roiarray has the same set of these data when working with rois in
%   applications.


%   Todo: 
%       [ ] Better solution to visible rois. Specifically: Now, everytime a
%           roi is added or removed the filtering for visible rois is reset.
%       [ ] Add channel number and plane number as arguments that can be
%           passed on construction

    properties
        ParentApp = [] % Used for storing undo/redo commands.
    end
    
    properties
        Description
        ChannelNumber = 1
        PlaneNumber = 1
    end
    
    properties (SetAccess = private)
        FovImageSize = [] % Todo: Make dependent
    end
    
    properties (SetAccess = protected) % RoiGroupData...
        roiArray RoI

        % % Should these be private? Dependent? - Should be dependent!
        roiClassification
        roiImages struct % Struct array
        roiStats  struct % Struct array
    end
    
    properties % Preferences
        NextRoiSelectionMode = 'Next in list'
        VisibleClassification = 'All'   % (Todo: Not implemented. Should this be implemented here on the roigroup or on the roidisplays?)
        isActive = true                 % Active (true/false) indicates whether rois should be kept in memory as an object or a struct array.
    end
    
    properties (Dependent, SetAccess = private)
        roiCount            % Number of rois contains in roiGroup
        IsDirty
    end
    
    properties (Access = private)
        isDirty_ = false    % Internal flag for whether roigroup has unsaved changes
    end
    
    events
        roisChanged                     % Triggered when rois are changed
        classificationChanged           % Triggered when roi classifications are changed
        roiSelectionChanged             % Triggered when roi selection is changed...
        VisibleRoisChanged
    end
    
    
    methods % Constructor
        
        function obj = roiGroup(varargin)
        %roiGroup Create a roiGroup object
        %
        %   roiGoupObj = roimanager.roiGroup(filename) creates a roigroup
        %   from file. filename is the absolute filepath for a file
        %   containing roi data.
        %
        %   roiGoupObj = roimanager.roiGroup(roiGroupStuct) creates a 
        %   roigroup
        
            if ~isempty(varargin)

                % Parse inputs. Parser might replace obj (todo: test)
                % obj = parseConstructorInputs(obj, varargin);

                if isa(varargin{1}, 'char')
                    if exist(varargin{1}, 'file')
                        fileAdapter = obj.getFileAdapter(varargin{1});
                        obj = fileAdapter.load();
                    else
                        error('First input is a character vector, but is not a filename for an existing file')
                    end

                elseif isa(varargin{1}, 'RoI')
                    obj.addRois(varargin{1})
                    
                elseif isa(varargin{1}, 'struct') && isfield(varargin{1}, 'roiArray')
                    obj.populateFromStruct(varargin{1})
                    
                elseif isa(varargin{1}, 'struct') && isfield(varargin{1}, 'uid')
                    roiArray = roimanager.utilities.struct2roiarray(varargin{1});
                    obj.addRois(roiArray)
                else

                end
            end
        end

    end

    methods (Access = private) % Methods for construction / initialization
        
        function obj = parseConstructorInputs(obj, varargin)
        %parseConstructorInputs Parse inputs to constructor

            % Check if first input is a valid filepath
            if isa(varargin{1}, 'char')
                if exist(varargin{1}, 'file')
                    fileAdapter = obj.getFileAdapter(varargin{1});
                    obj = fileAdapter.load();
                else
                    error('First input is a character vector, but is not a filename for an existing file')
                end
            
            % Check if first input is a RoI object/object array
            elseif isa(varargin{1}, 'RoI')
                obj.addRois(varargin{1})
                
            % Check if first input is a struct/struct array holding
            % roigroup fields
            elseif isa(varargin{1}, 'struct') && isfield(varargin{1}, 'roiArray')
                obj.populateFromStruct(varargin{1})
                
            % Check if first input is a struct/struct array holding
            % items that can be converted to RoIs         
            elseif isa(varargin{1}, 'struct') && isfield(varargin{1}, 'uid')
                roiArray = roimanager.utilities.struct2roiarray(varargin{1});
                obj.addRois(roiArray)
            else
                
            end
        end
        
    end

    methods % Methods for handling changes on the roiGroup

        function undo(obj)
            if ~isempty(obj.ParentApp) && ~isempty(obj.ParentApp.Figure)
                obj.changeRoiSelection(nan, []) % Note: unselect all rois before executing undo!
                uiundo(obj.ParentApp.Figure, 'execUndo')
            end
        end
        
        function redo(obj)
            if ~isempty(obj.ParentApp) && ~isempty(obj.ParentApp.Figure)
                obj.changeRoiSelection(nan, []) % Note: unselect all rois before executing undo!
                uiundo(obj.ParentApp.Figure, 'execRedo')
            end
        end
        
        function markClean(obj)
            for i = 1:numel(obj)
                obj(i).isDirty_ = false;
            end
        end
        
        function addRois(obj, newRois, roiInd, mode, isUndoRedo)
        % addRois Add new rois to the roiGroup.

            if isempty(newRois); return; end  %Just in case

            if nargin < 4; mode = 'append'; end
            if nargin < 5; isUndoRedo = false; end

            % Check if input is a roigroup or a roiArray.
            % Todo: Parse rois method.
            if isa(newRois, 'roimanager.roiGroup')
                newRois = newRois.roiArray;
            end

            % Count number of rois
            nRois = numel(newRois);
            
            if nargin < 3 || isempty(roiInd)
                roiInd = obj.roiCount + (1:nRois);
            end
            
            if isempty(obj.FovImageSize)
                obj.FovImageSize = newRois(1).imagesize;
            end

            if iscolumn(newRois); newRois = newRois'; end

            if obj.roiCount == 0; mode = 'initialize'; end

            % Convert rois to RoI or struct depending on channel status.
            if obj.isActive
                if isa(newRois, 'struct')
                    newRois = roimanager.utilities.struct2roiarray(newRois);
                end
            else
                if isa(newRois, 'RoI')
                    newRois = roimanager.utilities.roiarray2struct(newRois);
                end
            end

            % Make sure classification is part of userdata
            newRois = obj.initializeRoiClassification(newRois);
            
            % Make sure roi stats are initialized.
            newRois = obj.initializeRoiStats(newRois);

            % Make sure roi images are initialized.
            newRois = obj.initializeRoiImages(newRois);

            % Add rois, either by appending or by inserting into array.
            switch mode
                case 'initialize'
                    obj.roiArray = newRois;
                case 'append'
                    obj.roiArray = horzcat(obj.roiArray, newRois);
                case 'insert'
                    obj.roiArray = utility.insertIntoArray(obj.roiArray, newRois, roiInd, 2);
                case 'replace'
                    assert(numel(obj.roiArray)==numel(newRois), 'The number of rois must be the same as the number which is replaced')
                    obj.roiArray = newRois;
                    roiInd = 1:numel(obj.roiArray);
            end
            
            try
                obj.assignAppdata()
            catch ME
                disp(getReport(ME, 'extended'))
                error('This is a bug, please report...')
            end
            
            if strcmp(mode, 'replace')
                %return %Todo, make sure this is not misused. I.e what if rois that are replaced are different...
            end
            
            % Notify that rois have changed
            % fprintf('\nIndex pre event notification: %d\n', roiInd) % debug 
            eventData = roimanager.eventdata.RoiGroupChanged(newRois, roiInd, mode);
            obj.notify('roisChanged', eventData)
            
            % Update roi relations. (i.e if rois are added that have 
            % relations). Relevant if there was an undo/redo action.
            % This needs to be done after all rois are added.
            obj.updateRoiRelations(newRois, 'added')
            
            % Register the action with the undo manager
            if ~isUndoRedo && ~isempty(obj.ParentApp) && ~isempty(obj.ParentApp.Figure)
                cmd.Name            = 'Add Rois';
                cmd.Function        = @obj.addRois;       % Redo action
                cmd.Varargin        = {newRois, roiInd, mode, true};
                cmd.InverseFunction = @obj.removeRois;    % Undo action
                cmd.InverseVarargin = {roiInd, true};

                uiundo(obj.ParentApp.Figure, 'function', cmd);
            end
            
            obj.isDirty_ = true;
        end
        
        function modifyRois(obj, modifiedRois, roiInd, isUndoRedo)
        %modifyRois Modify the shape of rois.
        
            if nargin < 4; isUndoRedo = false; end

            originalRois = obj.roiArray(roiInd);
            
            if iscolumn(roiInd); roiInd = transpose(roiInd); end
            
            cnt = 1;
            for i = roiInd
                % Todo: Clean up this mess!
                iRoi = modifiedRois(cnt);
                obj.roiArray(i) = obj.roiArray(i).reshape(iRoi.shape, iRoi.coordinates);
                obj.roiArray(i) = setappdata(obj.roiArray(i), 'roiImages', getappdata(modifiedRois(cnt), 'roiImages') );
                obj.roiArray(i) = setappdata(obj.roiArray(i), 'roiStats', getappdata(originalRois(cnt), 'roiStats') );
                obj.roiArray(i) = setappdata(obj.roiArray(i), 'roiClassification', getappdata(originalRois(cnt), 'roiClassification') );

                cnt = cnt+1;
            end
            
            % Use assignAppdata instead?
            obj.roiImages = getappdata(obj.roiArray, 'roiImages');
            obj.roiStats = getappdata(obj.roiArray, 'roiStats');
            
            eventData = roimanager.eventdata.RoiGroupChanged(obj.roiArray(roiInd), roiInd, 'modify');
            obj.notify('roisChanged', eventData)
            
            % Register the action with the undo manager
            if ~isUndoRedo && ~isempty(obj.ParentApp) && ~isempty(obj.ParentApp.Figure)
                cmd.Name            = 'Modify Rois';
                cmd.Function        = @obj.modifyRois;      % Redo action
                cmd.Varargin        = {modifiedRois, roiInd, true};
                cmd.InverseFunction = @obj.modifyRois;         % Undo action
                cmd.InverseVarargin = {originalRois, roiInd, true};

                uiundo(obj.ParentApp.Figure, 'function', cmd);
            end

            obj.isDirty_ = true;
        end
        
        function removeRois(obj, roiInd, isUndoRedo)
        %removeRois Remove rois from the roiGroup.
        
            if nargin < 2; roiInd = 1:obj.roiCount; end
            if nargin < 3; isUndoRedo = false; end
            
            roiInd = sort(roiInd);
            removedRois = obj.roiArray(roiInd);
            
            if isUndoRedo
                % Remove selection of all rois if this was a undo/redo
                obj.changeRoiSelection(nan, []) % Note: unselect all rois before executing undo!
            end
            
            obj.roiArray(roiInd) = [];
            
            % Update the appdata properties.
            obj.assignAppdata()

            eventData = roimanager.eventdata.RoiGroupChanged([], roiInd, 'remove');
            obj.notify('roisChanged', eventData)
            
            % Update roi relations. (i.e if rois are removed that have 
            % relations). Relevant if there was an undo/redo action for 
            % example. This needs to be done after all rois are removed.
            obj.updateRoiRelations(removedRois, 'removed')
            
            % Register the action with the undo manager
            if ~isUndoRedo && ~isempty(obj.ParentApp) && ~isempty(obj.ParentApp.Figure)
                cmd.Name            = 'Remove Rois';
                cmd.Function        = @obj.removeRois;      % Redo action
                cmd.Varargin        = {roiInd, true};
                cmd.InverseFunction = @obj.addRois;         % Undo action
                cmd.InverseVarargin = {removedRois, roiInd, 'insert', true};

                uiundo(obj.ParentApp.Figure, 'function', cmd);
            else
                % Remove selection of all rois if this was a undo/redo
                obj.changeRoiSelection(nan, []) % Note: unselect all rois before executing undo!
            end
            
            obj.isDirty_ = true;
        end
        
        function roiLabels = getRoiLabels(obj, roiInd)
            
            numRois = obj.roiCount;
            charLength = ceil( log10(numRois+1) );
            formatStr = sprintf(' %%0%dd', charLength);

            tags = {obj.roiArray(roiInd).tag};
            nums = strsplit( num2str(roiInd, formatStr), ' ');

            roiLabels = strcat(tags, nums); 
        end

        function roiInd = getNextRoiInd(obj, currentRoiInd, direction, selectionMode)
        %getNextRoiInd Get next roi index dependent on trajectory type
        %
        % INPUTS:
        %   currentRoiInd : index for the current roi
        %   direction     : 'forward' or 'backward'
        %   selectionMode : what "type" of roi to select next. Can be:
        %       - 'with same classification'
        %       - 'Next unclassified roi'
        %       - 'Closest' (euclidian distance)
        %       - 'None'
        
            if nargin < 3 || isempty(direction)
                direction = 'forward';
            end
            
            if nargin < 4 || isempty(selectionMode)
            	selectionMode = obj.NextRoiSelectionMode;
            end
            
            if strcmp(selectionMode, 'None')
                roiInd = []; return
            end
            
            currentRoi = obj.roiArray(currentRoiInd);

            if contains(selectionMode, 'with same classification')
            % Limit roi candidates for selection to rois that have the same
            % tag as current roi.
            
                thisClsf = getappdata(currentRoi, 'roiClassification');
                allClsf = getappdata(obj.roiArray, 'roiClassification');
                
                roiIndCandidates = find(allClsf == thisClsf);
            
            elseif strcmp(selectionMode, 'Next unclassified roi')
                allClsf = getappdata(obj.roiArray, 'roiClassification');
                roiIndCandidates = find(allClsf == 0);
            else
                roiIndCandidates = 1:obj.roiCount;
            end
            
            if iscolumn(roiIndCandidates)
                roiIndCandidates = transpose(roiIndCandidates);
            end
                
            roiIndCandidates = unique( [roiIndCandidates, currentRoiInd] );
            
            if contains(selectionMode, 'Closest')
            % Sort list of candidates by their distance from current roi
                
                centerCoords = cat(1, obj.roiArray.center);
                
                deltaX = currentRoi.center(1) - centerCoords(:,1);
                deltaY = currentRoi.center(2) - centerCoords(:,2);

                % Absolute distance:
                distance = hypot(deltaX, deltaY);
                distance = distance(roiIndCandidates);
                
                % Add a direction to the distance metric. Go from left to
                % right, but split in two rows. %TODO Add a 1 dimensional
                % metric, so that each roi is connected to one other along
                % a 1D space.
                sgnX = sign( centerCoords(roiIndCandidates,1) - currentRoi.center(1));
                
                distance = sgnX .* distance;
                
                [~, sortInd] = sort(distance);
                roiIndCandidates = roiIndCandidates(sortInd);
                roiIndCandidates = transpose(roiIndCandidates); % make row vector
            end
            
            if strcmp(direction, 'backward')
                roiIndCandidates = fliplr(roiIndCandidates);
            end
            
            % Select the next roi among candidates.
            matchInd = find(roiIndCandidates == currentRoiInd);

            if matchInd == numel(roiIndCandidates)
                roiInd = roiIndCandidates(1); % Go to beginning...
            else
                roiInd = roiIndCandidates(matchInd+1);
            end
        end

        function changeRoiSelection(obj, oldSelection, newSelection, origin)
        %changeRoiSelection Method to notify a roiSelectionChanged event
        %
        % INPUTS:
        %   oldSelection : indices of rois that were selected before.
        %   newSelection : indices of rois that are newly selected.
        %   origin       : the class/interface that origninated this call
        
            if nargin < 4; origin = []; end
            
            getEventData = @roimanager.eventdata.RoiSelectionChanged;
            eventData = getEventData(oldSelection, newSelection, origin);
            obj.notify('roiSelectionChanged', eventData)
        end

        function changeVisibleRois(obj, newSelection, eventType)
            if nargin < 3; eventType = []; end
            
            % Filter selection by current classification state
            %newSelection = obj.filterByCurrentClassification(newSelection);
            
            eventData = uiw.event.EventData('NewVisibleInd', newSelection, ...
                'Type', eventType);
            obj.notify('VisibleRoisChanged', eventData)
        end
        
        function ind = filterByCurrentClassification(obj, ind)
            
            clsf = obj.roiClassification;
                        
            switch obj.VisibleClassification % Todo: Should read cases from some config...
                case 'All'
                    isVisibleRoi = clsf >= 0;
                case 'Unclassified'
                    isVisibleRoi = clsf == 0;
                case 'Accepted'
                    isVisibleRoi = clsf == 1;
                case 'Rejected'
                    isVisibleRoi = clsf == 2;
                case 'Unresolved'
                    isVisibleRoi = clsf == 3;
            end
            
            ind = intersect(ind, find(isVisibleRoi));
        end
        
        function setRoiClassification(obj, roiInd, newClass)
            %mode: add, insert, append...
            
            obj.roiArray(roiInd) = setappdata(obj.roiArray(roiInd), ...
                'roiClassification', newClass);
            
            evtData = roimanager.eventdata.RoiClsfChanged(roiInd, newClass);
            obj.roiClassification(roiInd) = newClass;
            obj.notify('classificationChanged', evtData)
            
            obj.isDirty_ = true;
        end
        
        function connectRois(obj, parentInd, childInd)
            
            childRois = obj.roiArray(childInd);
            parentRoi = obj.roiArray(parentInd);
            
            obj.roiArray(parentInd) = parentRoi.addChildren(childRois);
            
            for i = childInd
                obj.roiArray(i) = obj.roiArray(i).addParent(parentRoi);
            end
            
            eventData = roimanager.eventdata.RoiGroupChanged(parentRoi, [parentInd,childInd], 'connect');
            obj.notify('roisChanged', eventData)
            
            % Todo: Add as action to undomanager.
        end
        
        function disconnectRois(obj)
            % todo
        end
        
        function updateRoiRelations(obj, updatedRois, action)
        %updateRoiRelations Update relations in roi array, if rois with 
        % relations are added or removed.
        
            allRoiUid = {obj.roiArray.uid};
            if isempty(allRoiUid); return; end
            
            % Temp function for checking property of all rois in
            % roiarray... Should be a method of RoI...?
            isPropEmpty = @(prop) arrayfun(@(roi) isempty(roi.(prop)), updatedRois);
            
            % Find all rois that are parents or children among updated rois
            parentInd = find( ~isPropEmpty('connectedrois') );
            childInd = find( ~isPropEmpty('parentroi') );
            
            if isempty(parentInd) && isempty(childInd); return; end
            
            switch action
                case 'added'
                    parentAction = 'addChildren';       % Add child to parent
                    childAction = 'addParent';          % Add parent to all children
                case 'removed'
                    parentAction = 'removeChildren';    % Remove child from parent
                    childAction = 'removeParent';       % Remove parent from children. Kind of sad considering this is 2020...
            end
            
            % Add/remove parent to/from children
            for i = 1:numel(parentInd)
                parentRoi = updatedRois(parentInd(i));
                [~, chInd] = intersect(allRoiUid, parentRoi.connectedrois);
                if iscolumn(chInd); chInd = transpose(chInd); end
                for j = chInd
                    obj.roiArray(j) = obj.roiArray(j).(childAction)(parentRoi);
                end
            end
            
            % Add/remove children to/from parent
            for i = 1:numel(childInd)
                childRoi = updatedRois(childInd(i));
                [~, j] = intersect(allRoiUid, childRoi.parentroi);
                if ~isempty(j)
                    obj.roiArray(j) = obj.roiArray(j).(parentAction)(childRoi);
                end
            end
            
            % For simplicity, just notify that all rois are updated and do a 
            % relink. Relations are plotted on children references, but if
            % parent has been readded, this needs to be updated on children
            % that are already existing. Therefore, the relink, which will
            % flush and update all relations. 
            evtDataCls = @roimanager.eventdata.RoiGroupChanged;
            eventData = evtDataCls(obj.roiArray, 1:obj.roiCount, 'relink');
            obj.notify('roisChanged', eventData)
        end
        
    end
    
    methods % Methods for saving rois
        
        function [wasSuccess, savePath] = saveRois(obj, savePath)
            
            import nansen.dataio.fileadapter.roi.RoiGroup
                        
            if nargin < 2; savePath = ''; end
            
            fileObj = nansen.dataio.fileadapter.roi.RoiGroup(savePath);
            if isempty(savePath)
                wasSuccess = fileObj.uiput();
                if ~wasSuccess; return; end
            end
            
            fileObj.save(obj)
            obj.markClean()
            
            wasSuccess = true;    
            
            if nargout == 1
                clear savePath
            elseif nargout == 0
                clear wasSuccess savePath
            end

            saveMsg = sprintf('Rois Saved to %s', savePath);
            obj.PrimaryApp.displayMessage(saveMsg, 2)
                        
            obj.roiFilePath = savePath;
        end
        
    end
    
    methods
        
        function roiCount = get.roiCount(obj)
            roiCount = numel(obj.roiArray);
        end

        function set.VisibleClassification(obj, newValue)
            
        end
        
        function isDirty = get.IsDirty(obj)
            if obj.roiCount == 0
                isDirty = false;
            else
                isDirty = obj.isDirty_;
            end
        end
        
        function tf = validateForClassification(obj)
            
            %temporary to get things up and running
            
            tf = false(1,3);
            
            fields = {'roiImages', 'roiStats', 'roiClassification'};
            
            for i = 1:numel(fields)
            
                D = obj.roiArray.getappdata(fields{i});
                
                if numel(D) == obj.roiCount
                    obj.(fields{i}) = D;
                    tf(i) = true;
                end
                
            end
            
            if isempty(obj.roiClassification)
                obj.roiClassification = zeros(size(obj.roiArray));
                obj.roiArray = setappdata(obj.roiArray, 'roiClassification', ...
                    obj.roiClassification);
                tf(3) = true;
            end
            
            tf = all(tf);
        end
        
    end
    

    methods (Access = protected)

        function tf = isUiUndoSupported(obj)
            
            hasApp = ~isempty(obj.ParentApp);

            if hasApp
                tf = isprop(obj.ParentApp, 'Figure') && ...
                                ~isempty(obj.ParentApp.Figure) && ...
                                    isvalid(obj.ParentApp.Figure);
            else
                tf = false;
            end
        end

    end

    methods (Access = private)
        
        function assignAppdata(obj)
        %assignAppdata Assign roi appdata to properties of this object 
            if obj.roiCount > 0
                obj.roiClassification = getappdata(obj.roiArray, 'roiClassification');
                obj.roiImages = getappdata(obj.roiArray, 'roiImages');
                obj.roiStats = getappdata(obj.roiArray, 'roiStats');
            else
                obj.roiClassification = [];
                obj.roiImages = [];
                obj.roiStats = [];
            end
        end
        
        function populateFromStruct(obj, S)
        %populateFromStruct Assign properties from fields of a struct  
           
            fields = fieldnames(S);
            numRois = numel(S.roiArray);
            
            for i = 1:numel(fields)
                switch fields{i}
                    case 'roiArray'
                        obj.addRois(S.roiArray)
                    case 'roiImages'
                        if numel(S.roiImages) == numRois
                            obj.roiImages = S.roiImages;                            
                        end
                    case 'roiStats'
                        if numel(S.roiStats) == numRois
                            obj.roiStats = S.roiStats;
                        end
                    case 'roiClassification'
                        if numel(S.roiClassification) == numRois
                            obj.roiClassification = S.roiClassification;
                        end
                    case 'ChannelNumber'
                        obj.ChannelNumber = S.ChannelNumber;
                    case 'PlaneNumber'
                        obj.PlaneNumber = S.PlaneNumber;
                end
            end
                        
            if isempty(obj.roiClassification)
                obj.roiClassification = zeros(size(obj.roiArray));
            end
            
            obj.roiArray = setappdata(obj.roiArray, 'roiClassification', obj.roiClassification);
            obj.roiArray = setappdata(obj.roiArray, 'roiImages', obj.roiImages);
            obj.roiArray = setappdata(obj.roiArray, 'roiStats', obj.roiStats);
        end
    end
    
    methods (Access = private)

        function roiArray = initializeRoiClassification(~, roiArray)
        %initializeRoiClassification Initialize roi classification for roi
        
            % Add the 0 classification if roi does not have a
            % classification
            for i = 1:numel(roiArray)
                if isempty(getappdata(roiArray(i), 'roiClassification'))
                    roiArray(i) = setappdata(roiArray(i), 'roiClassification', 0);
                end
            end
        end
        
        function roiArray = initializeRoiStats(obj, roiArray)
        %initializeRoiStats Initialize roi stats for roi
            
            if obj.roiCount == 0; return; end
            
            referenceStats = getappdata(obj.roiArray(1), 'roiStats');
            if isempty(referenceStats); return; end
            
            blankStats = utility.struct.clearvalues( referenceStats, true );
            
            for i = 1:numel(roiArray)
                if isempty(getappdata(roiArray(i), 'roiStats'))
                    roiArray(i) = setappdata(roiArray(i), 'roiStats', blankStats);
                end
            end
        end
        
        function roiArray = initializeRoiImages(obj, roiArray)
        %initializeRoiImages Initialize roi images for roi
            
            if obj.roiCount == 0; return; end
            
            referenceImages = getappdata(obj.roiArray(1), 'roiImages');
            if isempty(referenceImages); return; end
            
            blankImages = utility.struct.clearvalues( referenceImages, true );
            
            for i = 1:numel(roiArray)
                if isempty(getappdata(roiArray(i), 'roiImages'))
                    roiArray(i) = setappdata(roiArray(i), 'roiImages', blankImages);
                end
            end
        end
    end

    methods (Static)
        function fileAdapter = getFileAdapter(filePath)
            fileAdapter = nansen.dataio.fileadapter.roi.RoiGroup(filePath); 
        end 
    end

end