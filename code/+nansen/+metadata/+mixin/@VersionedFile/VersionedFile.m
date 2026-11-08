classdef VersionedFile < handle
%VersionedFile Mixin providing verified file persistence with version tracking
%
%   Subclasses must implement toFileStruct() and fromFileStruct(S).
%   Optionally override processFileStruct(S) and onAfterLoad().
%
%   The save() method writes to a temp file, verifies that it loads, copies
%   it over the target file, and renames the temp file to a backup. Each
%   successful save increments a version number. isLatestVersion() compares
%   the in-memory version to the one on disk, allowing detection of
%   external modifications.
%
%   See also: nansen.metadata.MetaTable

    properties (SetAccess = protected)
        filepath    (1,:) char = ''
        VersionNumber int64 = int64(0)
    end

    methods (Abstract, Access = protected)
        S = toFileStruct(obj)
        % toFileStruct Serialize object state to a struct for saving

        fromFileStruct(obj, S)
        % fromFileStruct Restore object state from a loaded struct
    end

    methods (Access = protected)
        function S = processFileStruct(obj, S) %#ok<INUSL>
        %processFileStruct Hook called after toFileStruct(), before saving
        %
        %   Override to modify S before it is written to disk (e.g. to
        %   synchronize entries to a master MetaTable).
        end

        function onAfterLoad(obj) %#ok<MANU>
        %onAfterLoad Hook called after fromFileStruct() completes
        %
        %   Override to perform post-load actions (e.g. syncing from master).
        end
    end

    methods
        function wasSaved = save(obj, force)
        %save Save object to file through a verified temporary file
        %
        %   wasSaved = save(obj) saves if the object is modified.
        %   wasSaved = save(obj, true) forces a save even if unmodified.
        %
        %   For a target file <name>.mat, the data is written to
        %   <name>.tempsave.mat in the same folder. That file is loaded to
        %   verify it, copied over the target file, and renamed to
        %   <name>.backup.mat, replacing an earlier backup.
        %
        %   <name>.backup.mat exists after the first successful save and
        %   holds a copy of the data from the latest successful save.
        %
        %   <name>.tempsave.mat exists while a save is running. A file left
        %   on disk afterwards holds the data of a save that stopped after
        %   writing it. save throws NANSEN:VersionedFile:SaveFailed if the
        %   verification or the copy fails. If only the rename fails, the
        %   save has succeeded and save issues the warning
        %   NANSEN:VersionedFile:BackupNotUpdated.
        %
        %   VersionNumber is incremented once the target file is written,
        %   so a failed save leaves it unchanged.

            if nargin < 2; force = false; end
            wasSaved = false;

            if isempty(obj.filepath)
                error('NANSEN:VersionedFile:NoFilepath', ...
                    'Cannot save: filepath is not set.')
            end

            if obj.isClean() && ~force
                if ~nargout; clear wasSaved; end
                return
            end

            if ~force && ~obj.isLatestVersion()
                error('NANSEN:VersionedFile:StaleFile', ...
                    ['Cannot save "%s" because the file has changed on disk. ', ...
                     'Reload the file or save with force=true to overwrite the newer version.'], ...
                    obj.filepath)
            end

            S = obj.toFileStruct();
            S = obj.processFileStruct(S);

            newVersionNumber = int64(obj.loadVersionNumber()) + 1;
            S.VersionNumber = newVersionNumber;

            [folderPath, fileName, fileExtension] = fileparts(obj.filepath);
            tempPath = fullfile(folderPath, fileName + ".tempsave" + fileExtension);
            backupPath = fullfile(folderPath, fileName + ".backup" + fileExtension);

            save(tempPath, '-struct', 'S');

            try
                verifiedS = load(tempPath); %#ok<NASGU>
                copyfile(tempPath, obj.filepath)

                % isLatestVersion compares this number with the one in the
                % file, so it changes only once the file holds the new one.
                obj.VersionNumber = newVersionNumber;
                wasSaved = true;
                obj.markClean();
            catch ME
                error("NANSEN:VersionedFile:SaveFailed", ...
                    "Could not save '%s'. The data of this save is kept in '%s'. Cause: %s", ...
                    obj.filepath, tempPath, ME.message)
            end

            % The target file is written at this point, so a failed rename
            % must not surface as an error. With output arguments, movefile
            % returns a failure in its status instead of throwing it. The
            % "f" option also replaces a read-only backup.
            [wasRenamed, renameMessage] = movefile(tempPath, backupPath, "f");
            if ~wasRenamed
                warning("NANSEN:VersionedFile:BackupNotUpdated", ...
                    "Saved '%s', but could not rename '%s' to a backup: %s", ...
                    obj.filepath, tempPath, renameMessage)
            end

            if ~nargout; clear wasSaved; end
        end

        function load(obj)
        %load Load object state from file

            if ~isfile(obj.filepath)
                error('NANSEN:VersionedFile:FileNotFound', ...
                    'File "%s" does not exist.', obj.filepath)
            end

            S = load(obj.filepath);
            obj.fromFileStruct(S);

            if isempty(obj.VersionNumber) || obj.VersionNumber == 0
                obj.VersionNumber = int64(0);
            end

            obj.onAfterLoad();
            obj.markClean();
        end

        function saveCopy(obj, savePath)
        %saveCopy Save a copy of this object to the given file path
        %
        %   The copy has its own version count: VersionNumber in the copy
        %   is one higher than in an existing file at savePath, and 1 for
        %   a new file. The object stays associated with its own file, so
        %   filepath and VersionNumber keep their values, also if the save
        %   fails. A savePath equal to filepath is a forced save.

            % Writing the object's own file changes its version, so the
            % number in memory has to follow it.
            if strcmp(savePath, obj.filepath)
                obj.save(true);
                return
            end

            originalPath = obj.filepath;
            originalVersionNumber = obj.VersionNumber;
            stateCleanupObj = onCleanup( ...
                @() obj.restoreFileState(originalPath, originalVersionNumber));

            obj.filepath = savePath;
            obj.save(true);
        end

        function tf = isLatestVersion(obj)
        %isLatestVersion Return true if in-memory version matches the file

            versionNumberInFile = obj.loadVersionNumber();
            tf = versionNumberInFile == obj.VersionNumber;
        end

        function versionNumber = getVersionNumberOnDisk(obj)
        %getVersionNumberOnDisk Read the persisted version number

            versionNumber = obj.loadVersionNumber();
        end
    end

    methods (Access = protected)
        function versionNumber = loadVersionNumber(obj)
        %loadVersionNumber Read VersionNumber from file without loading all data

            if ~isfile(obj.filepath)
                versionNumber = int64(0);
                return
            end

            warnState = warning('off', 'MATLAB:load:variableNotFound');
            warningCleanupObj = onCleanup(@() warning(warnState));

            S = load(obj.filepath, 'VersionNumber');

            if isfield(S, 'VersionNumber') && ~isempty(S.VersionNumber)
                versionNumber = S.VersionNumber;
            else
                versionNumber = int64(0);
            end
        end
    end

    methods (Access = private)
        function restoreFileState(obj, filePath, versionNumber)
        %restoreFileState Set the file path and the version number of that file

            obj.filepath = filePath;
            obj.VersionNumber = versionNumber;
        end
    end

    methods (Abstract)
        markClean(obj)
        % markClean Mark the object as unmodified

        tf = isClean(obj)
        % isClean Return true if the object has no unsaved changes
    end
end
