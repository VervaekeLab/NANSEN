classdef CompositeRoiGroup < roimanager.roiGroup
%CompositeRoiGroup Class for dynamically combining RoiGroups in apps
%
%   This class is a "quick response" to the need for having multiple
%   "active" roi groups in an app, and being able to mix and match which
%   groups are active at any given time.
%   
%   From the outside, this class should appear and behave like a single 
%   roi group, but internally, each individual roi group keeps it's
%   identity. Methods are modified so that they loop over individual roi
%   groups and invokes that groups corresponding method. The main
%   difference being that the undo/redo functionality has to be managed by 
%   this class and the undo/redo is executed on static methods
%
%   This is important for a couple of reasons:
%       1) When modifying rois from multiple roi groups, a redo operation
%       needs to be applied to all rois from different groups in one go.
%       That would not be possible if looping over roi groups.
%       2) An object of this class will be transient, i.e when it will be
%       destroyed if a user changes channels in the parent app. Therefore,
%       undo/redo execution has to be applied using static methods.

    % Todo:
    %   [ ] Override addRois, removeRois

    properties (SetAccess = immutable, GetAccess = private)
        RoiGroupArray
    end

    % Properties for keeping track of which roi belongs to which group and
    % what index it has within that group
    properties (Access = private)
        RoiGroupIndex       % Vector of indices specifying which group a roi belongs to.
        RoiIndexInGroup
    end

    properties (Access = private)
        IndividualRoiGroupChangedListener event.listener
    end

    methods % Constructor

        function obj = CompositeRoiGroup(roiGroupArray)
            obj.RoiGroupArray = roiGroupArray;
            
            obj.roiArray = cat(2, obj.RoiGroupArray.roiArray);

            if obj.roiCount > 0
                % Update roi array property based on all individual roi groups.
                obj.roiImages = getappdata(obj.roiArray, 'roiImages');
                obj.roiStats = getappdata(obj.roiArray, 'roiStats');       
                obj.roiClassification = getappdata(obj.roiArray, 'roiClassification'); 
            end

            obj.ParentApp = obj.RoiGroupArray(1).ParentApp;
            obj.assignRoiGroupIndex()
            
            for i = 1:numel(roiGroupArray)
                obj.IndividualRoiGroupChangedListener(i) = event.listener(roiGroupArray(i), ...
                    'roisChanged', @(s, e, idx) obj.individualRoiGroupModified(e,i));
            end
        end
        
    end

    methods (Access = public)
        
        function addRois(~, ~, ~, ~, ~)
            errordlg('Can not add rois when viewing multiple channels, please select one channel to add rois.')
            error('Nansen:NotImplementedYet', 'Can not add rois to a collection of roi groups')
        end

        function removeRois(~, ~, ~, ~, ~)
            error('Nansen:NotImplementedYet', 'Can not remove rois from a collection of roi groups')
        end

        function modifyRois(obj, modifiedRois, roiInd, ~)
            
            % Todo: Run superclass methods
            % Update modified rois in roiarrays of each roi group...
            isUndoRedo = false;

            % Get rois and roi inds per roigroup...
            originalRois = obj.roiArray(roiInd);
        
            tempRoiGroupIdx = obj.RoiGroupIndex(roiInd);
            tempRoiIndInGroup = obj.RoiIndexInGroup(roiInd);

            affectedRoiGroupIdx = unique( tempRoiGroupIdx );
            numAffectedRoiGroups = numel(affectedRoiGroupIdx);
            
            roiDataPerGroup = cell(numAffectedRoiGroups, 4);

                       
            % Update roi array before the update of indivisual roi groups 
            % (poor design, should be adressed).
            obj.roiArray(roiInd) = modifiedRois;
            obj.roiImages = getappdata(obj.roiArray, 'roiImages');
            obj.roiStats = getappdata(obj.roiArray, 'roiStats');       
            obj.roiClassification = getappdata(obj.roiArray, 'roiClassification');   


            count = 0;
            for i = affectedRoiGroupIdx
                count = count + 1;

                % Get indices belonging th current group...
                isThisGroup = tempRoiGroupIdx == i;

                thisModifiedRois = modifiedRois(isThisGroup);
                thisRoiInd = tempRoiIndInGroup(isThisGroup);
                
                % Call modify roi, but set the isUndoRedo flag to true to
                % avoid registering the undo/redo per group
                obj.RoiGroupArray(i).modifyRois(thisModifiedRois, thisRoiInd, true)
                
                roiDataPerGroup{count, 1} = obj.RoiGroupArray(i);
                roiDataPerGroup{count, 2} = originalRois(isThisGroup);
                roiDataPerGroup{count, 3} = thisModifiedRois;
                roiDataPerGroup{count, 4} = thisRoiInd;
            end
            
            % Create struct array for uiundo
            roiDataPerGroup = cell2struct(roiDataPerGroup, ...
                {'roiGroup', 'oldRois', 'newRois', 'roiInd'}, 2);    

            % Register with undo manager...
            if ~isUndoRedo && obj.isUiUndoSupported
                obj.registerUndoAction('modifyRois', 'modifyRois', roiDataPerGroup)
            end
        end

        function setRoiClassification(obj)
            % Todo: Run superclass methods
            % Update classification of rois in each roi group...
        end

    end
    
    methods (Access = private)

        function individualRoiGroupModified(obj, eventData, thisRoiGroupIdx)

            % Transform roi indices from group to composite group indices
            roiIndInThisGroup = eventData.roiIndices;

            isThisGroup = obj.RoiGroupIndex == thisRoiGroupIdx;
            isMatchingRoiIdx = ismember(obj.RoiIndexInGroup, roiIndInThisGroup);
            
            roiInd = find(isThisGroup & isMatchingRoiIdx);
            
            fprintf('debug this (compositeRoiGroup/individualRoiGroupModified)\n');
            eventData = roimanager.eventdata.RoiGroupChanged(...
                eventData.roiArray, roiInd, 'modify');
