classdef (Abstract) RemoteFileSource < handle
%RemoteFileSource - Source of data files that are stored online
%
%   A data location can hold placeholders for files that are stored
%   online, such as the empty files of a cloned EBRAINS bucket. A subclass
%   of RemoteFileSource tells which local files are placeholders and
%   replaces a placeholder with the online file.
%
%   A project names its subclass in the project preference
%   RemoteFileSource. Session.loadData then checks every file it loads:
%   when the file is a placeholder, it downloads it if the project
%   preference AutoDownloadRemoteFiles is true, and raises an error that
%   names Session.downloadDataFile otherwise.
%
%       preferences = project.Preferences;
%       preferences.RemoteFileSource = 'mymodule.dataio.MyFileSource';
%       preferences.AutoDownloadRemoteFiles = true;
%       project.Preferences = preferences;
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
            obj.RootPath = rootPath;
        end
    end

    methods (Abstract)
        %isOnlineOnly Whether a local file is a placeholder for a file stored online
        tf = isOnlineOnly(obj, filePath)

        %download Replace the placeholder at filePath with the file stored online
        download(obj, filePath)
    end
end
