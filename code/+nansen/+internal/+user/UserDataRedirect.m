classdef (Sealed) UserDataRedirect
%UserDataRedirect File that names the user data directory for every MATLAB release
%
%   The UserDataDirectory preference is saved in MATLAB's preference
%   directory, which belongs to one MATLAB release. When the user data is
%   moved to a directory other than the default, the session also writes
%   that directory to a redirect file in the default directory,
%   <userpath>/Nansen/profiles/<profile>, which does not belong to a
%   release. A session whose release has no UserDataDirectory preference
%   uses the directory that the redirect file names, if that is an absolute
%   path to an existing folder.
%
%   The file is named user_data_redirect.txt. It holds the path on its
%   first line, as UTF-8 text.
%
%   UserDataRedirect methods:
%       getFilePath - Path of the redirect file in a default directory
%       read        - Directory that the redirect file names
%       follow      - Directory that the redirect file names, if it exists
%       write       - Write a redirect file
%       remove      - Remove a redirect file
%
%   See also nansen.internal.user.NansenUserSession/setUserDataDirectory,
%   nansen.userdatadir

    properties (Constant)
        FILENAME = "user_data_redirect.txt"
    end

    methods (Access = private)
        function obj = UserDataRedirect()
        %UserDataRedirect Not used; the class only groups static methods
        end
    end

    methods (Static)

        function filePath = getFilePath(defaultDirectory)
        %getFilePath Path of the redirect file in a default directory

            arguments
                defaultDirectory (1,1) string
            end

            filePath = fullfile(defaultDirectory, ...
                nansen.internal.user.UserDataRedirect.FILENAME);
        end

        function userDataDirectory = read(defaultDirectory)
        %read Directory that the redirect file names
        %
        %   userDataDirectory = read(defaultDirectory) returns the first
        %   line of the redirect file in defaultDirectory, or "" when there
        %   is no redirect file.

            arguments
                defaultDirectory (1,1) string
            end

            userDataDirectory = "";

            filePath = nansen.internal.user.UserDataRedirect.getFilePath(defaultDirectory);
            if ~isfile(filePath); return; end

            lines = readlines(filePath, "Encoding", "UTF-8", "EmptyLineRule", "skip");
            if ~isempty(lines)
                userDataDirectory = lines(1);
            end
        end

        function userDataDirectory = follow(defaultDirectory)
        %follow Directory that the redirect file names, if it exists
        %
        %   userDataDirectory = follow(defaultDirectory) returns the
        %   directory that the redirect file in defaultDirectory names, or
        %   "" when there is no redirect file, or when it does not name an
        %   existing folder by an absolute path. A relative path would
        %   resolve against MATLAB's current folder.

            arguments
                defaultDirectory (1,1) string
            end

            userDataDirectory = nansen.internal.user.UserDataRedirect.read(defaultDirectory);

            isUsable = strlength(userDataDirectory) > 0 ...
                && nansen.util.path.isAbsolutePath(char(userDataDirectory)) ...
                && isfolder(userDataDirectory);

            if ~isUsable
                userDataDirectory = "";
            end
        end

        function write(defaultDirectory, userDataDirectory)
        %write Write a redirect file naming a user data directory
        %
        %   write(defaultDirectory, userDataDirectory) writes
        %   userDataDirectory to the redirect file in defaultDirectory,
        %   creating defaultDirectory if it does not exist.

            arguments
                defaultDirectory (1,1) string
                userDataDirectory (1,1) string
            end

            if ~isfolder(defaultDirectory); mkdir(defaultDirectory); end

            filePath = nansen.internal.user.UserDataRedirect.getFilePath(defaultDirectory);
            writelines(userDataDirectory, filePath, "Encoding", "UTF-8")
        end

        function remove(defaultDirectory)
        %remove Remove the redirect file from a default directory

            arguments
                defaultDirectory (1,1) string
            end

            filePath = nansen.internal.user.UserDataRedirect.getFilePath(defaultDirectory);
            if isfile(filePath)
                delete(filePath)
            end
        end
    end
end