% %             eventData = roimanager.eventdata.RoiGroupChanged(...
% %                 eventData.roiArray, roiInd, eventData.eventType);
            obj.notify('roisChanged', eventData)
        end

    end

    methods (Access = private)
        
        function assignRoiGroupIndex(obj)
        %assignRoiGroupIndex Assign properties keeping track of indices
        %
        %   Keep track of group indices for concatenated (flattened)
        %   vectors of rois.
        %
        %   RoiGroupIndex : For each roi, which group does it belong to
        %   RoiIndexInGroup : For each roi, which index does it have in its 
        %   group
 
            % - Count number of rois per roigroup
            numRois = arrayfun(@(rg) rg.roiCount, obj.RoiGroupArray);
            
            if sum(numRois) == 0; return; end

            transitionIdx = cumsum([1, numRois(1:end-1)]);

            indexVectorInit = zeros(1, sum( numRois ));
            indexVectorInit(transitionIdx) = 1;
            if numel(indexVectorInit) > numRois
                indexVectorInit = indexVectorInit(1:numRois);
            end
            obj.RoiGroupIndex = cumsum(indexVectorInit);

            roiIndexPerGroup = arrayfun(@(n) 1:n, numRois, 'uni', 0);
            obj.RoiIndexInGroup = cat(2, roiIndexPerGroup{:});
        end

        function registerUndoAction(obj, funcNameUndo, funcNameRedo, roiGroupStruct)
            
            hFigure = obj.ParentApp.Figure;

            %inputs: cell array (or struct array) for each roigroup, 
            % containing  modifiedRois, originalRois, roiInd

            % build command for undo/redo...
            
            [oldData, newData] = deal(roiGroupStruct);

            [oldData(:).rois] = oldData(:).oldRois;
            [newData(:).rois] = newData(:).newRois;

            oldData = rmfield(oldData, {'oldRois', 'newRois'});
            newData = rmfield(newData, {'oldRois', 'newRois'});

            cmd.Name            = 'Modify Rois';
            cmd.Function        = @roimanager.CompositeRoiGroup.executeRedo;
            cmd.Varargin        = {funcNameRedo, newData};
            cmd.InverseFunction = @roimanager.CompositeRoiGroup.executeUndo;
            cmd.InverseVarargin = {funcNameUndo, oldData};

            uiundo(hFigure, 'function', cmd);
        end

    end

    methods (Static)

        function executeUndo(functionName, groupArgsAsArray)

            for i = 1:numel(groupArgsAsArray)
                iStruct = groupArgsAsArray(i);
                thisGroup = iStruct.roiGroup; %#ok<NASGU> 

                func = str2func( sprintf(functionName) );
                func(thisGroup, iStruct.rois, iStruct.roiInd, true)
                disp(i)
            end
        end

        function executeRedo(functionName, groupArgsAsArray)
            for i = 1:numel(groupArgsAsArray)
                iStruct = groupArgsAsArray(i);
                thisGroup = iStruct.roiGroup; %#ok<NASGU> 

                func = str2func( sprintf(functionName) );
                func(thisGroup, iStruct.rois, iStruct.roiInd, true)
                disp(i)
            end
        end

        function applyUndoToAllGroups()
            % TODO: Combine methods above
        end

    end
end