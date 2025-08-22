classdef DynamicFileAdapter < nansen.dataio.FileAdapter
    
    properties (SetAccess = private)
        Description (1,1) string  = ""
    end

    properties (Access = private)
        ReadFunction
        WriteFunction
        ViewFunction
    end

    properties (GetAccess = private, SetAccess = immutable)
        FileAdapterNamespace (1,1) string
        FileAdapterDefinitionPath (1,1) string
    end
    properties (Access = private, Dependent)
        FileAdapterFolder (1,1) string
    end
    
    properties (Constant)
        DataType = ""
    end

    properties (Constant, Access = protected) % Todo: SetAccess = immutable
        SUPPORTED_FILE_TYPES = {}
    end

    methods
        function obj = DynamicFileAdapter(fileAdapterName, filePath)
            obj = obj@nansen.dataio.FileAdapter(filePath);
            obj.FileAdapterNamespace = fileAdapterName;
            obj.FileAdapterDefinitionPath = obj.resolveName(fileAdapterName);
            metadata = obj.readFileAdapterMetadata(obj.FileAdapterDefinitionPath);
            obj.Description = metadata.Description;

            obj.detectReadFunction(metadata)
            obj.detectWriteFunction(metadata)
            obj.detectViewFunction(metadata)
        end
    end

    methods
        function folderPath = get.FileAdapterFolder(obj)
            folderPath = fileparts(obj.FileAdapterDefinitionPath);
        end
    end

    methods (Access = protected)
        function data = readData(obj)
            data = obj.ReadFunction(obj.Filename);
        end

        function writeData(obj, data)
            if ~isempty(obj.WriteFunction)
                obj.WriteFunction(obj.Filename, data)
            else
                error('File adapter is read only') % Todo: Reuse superclass exception
            end
        end
    end
    methods
        function view(obj)
            if ~isempty(obj.ViewFunction)
                data = obj.readData();
                obj.ViewFunction(data)
            else
                error('File adapter does not have a viewer') % Todo: Reuse superclass exception
            end
        end
    end

    methods (Access = protected) % Internal methods
        function assertIsWritable(obj)
            assertMsg = 'This file adapter does not have write permission';
            assert(~isempty(obj.WriteFunction), assertMsg)
        end
    end
    
    methods (Access = private)
        function detectReadFunction(obj, metadata)
            readFunctionName = '';
            if ~isempty(metadata.ReadFunction)
                readFunctionName = metadata.ReadFunction;
            else
                if isfile( fullfile(obj.FileAdapterFolder, 'read.m') )
                    readFunctionName = obj.FileAdapterNamespace + '.read';
                end
            end
            if ~isempty(readFunctionName)
                obj.ReadFunction = str2func(readFunctionName);
            end
        end
        
        function detectWriteFunction(obj, metadata)
            writeFunctionName = '';
            if ~isempty(metadata.WriteFunction)
                writeFunctionName = metadata.WriteFunction;
            else
                if isfile( fullfile(obj.FileAdapterFolder, 'write.m') )
                    writeFunctionName = obj.FileAdapterNamespace + '.write';
                end
            end
            if ~isempty(writeFunctionName)
                obj.WriteFunction = str2func(writeFunctionName);
            end
        end

        function detectViewFunction(obj, metadata)
            viewFunctionName = '';
            if ~isempty(metadata.ViewFunction)
                viewFunctionName = metadata.ViewFunction;
            else
                if isfile( fullfile(obj.FileAdapterFolder, 'view.m') )
                    viewFunctionName = obj.FileAdapterNamespace + '.view';
                end
            end
            if ~isempty(viewFunctionName)
                obj.ViewFunction = str2func(viewFunctionName);
            end
        end
    end
    
    methods (Static)
        function filePath = resolveName(fileAdapterName)
            fileAdapterNamespace = replace(fileAdapterName, '.', [filesep, '+']);
            s = what(fileAdapterNamespace);
            assert(numel(s) == 1, ...
                'Expected to find exactly one file adapter definition for %s', fileAdapterName);
            
            filePath = fullfile(s.path, 'fileadapter.json');
        end

        function fileadapterProps = readFileAdapterMetadata(metadataFilePath)
            metadata = jsondecode(fileread(metadataFilePath));
            % Todo: Assert valid metadata
            fileadapterProps = metadata.Properties;
        end
    end
end
