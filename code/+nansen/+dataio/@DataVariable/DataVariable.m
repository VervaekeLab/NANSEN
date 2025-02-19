classdef DataVariable < nansen.metadata.abstract.Item

    % Todo/Question:
    %  Should project ID be part of this class.
    

    properties (Dependent)
        VariableName (1,1) string   % Name of variable
    end

    properties
        DataLocation (1,1) string = ""          % todo: rename DataLocationName? Name of datalocation where variable is stored.
        Subfolder (1,1) string = ""             % Subfolder within sessionfolder where variable is saved to file (optional)
        FileNameExpression (1,1) string = ""    % Part of filename to reckognize variable from (optional) FilenamePattern
        FileType (1,1) string = ""              % File type of variable
        FileAdapter (1,1) string = "Default"    % File adapter to use for loading and saving variable
        Alias (1,1) string = ""                 % Alias or "nickname" for variables
        GroupName (1,1) string = ""             % Placeholder...
        IsCustom (1,1) logical   = false        % Is variable custom, i.e user defined?
        IsInternal (1,1) logical = false        % Flag for internal variable
        IsFavorite (1,1) logical = false        % Flag for variable marked as favorite
    end

    properties (Dependent, SetAccess = private)
        % DataLocation Should this be dependent? Yes, because if the name
        % is updated. However, seems like it would be inefficient to
        % retrieve the name every time it is used?

        DataType (1,1) string       % Datatype of variable: Will depend on file adapter
    end

    properties (Access = private)
        DataLocationUuid (1,1) string = ""     % uuid of datalocation variable belongs to (internal)
    end

    properties (Access = private, Transient)
        DataType_ (1,1) string
    end

    methods %(Access = {?nansen.config.varmodel.VariableModel, ?Catalog})
        function obj = DataVariable(propValues)
            arguments
                propValues.?nansen.dataio.DataVariable
                propValues.DataLocationUuid (1,1) string = ""
                propValues.UUID (1,1) string % Capture superclass properties last
            end
            nameValuePairs = namedargs2cell(propValues);
            obj@nansen.metadata.abstract.Item(nameValuePairs{:})
            
            obj.updateInternals()
        end
    end

    methods % Set/get methods
        function set.VariableName(obj, value)
            obj.Name = value;
        end
        function value = get.VariableName(obj)
            value = obj.Name;
        end
               
        function set.DataLocationUuid(obj, value)
            obj.DataLocationUuid = value;
            obj.postSetDataLocationUuid()
        end

        function value = get.DataType(obj)
            value = obj.DataType_;
        end
    end
    
    methods % Inherited
        function result = toStruct(obj, options)
            arguments
                obj (1,:) nansen.metadata.abstract.Item
                options.ConvertHidden (1,1) logical = true
                options.ConvertTransient (1,1) logical = false
                options.ConvertPrivate (1,1) logical = true
                options.WithContext (1,1) logical = false
            end
            options = namedargs2cell(options);
            result = toStruct@nansen.common.mixin.StructConvertible(obj, options{:});
        end
    end

    methods (Access = protected)
        function publicProperties = setPrivateProps(obj, allProperties)
            if isfield(allProperties, 'DataLocationUuid')
                obj.DataLocationUuid = allProperties.DataLocationUuid;
                publicProperties = rmfield(allProperties, 'DataLocationUuid');
            else
                publicProperties = allProperties;
            end
        end
    end

    methods (Access = ?nansen.common.mixin.StructConvertible)
        function value = getPrivate(obj, privatePropertyName)
            value = obj.(privatePropertyName);
        end
    end

    methods % File adapter methods
        function fileAdapter = getFileAdapter(obj)
            error('Not implemented yet')
            fileAdapterFcn = obj.getFileAdapterFcn();
            % Note: Need to implement path resolution here
            filePath = '';  % TODO: Implement path resolution
            fileAdapter = fileAdapterFcn(filePath);
        end

        function fileAdapterFcn = getFileAdapterFcn(obj)
            fileAdapterList = nansen.dataio.listFileAdapters();
            
            % Find file adapter match for name
            isMatch = strcmp({fileAdapterList.FileAdapterName}, obj.FileAdapter);
            
            if ~any(isMatch)
                error('DataVariable:GetFileAdapterFcn', 'File adapter was not found')
            elseif sum(isMatch) > 1
                error('This is a bug. Please report')
            end
            
            fileAdapterFcn = str2func(fileAdapterList(isMatch).FunctionName);
        end

        function updateDataType(obj) % Todo: refreshDataType, or just make it dependent?
            fileAdapterList = nansen.dataio.listFileAdapters();
            if ~strcmp(obj.FileAdapter, 'Default')
                isMatch = strcmp({fileAdapterList.FileAdapterName}, obj.FileAdapter);
                if any(isMatch)
                    fileAdapterFcn = str2func(fileAdapterList(isMatch).FunctionName);
                    obj.DataType_ = fileAdapterFcn().DataType;
                end
            end
        end
    end

    methods (Access = private)
        function updateInternals(obj)
            if strcmp(obj.DataLocation, 'DEFAULT')
                obj.assignDefaultDataLocation()
            end
            obj.updateDataType()
        end

        function assignDataLocation(obj, dataLocationReference)
            arguments
                obj (1,1) nansen.dataio.DataVariable
                dataLocationReference (1,1) string
            end
            if nansen.common.isUuid(dataLocationReference)
                obj.DataLocationUuid = dataLocationReference;
            else
                % Resolve and assign data location uuid:
                dlm = nansen.DataLocationModel();
                dataLocationInfo = dlm.getDataLocation(dataLocationReference);
                obj.DataLocationUuid = dataLocationInfo.Uuid;
            end
        end

        function assignDefaultDataLocation(obj)
            dataLocationInfo = nansen.DataLocationModel().DefaultDataLocation;
            obj.DataLocation = dataLocationInfo.Name;
            obj.DataLocationUuid = dataLocationInfo.Uuid;
        end
    end
    
    methods (Access = private) % Property postset methods
        function postSetDataLocationUuid(obj)
            DLM = nansen.DataLocationModel();
            dataLocationName = DLM.getNameFromUuid(obj.DataLocationUuid);
            obj.DataLocation = dataLocationName;
        end
    end

    methods (Static)
        function result = fromInitSpecification(filePath)
            import nansen.dataio.DataVariable
            S = readstruct(filePath);
            allDataLocationNames = string( fieldnames(S) )';
            
            numVars = sum( structfun(@(s) numel(fieldnames(s)), S) );
            result = cell(1, numVars);
            
            count = 0;
            for dataLocationName = allDataLocationNames
                allVariableNames = string( fieldnames(S.(dataLocationName)) )';
                for variableName = allVariableNames
                    count = count + 1;
                    result{count} = DataVariable.fromInitSpecificationScalar(...
                        dataLocationName, ...
                        variableName, ...
                        S.(dataLocationName).(variableName));
                end
            end

            result = [result{:}];
        end

        function obj = fromStruct(S)
            import nansen.metadata.abstract.Item
            obj = Item.fromStruct(S, mfilename('class'));
            if ~isempty( char(S.DataLocationUuid) )
                obj.assignDataLocation(S.DataLocationUuid)
            end
        end

        function obj = fromJson(fileName)
            import nansen.metadata.abstract.Item
            obj = Item.fromJson(fileName, mfilename('class'));
        end
    end

    methods (Static, Access = ?nansen.dataio.DataVariable)
        function result = fromInitSpecificationScalar(...
                dataLocationName, variableName, initSpecificationStr)
            
            arguments
                dataLocationName (1,1) string 
                variableName (1,1) string 
                initSpecificationStr (1,1) string 
            end
            
            if contains(initSpecificationStr, ":")
                parts = split(initSpecificationStr, ":");
                fileDetails = parts{1};
                fileAdapterDetails = parts{2};
            else
                fileDetails = initSpecificationStr;
                fileAdapterDetails = string(missing);
            end

            if contains(fileDetails, "/")
                fileSeparator = "/";
            elseif contains(fileDetails, "\")
                fileSeparator = "\";
            else
                fileSeparator = string.empty;
            end

            if ~isempty(fileSeparator)
                parts = split(fileDetails, fileSeparator);
                subfolderDetails = parts{1};
                fileDetails = parts{2};
            else
                subfolderDetails = "";
            end

            [~, filenamePattern, fileExtension] = fileparts(fileDetails);
            
            fileAdapterName = '';
            if ~ismissing(fileAdapterDetails)
                if isempty(fileAdapterDetails)
                    keyboard
                    %Todo: Create fileadapter...

                else
                    fileAdapterName = fileAdapterDetails;
                end
            end

            result = nansen.dataio.DataVariable(...
                "VariableName", variableName, ...
                "Subfolder", subfolderDetails, ...
                "FileNameExpression", filenamePattern, ...
                "FileType", fileExtension, ...
                "FileAdapter", fileAdapterName);

            result.assignDataLocation(dataLocationName)
        end
    end
end
