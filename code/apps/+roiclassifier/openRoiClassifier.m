function hClassifier = openRoiClassifier(varargin)
%openRoiClassifier Open roiClassifier
%
%   hClassifier = openRoiClassifier(roiData)
%       roiData is a struct with the following fields: roiArray, roiImages,
%       roiStats, roiClassification
%
%   hClassifier = openRoiClassifier(roiGroup) is a roimanager.roiGroup
%
%   hClassifier = openRoiClassifier(roiArray, imageStack) 

    roiData = struct.empty;
    roiGroup = [];
    
    vararginType = cellfun(@(c) class(c), varargin, 'uni', 0);
        
    if isa( varargin{1}, 'struct' )
        dataFields = fieldnames(varargin{1});
        
        if all( ismember({'roiArray', 'roiImages', 'roiStats', 'roiClassification'}, dataFields) )
            roiData = varargin{1};
        end
       
    elseif isa(varargin{1}, 'RoI')
        
        if isa(varargin{2}, 'nansen.stack.ImageStack') 
            roiData = roiclassifier.prepareRoiData(varargin{1:2});
        end
        
    elseif isa(varargin{1}, 'roimanager.roiGroup')
        if nargin >= 2 && ~isempty(varargin{2}) && isa(varargin{2}, 'nansen.stack.ImageStack') 
            roiData = roiclassifier.prepareRoiData(varargin{1:2});
        
        else
            roiGroup = varargin{1};
        end
    end
    
    
    if ~isempty(roiData)
        roiArray = roiData.roiArray;       
        roiArray = roiArray.setappdata('roiImages', roiData.roiImages);
        roiArray = roiArray.setappdata('roiStats', roiData.roiStats);
        roiArray = roiArray.setappdata('roiClassification',  roiData.roiClassification);

        roiGroup = roimanager.roiGroup(roiArray);
    end
    
    if isempty(roiGroup)
        error('Input is not valid for roi classifier app')
    end

    nvPairs = {};
    if isa(varargin{end}, 'struct')
        if isfield(varargin{end}, 'RoiSelectedCallbackFunction')
            fcnName = varargin{end}.RoiSelectedCallbackFunction;
            if ~isempty(fcnName)
                nvPairs = {'RoiSelectedCallbackFunction', str2func(fcnName)};
            end
        end
    end

    hClassifier = roiclassifier.App(roiGroup, 'tileUnits', 'scaled', nvPairs{:});


end