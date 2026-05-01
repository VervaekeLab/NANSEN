classdef VersionedFile < handle
%VersionedFile Mixin providing verified file persistence with version tracking
%
%   Subclasses must implement toFileStruct() and fromFileStruct(S).
%   Optionally override processFileStruct(S) and onAfterLoad().
%
%   The save() method writes to a temp file, verifies that it loads, copies
%   it over the target file, and leaves the temp file as a backup. It also
%   increments a version number on each save. isLatestVersion() compares
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
        %save Save object to file atomically
        %
        %   wasSaved = save(obj) saves if the object is modified.
        %   wasSaved = save(obj, true) forces a save even if unmodified.
        %
        %   Uses a temp-file pattern: writes to a .tempsave file, verifies
        %   it loads correctly, then copies it over the target file.

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

            versionNumber = obj.loadVersionNumber();
            obj.VersionNumber = versionNumber + 1;
            S.VersionNumber = obj.VersionNumber;

            tempPath = strrep(obj.filepath, '.mat', '.tempsave.mat');
            save(tempPath, '-struct', 'S');

            try
                verifiedS = load(tempPath); %#ok<NASGU>
                copyfile(tempPath, obj.filepath)
                wasSaved = true;
                obj.markClean();
            catch
                error('NANSEN:VersionedFile:SaveFailed', ...
                    ['Something went wrong when saving. ' ...
                     'A backup should exist with a ''.tempsave'' postfix: %s'], ...
                    tempPath)
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

            originalPath = obj.filepath;
            obj.filepath = savePath;
            obj.save(true);
            obj.filepath = originalPath;
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

    methods (Abstract)
        markClean(obj)
        % markClean Mark the object as unmodified

        tf = isClean(obj)
        % isClean Return true if the object has no unsaved changes
    end
end
