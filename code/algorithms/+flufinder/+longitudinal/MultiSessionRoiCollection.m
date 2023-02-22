classdef MultiSessionRoiCollection < handle
%MultiSessionRoiCollection is a class for managing rois of multiple sessions.

% Todo:
%   [ ] Add save method and save as a struct array
%   [ ] Add static load method, and initialize from calling it.
%   [ ] Should this be a non-scalar? Why is it??? Why is it a value class?
%   [ ] Use catalog?
%   [ ] Add methods for updating on the fly
%   [ ] Support for rois from more than one image cannel


%   properties

%       SynchMode = 'Only Add', 'Mirror'
%       UpdateMode = 'replace', 'merge', 'update' % Mode for updating a set of rois
%           'replace' the existing rois with new ones
%           'merge' merge the new rois into existing
%           'update' update existing rois from master

    properties 
        SessionID
        FovImage
        RoIArray
        ImageChannel = 1 % Which image channel rois belong to
    end
    

    methods
        
        % Constructor
        function obj = MultiSessionRoiCollection(sessionID, fovImage, roiArray, imageChannel)
            
            if nargin == 0; return; end
            
            obj = obj.initializeEntry(sessionID, fovImage);

            obj.RoIArray = roimanager.utilities.roiarray2struct(roiArray);

            if nargin == 4 && ~isempty(imageChannel)
                obj.ImageChannel = imageChannel;
            end
        end
        
        % Add sessionID and FovImage to multi session roi object
        function obj = initializeEntry(obj, sessionID, fovImage)
           obj.SessionID = sessionID;
           obj.FovImage = fovImage;
        end
        
        % Add roi array to multi session roi object
        function obj = addEntry(obj, sessionID, fovImage, roiArray)
        %ADDENTRY add a new roi array to a multisession roi array
        %
        %   A = addEntry(A, sessionID, fovImage, roiArray) adds a new entry
        %   to a multiSessionRoI array (A). Note, the output of this
        %   method must be reassigned to A for the adding to take place.
        %
        %   When a roi array is added, it is compared with other roi
        %   arrays from other sessions (master). If any rois are not 
        %   present, they are added to the current roi array from the 
        %   master. If overlapping rois are found, rois of the current roi 
        %   array inherit the roi uid from the reference sessions (master).
        
            import flufinder.longitudinal.MultiSessionRoiCollection

            % Check if session is already a member of the object array
            if obj.contains(sessionID)
                obj = obj.updateEntry(sessionID, roiArray);
                warning('MultiSessionRoI array already contains session %s. Updated entry...', sessionID)
                return
            end
            
            % If roi array is empty, duplicate based on reference session
            if isempty(roiArray)
                roiArray = obj.duplicateRois(fovImage);
            end
            
            % Expand the multi session roi array with a new object.
            obj(end+1) = MultiSessionRoiCollection(sessionID, fovImage, roiArray);
            
            if numel(obj) > 1
                obj = obj.updateFromOthers(sessionID);
            end
            
            if ~nargout
                warning('multiSessionRoI is an array of handle objects. Type help flufinder.longitudinal.MultiSessionRoiCollection/addEntry for instruction on how to properly add entries to an object array of this class.')
                clear obj
            end
        end
        
        % Update a roi array from master
        function [obj, roiArray] = updateFromOthers(obj, sessionID)
        %UPDATEFROMOTHERS update RoIs for given session from reference sess
        %
        % Todo: Rename to updateFromReference

            refRois = roimanager.utilities.struct2roiarray(obj(1).RoIArray);
            
%             isEmptyBoundary = cellfun(@(b) numel(b)==0, {refRois.boundary});
%             isnanCenter = cellfun(@(b) any(isnan(b)), {refRois.center});
%             refRois(isnanCenter | isEmptyBoundary) = [];

            ind = obj.getSessionInd(sessionID);
            tmpRois = roimanager.utilities.struct2roiarray(obj(ind).RoIArray);

