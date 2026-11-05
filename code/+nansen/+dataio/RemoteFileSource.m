classdef (Abstract) RemoteFileSource < handle
%RemoteFileSource - Source of data files that are stored online
%
%   A data location can hold placeholders for files that are stored
%   online, such as the empty files of a cloned EBRAINS bucket. A subclass
%   of RemoteFileSource tells which local files are placeholders and
%   replaces a placeholder with the online file.
%
%   A project names its subclass with Project.setRemoteFileSource.
%   Session.loadData then checks every file it loads: when the file is a
%   placeholder, it downloads it if Project.setAutoDownloadRemoteFiles was
%   set to true, and raises an error that names Session.downloadDataFile
%   otherwise.
%
%       project.setRemoteFileSource("mymodule.dataio.MyFileSource")
%       project.setAutoDownloadRemoteFiles(true)
%
%   A subclass constructor takes one input, the root folder of the data
%   location that holds the file, and passes it to this constructor.
%
%   See also nansen.metadata.type.Session/loadData,
%   nansen.metadata.type.Session/downloadDataFile

    properties (SetAccess = immutable)
        RootPath (1,1) string % Root folder of the data location that holds the files
    end

    methods
        function obj = RemoteFileSource(rootPath)
            arguments
                rootPath (1,1) string
            end
            obj.RootPath = rootPath;
        end
    end

    methods (Abstract)
        %isOnlineOnly Whether a local file is a placeholder for a file stored online
        %
        %   tf = isOnlineOnly(obj, filePath) is called only for a file that
        %   exists, and must return a logical scalar.
        tf = isOnlineOnly(obj, filePath)

        %download Replace the placeholder at filePath with the file stored online
        %
        %   download(obj, filePath) must return only once the complete file
        %   is in place, because the file is read right after. If the
        %   download fails, it must raise an error and leave the placeholder:
        %   a partial file that is not empty would count as local.
        download(obj, filePath)
    end
end
