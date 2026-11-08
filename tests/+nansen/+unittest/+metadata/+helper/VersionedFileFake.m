classdef VersionedFileFake < nansen.metadata.mixin.VersionedFile
%VersionedFileFake Minimal VersionedFile that stores one value, for unit testing
%
%   AfterMarkClean is called at the end of markClean. VersionedFile.save
%   calls markClean between copying the temp file over the target file and
%   renaming the temp file, so a test can use AfterMarkClean to change the
%   files on disk at that point.

    properties
        Data = 0
        AfterMarkClean (1,1) function_handle = @() []
    end

    properties (Access = private)
        HasNoUnsavedChanges (1,1) logical = false
    end

    methods
        function obj = VersionedFileFake(filePath)
            arguments
                filePath (1,1) string
            end
            obj.filepath = char(filePath);
        end

        function markModified(obj)
            obj.HasNoUnsavedChanges = false;
        end

        function markClean(obj)
            obj.HasNoUnsavedChanges = true;
            obj.AfterMarkClean();
        end

        function tf = isClean(obj)
            tf = obj.HasNoUnsavedChanges;
        end
    end

    methods (Access = protected)
        function S = toFileStruct(obj)
            S = struct('Data', obj.Data);
        end

        function fromFileStruct(obj, S)
            obj.Data = S.Data;
        end
    end
end