%             isEmptyBoundary = cellfun(@(b) numel(b)==0, {tmpRois.boundary});
%             isnanCenter = cellfun(@(b) any(isnan(b)), {tmpRois.center});
%             tmpRois(isnanCenter | isEmptyBoundary) = [];
            
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
            for i = 1:numel(newRois)
                newRois(i).enhancedImage = [];
            end
            
            roiArray = cat(2, tmpRois, newRois);
            obj(ind).RoIArray = roimanager.utilities.roiarray2struct(roiArray);
                        
            if nargout < 2
                clear roiArray tmpRois newRois
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
                    obj = obj.updateFromOthers(sessionID);
                    
                otherwise
                    error('Unknown input')
            end
        end
         
        function roiArray = getRoiArray(obj, sessionID)
        %GETROIARRAY Get roi array for given sessionID
            
            ind = contains( {obj.SessionID}, sessionID );
            roiArray = roimanager.utilities.struct2roiarray(obj(ind).RoIArray);
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
        
            if nargin < 3; synchMode = 'mirror'; end
        
            if ~obj.contains(sessionID)
                error('Session %s is not part of this multisession RoI', sessionID)
            end
            
            isReference = contains( {obj.SessionID}, sessionID );
            referenceRois = obj.getRoiArray(sessionID);
            
            for i = find(~isReference)
                
                tmpRois = roimanager.utilities.struct2roiarray(obj(i).RoIArray); %getRoiArray(tmpSessionID);
               
                % Find rois which are present in reference rois and not in
                % tmp rois and calculate their positions relative to tmp
                % rois.
                newRois = roimanager.utilities.interpolateRoiPositions(referenceRois, tmpRois);
                
                % Since rois are added to another session, remove the
                % missing tag they might contain on another session.
                newRois = newRois.removeTag('missing');
                
                % Add imported tag to rois because they are "imported" from
                % another session
                newRois = newRois.addTag('imported');
                
                % Set the enhanced image property to empty
                for j = 1:numel(newRois)
                    newRois(j).enhancedImage = [];
                end
                
                tmpRois = cat(2, tmpRois, newRois);
                
                if strcmpi(synchMode, 'mirror')
                    [~, delInd] = setdiff({tmpRois.uid}, {referenceRois.uid});
                    tmpRois(delInd) = [];
                    
                    % Mirror celltype from reference rois
                    [tmpRois(:).celltype] = referenceRois.celltype;
                    
                end
                
                % Check if rois are outside of image, and add missing
                % tag if they are.
                isRoiOutsideImage = arrayfun(@(roi) roi.isOutsideImage, tmpRois);
                tmpRois(isRoiOutsideImage) = tmpRois(isRoiOutsideImage).addTag('missing');
                
                obj(i).RoIArray = roimanager.utilities.roiarray2struct(tmpRois);
            end
        end
        
        function roiArray = duplicateRois(obj, fovImage, varargin)
        %DUPLICATEROIS Apply/duplicate rois to a new session
            
% % %         % Todo: Implement varargin and options
% % %             defoptions = struct('reference', 1, ...
% % %                                 'register', true, ...
% % %                                 'regMethod', 'rigid');
            
            % Todo: plot rois and ask user if the alignment is good. If
            % no, just add rois as normal.

            % Apply rois from first session to the loaded session
            imArray = cat(3, obj(1).FovImage, fovImage);
            fovShifts = flufinder.longitudinal.alignFovs(imArray);

            % Todo: Create a new roi array based on shifts. Run one rigid,
            % and one nonrigid and let user select?

            refRois = roimanager.utilities.struct2roiarray(obj(1).RoIArray);
            
            newRois = flufinder.longitudinal.warpRois(refRois, fovShifts);
            
            isRoiOutsideImage = arrayfun(@(roi) roi.isOutsideImage, newRois);
            newRois(isRoiOutsideImage) = newRois(isRoiOutsideImage).addTag('missing');
            
            % Set the enhanced image property to empty
            for i = 1:numel(newRois)
                newRois(i).enhancedImage = [];
            end
            
            % Return rois.
            roiArray = newRois;
        end
        
        function TF = contains(obj, sessionID)
            
            if isempty(obj); TF = false; return; end
            if numel(obj) == 1 && isempty(obj.SessionID); TF = false; return; end

            TF = any(contains({obj(:).SessionID}, sessionID));
        end
       
        function n = getSessionInd(obj, sessionID)
            n = find( contains({obj.SessionID}, sessionID) );
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
        
            S = struct( 'SessionID', {obj.SessionID}, ...
                        'FovImage', {obj.FovImage}, ...
                        'RoIArray', {obj.RoIArray} );
        end
        
    end
   
    methods (Static)
        
        function obj = loadobj(s)
            
            obj = s;
            
            for n = 1:numel(obj)
                if isa(obj(n).RoIArray, 'RoI')
                    obj(n).RoIArray = roimanager.utilities.roiarray2struct(obj(n).RoIArray);
                end
            end
        end
        
    end

end