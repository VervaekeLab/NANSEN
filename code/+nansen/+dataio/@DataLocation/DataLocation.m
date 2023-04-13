classdef DataLocation < handle
%DATALOCATION A class to represent a data location
    %   This class should be used to represent a data location, and to
    %   interact with the data in the data location.


    properties (SetAccess = private)
        Uuid char                   % Unique identifier for the data location
        RootUuid char               % Unique identifier for the data location root directory
    end

    properties
        Name char                   % Name of the data location
        Type nansen.dataio.enum.DataLocationType % Type of data location
        RootPath char               % Root path of the data location
        Subfolders char             % Subfolders of the data location
    end

    properties (Dependent)
        Path                        % Path to the data location
    end

     properties (Hidden, SetAccess = immutable) %(Transient) 
        DataLocationModel
    end


    methods
        function obj = DataLocation(name, type, rootPath, subfolders)
            %DATALOCATION Construct an instance of this class
            %   Detailed explanation goes here
            obj.Name = name;
            obj.Type = type;
            obj.RootPath = rootPath;
            obj.Subfolders = subfolders;
        end
    end

    methods
        function value = get.Path(obj)
            value = fullfile(obj.RootPath, obj.Subfolders);
        end
    end

    methods
        function updateRootPath(obj, rootPath)
            
            % Get datalocation info from datalocation model 
            dlInfo = obj.DataLocationModel.getDataLocation(obj.Name);

            % Was a session folder for this entry located in (any of) 
            % the root datalocation directories.

            name = dataLocation.Name;
            rootPaths = {dataLocation.RootPath.Value};

            rootIdx = [];
            for k = 1:numel(rootPaths)
                if isfield(entries(j).DataLocation, name)
                    tf = contains( entries(j).DataLocation.(name), rootPaths{k} );
                    if ~isempty(tf)
                        thisRootPath = rootPaths{k};
                        rootIdx = k;
                        break
                    end
                end
            end

            obj.RootPath = rootPath;

            % Update root uuid
        end
    end


end