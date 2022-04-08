classdef roiGroup < handle
%roiGroup Class that stores rois and associated data and broadcasts events 
% whenever rois are added, removed or modified.
%
%   This class is used to give shared access to rois across multiple apps 
%   and uses events to let other apps know of changes to the rois.


%   Er det i orden at roi thumbnail bilder og stats lagres her...?
%   Det er UserData... Skal jeg lage en userdata egenskap?
%
%   For: Da følger disse dataene roien. Fleksibilitet
%   Mot: Ikke elegant? Rotete


    properties
        ParentApp = [] % Used for storing undo/redo commands.
        FovImageSize = []
    end
    
    properties
        Description
    end
    
    properties (SetAccess = private)
        roiArray RoI
        roiCount = 0

        % % Should these be private? Dependent?
        roiClassification
        roiImages struct % Struct array
        roiStats  struct % Struct array
    end
    
    properties 
        isActive = true                 % Active (true/false) indicates whether rois should be kept in memory as an object or a struct array.
    end
    
    properties (Dependent, SetAccess = private)
        IsDirty
    end
    properties (Access = private)
        isDirty_ = false    % Internal flag for whether roigroup has unsaved changes
    end
    
    events
        roisChanged                     % Triggered when rois are changed
        classificationChanged           % Triggered when roi classifications are changed
        roiSelectionChanged             % Triggered when roi selection is changed...
    end
    
    
    methods % Methods for handling changes on the roiGroup
        
        function obj = roiGroup(varargin)
        %roiGroup Create a roiGroup object
        %
        %   roiGoupObj = roimanager.roiGroup(filename) creates a roigroup
        %   from file. filename is the absolute filepath for a file
        %   containing roi data.
        
        
            if ~isempty(varargin)
            
                if isa(varargin{1}, 'char')
                    if exist(varargin{1}, 'file')
                        %todo: load file
                    else
                        %todo: throw error/warning.
                    end

                elseif isa(varargin{1}, 'RoI')
                    obj.addRois(varargin{1})
                    obj.assignAppdata()
                    
                elseif isa(varargin{1}, 'struct') && isfield(varargin{1}, 'roiArray')
                    obj.populateFromStruct(varargin{1})
                    
                elseif isa(varargin{1}, 'struct') && isfield(varargin{1}, 'uid')
                    roiArray = roimanager.utilities.struct2roiarray(varargin{1});
                    obj.addRois(roiArray)
                    obj.assignAppdata()
                else
                    
                end
                
            end
            
        end
        
        function assignAppdata(obj)
            if obj.roiCount > 0
                obj.roiImages = getappdata(obj.roiArray, 'roiImages');
                obj.roiStats = getappdata(obj.roiArray, 'roiStats');
                obj.roiClassification = getappdata(obj.roiArray, 'roiClassification');
            end
        end
        
        function populateFromStruct(obj, S)
        %populateFromStruct     
           
            % Todo: verify that images, stats and classification is same
            % length as roi array.
            
            fields = fieldnames(S);
            
            for i = 1:numel(fields)
                switch fields{i}
                    case 'roiArray'
                        obj.addRois(S.roiArray)
                    case 'roiImages'
                        obj.roiImages = S.roiImages;
                    case 'roiStats'
                        obj.roiStats = S.roiStats;
                    case 'roiClassification'
                        obj.roiClassification = S.roiClassification;
                end
            end
            
            if isempty(obj.roiClassification)
                obj.roiClassification = zeros(size(obj.roiArray));
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
            obj.isDirty_ = false;
        end
        
        function addRois(obj, newRois, roiInd, mode, isUndoRedo)
        % addRois Add new rois to the roiGroup.

            if isempty(newRois); return; end  %Just in case
        
            if nargin < 5; isUndoRedo = false; end
            
            if isempty(obj.FovImageSize)
                obj.FovImageSize = newRois(1).imagesize;
            end
            
            % Count number of rois
            nRois = numel(newRois);
            
            if iscolumn(newRois); newRois = newRois'; end

            if nargin < 4; mode = 'append'; end
            
            if nargin < 3 || isempty(roiInd)
                roiInd = obj.roiCount + (1:nRois);
            end
            
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
            for i = 1:numel(newRois)
                if isempty(getappdata(newRois(i), 'roiClassification'))
                    newRois(i) = setappdata(newRois(i), 'roiClassification', 0);
                end
            end

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
                    
            end
            
            try
            obj.roiClassification = getappdata(obj.roiArray, 'roiClassification');
            obj.roiImages = getappdata(obj.roiArray, 'roiImages');
            obj.roiStats = getappdata(obj.roiArray, 'roiStats');
            end
            
            if strcmp(mode, 'replace')
                return %Todo, make sure this is not misused. I.e what if rois that are replaced are different...
            end
            
            % Update roicount. This should happen before plot, update listbox 
            % and modify signal array:
            obj.roiCount = numel(obj.roiArray); %obj.roiCount + nRois;
            
            % Notify that rois have changed
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

            origRois = obj.roiArray(roiInd);
            
            if iscolumn(roiInd); roiInd = transpose(roiInd); end
            
            cnt = 1;
            for i = roiInd
                % Todo: Clean up this mess!
                obj.roiArray(i) = obj.roiArray(i).reshape('Mask', modifiedRois(cnt).mask);
                obj.roiArray(i) = setappdata(obj.roiArray(i), 'roiImages', getappdata(modifiedRois(cnt), 'roiImages') );
                obj.roiArray(i) = setappdata(obj.roiArray(i), 'roiStats', getappdata(modifiedRois(cnt), 'roiStats') );
                
                im = getappdata(obj.roiArray(i), 'roiImages');
                if ~isempty(im)
                    obj.roiArray(i).enhancedImage = im.enhancedAverage;
                end
                cnt = cnt+1;
            end
            
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
                cmd.InverseVarargin = {origRois, roiInd, true};

                uiundo(obj.ParentApp.Figure, 'function', cmd);
            end
            
            obj.isDirty_ = true;

        end
        
        function removeRois(obj, roiInd, isUndoRedo)
        %removeRois Remove rois from the roiGroup.
        
            if nargin < 3; isUndoRedo = false; end
            
            roiInd = sort(roiInd);
            removedRois = obj.roiArray(roiInd);
            
            if isUndoRedo
                % Remove selection of all rois if this was a undo/redo
                obj.changeRoiSelection(nan, []) % Note: unselect all rois before executing undo!
            end
            
            for i = fliplr(roiInd) % Delete from end to beginning.
                obj.roiArray(i) = [];
            end
            obj.roiCount = numel(obj.roiArray);
            
            if ~isempty(obj.roiArray)
                obj.roiClassification = getappdata(obj.roiArray, 'roiClassification');
                obj.roiImages = getappdata(obj.roiArray, 'roiImages');
                obj.roiStats = getappdata(obj.roiArray, 'roiStats');
            else
                obj.roiClassification = [];
                obj.roiImages = [];
                obj.roiStats = [];
            end
            
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

        function setRoiClassification(obj, roiInd, newClass)
            %mode: add, insert, append...
            
            obj.roiArray(roiInd) = setappdata(obj.roiArray(roiInd), ...
                'roiClassification', newClass);
            
            evtData = roimanager.eventdata.RoiClsfChanged(roiInd, newClass);
            obj.roiClassification(roiInd) = newClass;
            obj.notify('classificationChanged', evtData)
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

    methods
        function isDirty = get.IsDirty(obj)
            if obj.roiCount == 0
                isDirty = false;
            else
                isDirty = obj.isDirty_;
            end
        end
    end
    
end