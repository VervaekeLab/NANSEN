classdef MultiSessionRoiCollection < handle
%MultiSessionRoiCollection is a class for managing rois of multiple sessions.
%
%   The purpose of this class is to store RoIs for each session of a set of
%   longitudinal sessions and provide methods for keeping rois synched
%   across sessions. If a RoI array from one session is updated, the user
%   can use the updateEntry method in order to update the rois for this session 
%   and then use synchEntries to update roi arrays from all other sessions to 
%   reflect the changes to that specific roi array. I.e if five new rois were
%   added, now these rois will be added across all sessions. The class will
%   use the existing rois of each session to interpolate the position in
%   which to place new ones.
%
%   Useful methods:
%       - updateEntry
%       - synchEntries


% NOTE: The RoIArray property can be either an array of RoIs or a cell
% array or arrays of RoIs. The latter is the case if sessions have multiple
% imaging channels. This could be expanded to also work for longitudinal
% multi-plane recordings, but it requires a modified approach to aligning
% each FoV, as FoVs for planes needs to be aligned separately. The class
% will in some cases flatten roi cell arrays for some operations and then
% unflatten again afterwards.

% Todo:
%   [ ] Add save method and save as a struct array
%   [ ] Add static load method, and initialize from calling it.
%   [ ] Use catalog?
%   [ ] Add methods for updating on the fly
%   [ ] Add configurable options for how to align fov images to compute roi
%       translations.

% How do updateEntries, updateRoisFromReference and synchEntries differ? Can
% some parts of the methods be combined (not urgent)?

