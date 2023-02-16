classdef StackMetadata < nansen.dataio.metadata.AbstractMetadata
%ImageMetadata Class representing metadata for an imagestack   
    
    % A stack can be 2D to 5D arrays consisting of data of minimum 2
    % dimension (X,Y) and maximum 5 dimension (X,Y,C,Z,T)
    
    properties % Naming derived from the OME.XML schema (http://www.openmicroscopy.org/Schemas/OME/2016-06)
        
        DimensionArrangement char        % Describes stack dimension arrangement
        Size = []                        % Size of data along each dimension
        Class = '';                      % Class (data type) of image data
        
        SizeX (1,1) double = 1           % Dimensional size of image data array
        SizeY (1,1) double = 1           % Dimensional size of image data array
        SizeZ (1,1) double = 1           % Dimensional size of image data array
        SizeC (1,1) double = 1           % Dimensional size of image data array
        SizeT (1,1) double = 1           % Dimensional size of image data array
        
        PhysicalSizeX (1,1) double = 1   % Physical width of a pixel. um per pixel
        PhysicalSizeY (1,1) double = 1   % Physical height of a pixel. um per pixel
        PhysicalSizeZ (1,1) double = 1   % Physical distance between planes. 
        PhysicalSizeXUnit char = 'pixel' % The units of the physical size of a pixel.
        PhysicalSizeYUnit char = 'pixel' % The units of the physical size of a pixel.
        PhysicalSizeZUnit char = 'pixel' % The units of the physical distance between planes.
        
        TimeIncrement (1,1) double = 1   % Duration between image frames. 
        TimeIncrementUnit char = 'N/A'

        StartTime datetime
        SpatialPosition (1,3) double    % Spatial position (x,y,z)
    end
    
    properties
        ChannelDescription
        ChannelIndicator
    end
    
    properties
        FrameTimes = [];                % Vector of frame times
        FramePositions = [];
    end

    properties (Dependent, Transient)
        ImageSize                       % Size of image in physical units
        SampleRate (1,1) double         % Inverse time step
        SpatialLength (1,3) double      % Spatial resolution (x,y,z)
        SpatialUnits (1,3) cell         % Spatial units (x,y,z)
    end

    methods % Constructor
        
        function obj = StackMetadata(filePath)
            if nargin == 0
                return
            else
                obj.assignFilepath(filePath)
                obj.readFromFile()
            end
        end
        
    end
    
    methods % Set/get
        
        function sampleRate = get.SampleRate(obj)
            
            if contains( obj.TimeIncrementUnit, 'second')
%                 prefix = strrep(obj.TimeIncrementUnit, 'second', '');
%                 if ~isempty(prefix)
%                     prefix = nansen.dataio.metadata.SIUnitPrefix(prefix);
%                     timeStep = prefix.getValue(obj.TimeIncrement);
%                 else
                    timeStep = obj.TimeIncrement;
%                 end
                sampleRate = 1 / timeStep;
            else
                sampleRate = nan;
            end
            
        end
        
        function set.SampleRate(obj, newValue)
            obj.TimeIncrement = 1./newValue;
            obj.TimeIncrementUnit = 'second';
        end
        
        function imageSize = get.ImageSize(obj)
            imageSize = [obj.SizeX .* obj.PhysicalSizeX, ...
                            obj.SizeY .* obj.PhysicalSizeY ];
        end
        
        function set.ImageSize(obj, newValue)
            
            if numel(newValue) == 1
                newValue = [newValue, newValue];
            end
            
            obj.PhysicalSizeX = newValue(1) ./ obj.SizeX;
            obj.PhysicalSizeY = newValue(2) ./ obj.SizeY;
            
        end
        
        function spatialLength = get.SpatialLength(obj)
            spatialLength = [obj.PhysicalSizeX, ...
                obj.PhysicalSizeY, obj.PhysicalSizeZ];
        end
        
        function spatialUnits = get.SpatialUnits(obj)
            spatialUnits = {obj.PhysicalSizeXUnit, ...
                obj.PhysicalSizeYUnit, obj.PhysicalSizeZUnit};
        end
        
        function physSize = getPhysicalSize(obj)
            physSize = [obj.ImageSize,  obj.SizeZ .* obj.PhysicalSizeZ ];
        end
        
        function physUnits = getPhysicalUnits(obj)
            physUnits = {obj.PhysicalSizeXUnit, ...
                obj.PhysicalSizeYUnit, obj.PhysicalSizeZUnit};
        end
    end
    
    methods

        function save(obj)
            writeToFile(obj)
        end
        
        function updateTimeUnit(obj)
            % Todo: Turn 0.001 second into 1 microsecond etc.
        end
        
        function readFromFile(obj)
            if isempty(obj.Filename); return; end
            %obj.ini2yaml(obj.Filename) 
            readFromFile@nansen.dataio.metadata.AbstractMetadata(obj)
        end

        function writeToFile(obj)
            if isempty(obj.Filename); return; end
            writeToFile@nansen.dataio.metadata.AbstractMetadata(obj)
            %obj.yaml2ini(obj.Filename)
        end
        
        function addSectionToMetadata(obj, S, sectionName)
            
            tempFilename = [tempname, '.yaml'];
            yaml.WriteYaml(tempFilename, S);
            obj.yaml2ini(tempFilename, sectionName);
            
            textStr = fileread(tempFilename);
            delete(tempFilename)
            
            fid = fopen(obj.Filename, 'a');
            fwrite(fid, textStr);
            fclose(fid);
            
            
        end
        
        function updateFromSource(obj, S)
            % Rename UpdateFromReference
            fieldNames = {'PhysicalSizeX', 'PhysicalSizeXUnit', ...
                'PhysicalSizeY', 'PhysicalSizeYUnit', 'PhysicalSizeZ', ...
                'PhysicalSizeZUnit', 'TimeIncrement', 'TimeIncrementUnit', ...
                'StartTime', 'SpatialPosition', 'DimensionArrangement'};
            
            obj.fromStruct(S, fieldNames)
            
        end
        
        function uiset(obj, src, evt)
        %uiset Callback for value changed from gui
            
            
        end
        
    end
    
    methods (Access = protected)
        
        function S = toStruct(obj)
            S = toStruct@nansen.dataio.metadata.AbstractMetadata(obj);
            datestrFormat = 'YYYY_MM_DD_HH_MM_SS_sss';
            S.StartTime = datestr(S.StartTime, datestrFormat);
        end
        
        function fromStruct(obj, S, propertyNames)
            
            if nargin < 3
                propertyNames = fieldnames(S);
            end
            
            if ~isfield(S, 'StartTime') || isempty(S.StartTime)
                S.StartTime = datetime.empty;
            else
                datestrFormat = 'YYYY_MM_DD_HH_MM_SS_sss';
                S.StartTime = datetime(S.StartTime, 'InputFormat', datestrFormat);
            end
            
            if isfield(S, 'Size') && isa(S.Size, 'cell')
                S.Size = cell2mat(S.Size);
            end
            
            if isfield(S, 'ImageResolution') && isa(S.ImageResolution, 'cell')
                S.ImageResolution = cell2mat(S.ImageResolution);
            end
            if isfield(S, 'SpatialPosition') &&  isa(S.SpatialPosition, 'cell')
                S.SpatialPosition = cell2mat(S.SpatialPosition);
            end
            if isfield(S, 'FrameTimes') &&  isa(S.FrameTimes, 'cell')
                S.FrameTimes = cell2mat(S.FrameTimes);
            end
            
            fromStruct@nansen.dataio.metadata.AbstractMetadata(obj, S, propertyNames)
        end
        
        function propertyNames = getPropertyNames(obj)
            % Skip dependent properties...
            propertiesSkip = {'ImageSize', 'SampleRate', 'SpatialLength', 'SpatialUnits'};
            propertyNames = properties(obj);
            propertyNames = setdiff(propertyNames, propertiesSkip, 'stable');
        end
        
    end
    

    methods (Static)

        function ini2yaml(filename)
            textStr = fileread(filename);
            textStr = strrep(textStr, '=', ':');
            textStr = regexprep(textStr, '\n[', '\n#[');
            fid = fopen(filename, 'w');
            fwrite(fid, textStr);
            fclose(fid);
        end
        
        function yaml2ini(filename, sectionName)
            
            textStr = fileread(filename);
            % Correct(?) format of struct with only scalars
            if strcmp(textStr(1), '{') && strcmp(textStr(end-1), '}') 
                textStr = [strrep( textStr(2:end-2), ', ', newline ), newline];
            end
            
            textStr = strrep(textStr, ':', ' =');
            
% %             sectionName = sprintf('[%s]\n', sectionName);
% %             textStr = sprintf('%s%s', sectionName, textStr);
            
            fid = fopen(filename, 'w');
            fwrite(fid, textStr);
            fclose(fid);
        end
        
    end

end