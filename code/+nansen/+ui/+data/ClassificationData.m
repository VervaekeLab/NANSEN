classdef ClassificationData < handle

    % Todo:
    %   [ ] Add methods for appending, inserting and removing elements.
    %   [ ] Only allow adding a base name for items?

    properties
        Description (1,1) string
    end
        
    properties (SetAccess = private)
        NumElements = []
    end

    properties
        ClassificationCategories = {'Accepted', 'Rejected', 'Unresolved'};
    end

    properties (SetAccess = private)
        Name (:, 1) string
        Info (:, 1) struct % Not implemented yet
        ImageData (:, 1) struct
        Classification (:, 1) uint8 % Todo: categorical
        Statistics (:, 1) struct

        % Todo:
        % PlotData
        % PlotType / PlotFunctionHandles
    end

    methods % Constructor
        function obj = ClassificationData(varargin)
            
        end
    end

    methods
        function addImageArray(obj, imageName, imageArray)
        %addImageArray - Add one or more image arrays to this instance
        %
        %   Syntax
        %       obj.addImageArray(imageName, imageArray)
        %
        %       obj.addImageArray(imageNameA, imageArrayA, imageNameB,
        %       imageArrayB, ...)

            arguments
                obj (1,1) nansen.ui.data.ClassificationData
            end

            arguments (Repeating)
                imageName (1,1) string
                imageArray (:,:,:) {mustBeNumeric}
            end
            
            numImages = cellfun(@(c) size(c,3), imageArray);
            
            assert( numel(unique(numImages))  == 1, ...
                'Image arrays must have the same size along the 3rd dimension' )
        
            numImages = numImages(1);

            obj.validateNumElements(numImages);
            
            if isempty(obj.ImageData)
                obj.ImageData = obj.initializeStructArray(imageName, numImages);
            end
            
            % Place individual images into individual elements of the struct array
            for i = 1:numel(imageName)
                thisName = imageName{i};
                thisImageArray = imageArray{i};
                thisImageCellArray = num2cell(thisImageArray, [1 2] );
                [obj.ImageData(:).(thisName)] = deal(thisImageCellArray{:});
            end
        end
        
        function addStatistics(obj, name, valueList)
        %addStatistics - Add one or more statistical value lists to this instance
        %
        %   Syntax
        %       obj.addStatistics(name, valueList)
        %
        %       obj.addStatistics(nameA, valueListA, nameB, valueListB, ...)
                    
            arguments
                obj (1,1) nansen.ui.data.ClassificationData
            end

            arguments (Repeating)
                name (1,1) string
                valueList (:,1) {mustBeNumeric}
            end

            numValues = cellfun(@(c) numel(c), valueList);
            
            assert( numel(unique(numValues))  == 1, ...
                'Lists of values must have the same number of elements' )
        
            numValues = numValues(1);

            obj.validateNumElements(numValues);
            
            if isempty(obj.Statistics)
                obj.Statistics = obj.initializeStructArray(name, numValues);
            end
            
            % Place individual images into individual elements of the struct array
            for i = 1:numel(name)
                thisName = name{i};
                thisValueList = valueList{i};
                thisValueListCellArray = num2cell(thisValueList);
                [obj.Statistics(:).(thisName)] = deal(thisValueListCellArray{:});
            end
        end

        function appendImages(obj, imageName, imageArray)
            error('Not implemented yet')
        end

        function insertImages(obj, imageName, indices, imageArray)
            error('Not implemented yet')
        end
        
        function addNames(obj, names)
        % addNames - Add names for each element

            arguments
                obj (1,1) nansen.ui.data.ClassificationData
                names (1,:) string
            end

            if numel(names)==1
                obj.Name = obj.createNames(names);
            else
                obj.validateNumElements(numel(names))
                obj.Name = names;
            end
        end
    end

    methods (Access = private)

        function validateNumElements(obj, numElements)
            if isempty(obj.NumElements)
                obj.NumElements = numElements;
                obj.initalizeProperties()
            else
                assert(numElements == obj.NumElements, ...
                    '%d elements were added, but the classification data contains %d elements', numElements, obj.NumElements)
            end
        end

        function initalizeProperties(obj)
            obj.Name = obj.createNames();
            obj.Classification = zeros(obj.NumElements, 1, 'uint8');

        end

        function nameList = createNames(obj, baseName)
            if nargin < 2
                baseName = "Item";
            end
            formatSpecifier = sprintf('%%0%dd', floor(log10(obj.NumElements)+1));
            nameList = arrayfun(@(i) sprintf(baseName+" "+formatSpecifier, i), 1:obj.NumElements);
        end

        function append()

        end

        function insert()

        end

        function remove()

        end
    end

    methods (Access = ?mclassifier.manualClassifier)
        function setClassification(obj, newClassification)
            obj.Classification = newClassification;
        end
    end

    methods (Static, Access = private)

        function S = initializeStructArray(name, numElements)
            data = repmat({[]}, 1,numElements);
            nvPairs = name; nvPairs(2,:) = {data};
            S = struct(nvPairs{:});
        end
    end
end