% + updateRoisFromReference : 
%       - Duplicate and reposition rois that are present on reference roi
%         array and copy to the "target" session
%       - Check if unique rois from reference session are overlapping with
%         rois from target session, and change uuid for rois in target
%         session where this is true.
%
% + updateEntry (merge)
%       - Compare old rois for entry with new incoming rois...
%         (Almost same as updateRoisFromReference, but in this method
%         overlapping rois are removed, whereas in updateRoisFromReference
%         new rois inheriting uuids from reference if possible....
%
% + synchEntries
%       - Update all objects from a source. 


%   Proposed properties
%       SynchMode = 'Only Add', 'Mirror'
%       UpdateMode = 'replace', 'merge', 'update' % Mode for updating a set of rois
%           'replace' the existing rois with new ones
%           'merge' merge the new rois into existing
%           'update' update existing rois from reference session

%       FovRegistrationMethod...
%       FovRegistrationOptions

    properties
        SessionID char      % Session ID for the current FoV and rois
        FovImage            % Image of an FOV
        RoIArray            % An array of rois for a session / FoV
        ImageChannel = []    % Which image channel rois belong to. Note: legacy.
    end

    properties (Access = private)
        IsReference = false % Flag for whether the current instance is a reference
    end

    methods % Constructor
        
        function obj = MultiSessionRoiCollection(sessionID, fovImage, roiArray, isReference)
        %MultiSessionRoiCollection Create instance of MultiSessionRoiCollection    
            if nargin == 0; return; end
            if nargin < 4 || isempty(isReference); isReference = false; end
            
            obj = obj.initializeEntry(sessionID, fovImage, isReference);
            
            obj.RoIArray = roimanager.utilities.roiarray2struct(roiArray);

            if nargin == 4 && ~isempty(imageChannel)
                obj.ImageChannel = imageChannel;
            end
        end
        
    end

    methods (Access = public)

        % Add roi array to multi session roi object
        function obj = addEntry(obj, sessionID, fovImage, roiArray, skipUpdate)
        %ADDENTRY add a new roi array to a multisession roi array
        %
        %   A = addEntry(A, sessionID, fovImage, roiArray) adds a new entry
        %   to a multiSessionRoI array (A). Note, the output of this
        %   method must be reassigned to A for the adding to take place.
        %
        %   When a roi array is added, it is compared with other roi
        %   arrays from other sessions (the reference). If any rois are not 
        %   present, they are added to the current roi array from the 
        %   reference. If overlapping rois are found, rois of the current roi 
        %   array inherit the roi uid from the reference sessions.
            
            import flufinder.longitudinal.MultiSessionRoiCollection
            
            if nargin < 5 || isempty(skipUpdate); skipUpdate = false; end

            % Check if session is already a member of the object array
            if obj.contains(sessionID)
                obj = obj.updateEntry(sessionID, roiArray);
                warning('MultiSessionRoI array already contains session %s. Updated entry...', sessionID)
                return
            end
            
            if isempty(roiArray) || ( isa(roiArray, 'cell') && all(cellfun(@isempty, roiArray)) )
                roiArray = obj.duplicateRoisFromReference(fovImage);
                skipUpdate = true;
            end

            % Todo: plot rois and ask user if the alignment is good. If
            % no, just add rois as normal.
            
            % Expand the multi session roi array with a new object.
            obj(end+1) = MultiSessionRoiCollection(sessionID, fovImage, roiArray);
            
            if numel(obj) > 1 && ~skipUpdate
                obj = obj.updateRoisFromReference(sessionID);
            end
            
            if ~nargout
                warning('multiSessionRoI is an array of handle objects. Type help flufinder.longitudinal.MultiSessionRoiCollection/addEntry for instruction on how to properly add entries to an object array of this class.')
                clear obj
            end
        end
                
        function obj = updateEntry(obj, sessionID, newRois, synchMode)
        %UPDATEENTRY Update rois for given session
        %
        %   Only new rois are added.
        
        % synchMode: 'replace', 'merge', 'update'
        
            if nargin < 4; synchMode = 'merge'; end

            ind = contains({obj.SessionID}, sessionID);
                        
            switch lower(synchMode)
                
                case 'replace'
                    obj(ind).RoIArray = roimanager.utilities.roiarray2struct(newRois);
                    
                case 'merge'
                    if isa(obj(ind).RoIArray, 'cell')
                        error('Merge is currently not supported for multichannel rois.')
                    end
                    oldRois = roimanager.utilities.struct2roiarray(obj(ind).RoIArray);
                    tmpRois = roimanager.utilities.interpolateRoiPositions(oldRois, newRois);
                    newRois = roimanager.utilities.removeOverlappingRois(tmpRois, newRois);
                    
                    % Sort newRois so that imported comes at the end
                    % Todo: Reconsider sorting
                    imported = [];
                    for x = 1:length(newRois)
                        if contains(cell2str(newRois(x).tags),'imported')
                            imported = [imported,x];
                        end
                    end
                    notImported = true(1,length(newRois));
                    notImported(imported) = false;
                    newRois = [newRois(notImported), newRois(imported)];
                    
                    obj(ind).RoIArray = roimanager.utilities.roiarray2struct(newRois);

                case 'update'
                    obj = obj.updateRoisFromReference(sessionID);
                    
                otherwise
                    error('Unknown input')
            end
        end
                   
        function obj = synchEntries(obj, sessionID, synchMode)
        %SYNCHENTRIES Synchronize all RoIs based on a reference session
        %
        %   obj = synchEntries(obj, sessionID, synchMode) synchronize rois
        %   from specified session to all other entries in the multisession
        %   roi collection. synchMode can be 'mirror' or 'add only'.
        %
        %   synchMode: 
        %       'mirror'    :
        %       'add only'  :

        % Rename to updateAllEntriesFromIndividual? Important to note that
        % it is not an update from reference, but the "reverse"
        
            if nargin < 3; synchMode = 'mirror'; end
            
            obj.assertSessionIsMember(sessionID)
            
            isSourceSession = contains( {obj.SessionID}, sessionID );
            sourceRois = obj.getRoiArray(sessionID);

            for i = find(~isSourceSession)
                
                targetRois = obj.getRoiArray(obj(i).SessionID);
               
                % Find rois which are present in source rois and not in target 
                % rois and calculate their positions relative to target rois.
                newRois = roimanager.utilities.interpolateRoiPositions(sourceRois, targetRois);
                
                if isa(newRois, 'cell')
                    for j = 1:numel(newRois)
                        targetRois{j} = obj.addNewRoisToTargetRois(sourceRois{j}, targetRois{j}, newRois{j}, synchMode);
                    end
                else
                    targetRois = addNewRoisToTargetRois(obj, sourceRois, targetRois, newRois, synchMode);
                end
                
                obj(i).RoIArray = roimanager.utilities.roiarray2struct(targetRois);
            end
        end
          
        function roiArray = getRoiArray(obj, sessionID)
        %GETROIARRAY Get roi array for given sessionID
            ind = strcmp( {obj.SessionID}, sessionID );
            roiArray = roimanager.utilities.struct2roiarray(obj(ind).RoIArray);
        end

        function TF = contains(obj, sessionID)
        %contains Check if object with given sessionID is part of object array
            if isempty(obj); TF = false; return; end
            if numel(obj) == 1 && isempty(obj.SessionID); TF = false; return; end

            TF = any(contains({obj(:).SessionID}, sessionID));
        end
       
        function obj = sortEntries(obj)
        %SORTENTRIES sort entries in array based on date in sessionID
        
            sessionIDs = {obj.SessionID};
            dateStrings = cellfun(@(sid) sid(7:14), sessionIDs, 'uni', 0);
            dateNumbers = datenum(dateStrings, 'yyyymmdd');
            
            [~, sortInd] = sort(dateNumbers);
            obj = obj(sortInd);
        end
        
        function S = toStruct(obj)
        %TOSTRUCT Return the properties of the object in a struct array
        % Todo: Why is this needed
            S = struct( 'SessionID', {obj.SessionID}, ...
                        'FovImage', {obj.FovImage}, ...
                        'RoIArray', {obj.RoIArray}, ...
                        'IsReference', [obj.IsReference]);
        end
        
    end

    methods (Access = private) % Internal methods (updating rois)

        function targetRois = addNewRoisToTargetRois(obj, sourceRois, targetRois, newRois, synchMode)
        %addNewRoisToTargetRois Add new rois to target rois
        %
        %   This method inserts a subset of rois from source rois into target
        %   rois.

                % Since rois are added to another session, remove the
                % missing tag they might contain on another session.
                newRois = newRois.removeTag('missing');
                
                % Add imported tag to rois because they are "imported" from
                % another session
                newRois = newRois.addTag('imported');
                
                % Set the enhanced image property to empty
                newRois = obj.resetRoiImageProperty(newRois);

                targetRois = cat(2, targetRois, newRois);
                
                if strcmpi(synchMode, 'mirror')
                    [~, delInd] = setdiff({targetRois.uid}, {sourceRois.uid});
                    targetRois(delInd) = [];
                    
                    % Mirror celltype from reference rois
                    [targetRois(:).celltype] = sourceRois.celltype;
                end
                
                % Check if rois are outside of image, and add missing
                % tag if they are.
                isRoiOutsideImage = arrayfun(@(roi) roi.isOutsideImage, targetRois);
                targetRois(isRoiOutsideImage) = targetRois(isRoiOutsideImage).addTag('missing');
        end

        function [obj, roiArray] = updateRoisFromReference(obj, sessionID)
        %updateRoisFromReference Update RoIs for given session from reference session.
        %
        %   This methods makes sure the roi array for the given session
        %   contain the same rois (rois with same IDs)

            refRois = obj.getReferenceRoiArray();
            %refRois = obj.removeInvalidRois(refRois);

            ind = obj.findSessionIndex(sessionID);
            tmpRois = roimanager.utilities.struct2roiarray(obj(ind).RoIArray);
            %refRois = obj.removeInvalidRois(refRois);

            obj.assertIsSingleChannelRois(refRois)

            newRois = roimanager.utilities.interpolateRoiPositions(refRois, tmpRois);
            newRois = newRois.removeTag('missing');
            newRois = newRois.addTag('imported');

            % Check if any of the unique rois from the reference session 
            % are overlapping with any rois from the current session. If
            % yes, rois in the current session should inherit unique
            % ids. All other rois are added to current session.
            if ~isempty(newRois)
                [iA, iB] = roimanager.utilities.findOverlappingRois(newRois, tmpRois);
                for n = 1:numel(iA)
                    tmpRois(iB(n)).uid = newRois(iA(n)).uid;
                end
                newRois(iA) = [];
            end
            
            % Set the enhanced image property to empty
            [newRois(:).enhancedImage] = deal([]);
            
            roiArray = cat(2, tmpRois, newRois);
            obj(ind).RoIArray = roimanager.utilities.roiarray2struct(roiArray);
            
            if nargout < 2
                clear roiArray tmpRois newRois
            end
        end

        function roiArray = duplicateRoisFromReference(obj, fovImage, varargin)
        %duplicateRoisFromReference Duplicate and reposition rois
        %
        %   This methods duplicates the roi array from the reference session 
        %   and repositions them based on pixel shifts that are obtained by
        %   aligning a FoV image with the reference FoV image.
            
            fovShifts = obj.getFovPixelOffsets(fovImage);
            
            refRois = obj.getReferenceRoiArray();
            [refRois, numRoisPerCell] = obj.getFlattenedRoiArray(refRois);

            % Create a new roi array based on shifts
            newRois = flufinder.longitudinal.warpRois(refRois, fovShifts);
            
            isRoiOutsideImage = arrayfun(@(roi) roi.isOutsideImage, newRois);
            
            % Todo: standardize tags.
            newRois(isRoiOutsideImage) = newRois(isRoiOutsideImage).addTag('missing');
            
            [newRois(:).enhancedImage] = deal([]); % Reset roi image property
            
            if ~isempty(numRoisPerCell) % Unflatten (multi-channel rois)
                newRois = utility.cell.unflatten(newRois, numRoisPerCell);
            end

            % Return rois.
            roiArray = newRois;
        end

        function fovPixelOffsets = getFovPixelOffsets(obj, fovImage)
        %getFovPixelOffsets Get pixel offsets for FoV relative to reference FoV
            
            %Todo: Get alignment options from object properties/preferences?
            
            referenceFovImage = obj.getReferenceFovImage();
            fovImageArray = cat(3, referenceFovImage, fovImage);
            fovPixelOffsets = flufinder.longitudinal.alignFovs(fovImageArray);
        end

    end

    methods (Access = private) % Internal methods (utility)

        function obj = initializeEntry(obj, sessionID, fovImage, isReference)
            obj.SessionID = sessionID;
            obj.FovImage = fovImage;
            obj.IsReference = isReference;
        end

        function index = findReferenceSessionIndex(obj)
            index = find([obj.IsReference]);
            if isempty(index)
                index = 1;
            end
        end

        function index = findSessionIndex(obj, sessionID)
        %findSessionIndex Find index for given session in object array
            index = find( contains({obj.SessionID}, sessionID) );
        end

        function fovImage = getReferenceFovImage(obj)
            referenceIdx = obj.findReferenceSessionIndex();
            fovImage = obj(referenceIdx).FovImage;
        end

        function roiArray = getReferenceRoiArray(obj)
            referenceIdx = obj.findReferenceSessionIndex();
            roiArray = obj(referenceIdx).RoIArray;

            % Make sure the returned value is a RoI array
            roiArray = roimanager.utilities.struct2roiarray(roiArray);
        end

        function assertSessionIsMember(obj, sessionID)
            if ~obj.contains(sessionID)
                error('Session "%s" is not part of this MultiSessionRoiCollection', ...
                    sessionID)
            end
        end

        function assertIsSingleChannelRois(~, roiArray)
            if isa(roiArray, 'cell')
                error('This operation is currently only supported for single channel rois. Please create issue if this functionality is needed.')
            end
        end

    end

    methods (Static)

        function obj = loadobj(s)
        %loadobj Perform customizations when loading object of this class
        %
        %   Convert rois to struct arrays on load.
            import roimanager.utilities.roiarray2struct
            import flufinder.longitudinal.MultiSessionRoiCollection.isRoiArray
            
            obj = s;
            
            for n = 1:numel(obj)
                if isRoiArray( obj(n).RoIArray )
                    obj(n).RoIArray = roiarray2struct(obj(n).RoIArray);
                end
            end
        end

    end

    methods (Static, Access = private) % Condider moving to roimanager.utilities

        function tf = isRoiArray(A)
            tf = isa(A, 'RoI') || (isa(A, 'cell') && isa(A{1}, 'RoI'));
        end

        function roiArray = resetRoiImageProperty(roiArray)
            import flufinder.longitudinal.MultiSessionRoiCollection.resetRoiImageProperty
            if isa(roiArray, 'cell')
                for i = 1:numel(roiArray)
                    roiArray{i} = resetRoiImageProperty(roiArray{i});
                end
            else
                % Set the enhanced image property to empty
                [roiArray(:).enhancedImage] = deal([]);
            end
        end

        function [roiArray, numRoisPerCell] = getFlattenedRoiArray(roiArray)
            if isa(roiArray, 'cell') % Flatten (multi-channel rois)
                [roiArray, numRoisPerCell] = utility.cell.flatten(roiArray);
            else
                numRoisPerCell = [];
            end
        end

        function roiArray = removeInvalidRois(roiArray)
            % This is most likely going to be deprecated.
            isEmptyBoundary = cellfun(@(b) numel(b)==0, {roiArray.boundary});
            isnanCenter = cellfun(@(b) any(isnan(b)), {roiArray.center});
            roiArray(isnanCenter | isEmptyBoundary) = [];
        end

    end

end