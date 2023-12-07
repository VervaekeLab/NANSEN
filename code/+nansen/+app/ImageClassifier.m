classdef ImageClassifier < mclassifier.manualClassifier
    
    % Todo: Consider whether the superclass need to be abstract.

    properties
        
        classificationColors = { [0.174, 0.697, 0.492], ...
                                 [0.920, 0.339, 0.378], ...
                                 [0.176, 0.374, 0.908] }

        classificationLabels = { 'Accepted', 'Rejected', 'Unresolved' }
        guiColors = struct('Background',  [0.1020 0.1137 0.1294], ...
                           'Foreground', [0.8196 0.8235 0.8275])       
    end


    % Properties holding the item data for the GUI
    properties (Dependent)
        itemSpecs               % Struct array of different specifications per item
        itemImages              % Struct array of different images per item
        itemStats               % Struct array of different stats per item
        itemClassification      % Vector with classification status per item
    end

    properties (Dependent)
        dataFilePath            % Filepath to load/save data from
    end


    properties (SetAccess = private)
        ClassificationData
        SavePath = ''
    end

    methods % Structors

        function obj = ImageClassifier(varargin)
        %ImageClassifier Construct the image classifier app
        %
        %   Syntax:
        %       nansen.app.ImageClassifier(classificationData) opens an 
        %       instance of the image classifier given a set of 
        %       classification data.
        %
        %       nansen.app.ImageClassifier(filePath) opens an instance of 
        %       the image classifier given using previously saved
        %       classification data.
        %
        %       nansen.app.ImageClassifier(classificationData, 'SavePath', pathName) 
        %       also specifies a file path for saving results.
        %
        %   See also nansen.ui.data.ClassificationData

            % Todo: Should units always be scaled by default??
            varargin = [varargin, {'tileUnits', 'pixel'}];
            obj@mclassifier.manualClassifier(varargin{:})

            % Update tile callbacks because these are reset to default when
            % setting the tileUnits property of tiledImageAxes. Todo: Add
            % this to super class constructor...
            obj.setTileCallbacks()
            
            if ~nargout
                clear obj
            end
        end

    end

    methods %Set/get

        function set.dataFilePath(obj, value)
            obj.SavePath = value;
        end
        function filePath = get.dataFilePath(obj)
            filePath = obj.SavePath;
        end

        function specs = get.itemSpecs(obj)
            specs = obj.ClassificationData.Name;
        end
        
        function imData = get.itemImages(obj)
            imData = obj.ClassificationData.ImageData;
        end
           
        function classification = get.itemClassification(obj)
            classification = obj.ClassificationData.Classification;
        end
        function set.itemClassification(obj, newClassification)
            obj.ClassificationData.setClassification(newClassification);
        end
        
        function stats = get.itemStats(obj)
            stats = obj.ClassificationData.Statistics;
        end

    end

    methods
            
        function removeItems(obj, indToRemove)
            errordlg('Removal of items is not implemented yet.')
            return
        end

        function saveClassification(obj, ~, ~, varargin)
            
            if isempty(obj.SavePath)
                fileSpec = {'*.mat', 'Mat Files (*.mat)'};
                [filename, filePath, ~] = uiputfile(fileSpec);
                obj.SavePath = fullfile(filePath, filename);
            end
            
            S.ClassificationData = obj.ClassificationData;
            save(obj.SavePath, '-struct', 'S')
        end
    end

    methods (Access = protected) % Implement methods from mclassifier.manualClassifier
        
        function  nvpairs = parseInputs(obj, varargin)
            if isa(varargin{1}, 'nansen.ui.data.ClassificationData')
                obj.ClassificationData = varargin{1};
                varargin(1) = [];
            elseif isa(varargin{1}, 'char') || isa(varargin{1}, 'string')
                if isfile(varargin{1})
                    S = load(varargin{1});
                    obj.ClassificationData = S.ClassificationData;
                    varargin = ['SavePath', varargin{1}, varargin(2:end)];
                end
            else
                error('First input must be of type "nansen.ui.data.ClassificationData" ')
            end
            
            nvpairs = varargin;

            def = struct('SavePath', '');
            opt = utility.parsenvpairs(def, 1, nvpairs{:});
            propNames = fieldnames(opt);
            for i = 1:numel(propNames)
                obj.(propNames{i}) = opt.(propNames{i});
            end
        end
        
        function updateTile(obj, itemIndices, tileNumbers)

            % Accepts vector of item indices and tile numbers

            if nargin < 3 || isempty(tileNumbers)
                tileNumbers = find(ismember(obj.displayedItems, itemIndices));
            end

            if isempty(tileNumbers); return; end

            imageSelection = getCurrentImageSelection(obj);
            imageSize = obj.hTiledImageAxes.imageSize;

            try
                imageData = cat(3, obj.itemImages(itemIndices).(imageSelection));
            catch
                error('Not implemented for images of different size')
            end

            obj.hTiledImageAxes.updateTileImage(imageData, tileNumbers)

            % Update outline color according to classification
            obj.updateTileColor(tileNumbers)


            %cellOfStr = arrayfun(@(i) num2str(i), roiInd, 'uni', 0);
            roiLabels = obj.getItemText(itemIndices);
            obj.hTiledImageAxes.updateTileText(roiLabels, tileNumbers)

            % Reset linewidth of objects in all tiles
            % obj.hTiledImageAxes.updateTilePlotLinewidth(tileNumbers, 1)

            % Update linewidths of tiles with selected items.
            %tileNumbers = ismember(obj.displayedItems, obj.selectedItem);
            %obj.hTiledImageAxes.updateTilePlotLinewidth(tileNumbers, 2)
        end
        
        
        function onSelectedItemChanged(obj)
            % Pass
        end
        
    end

end