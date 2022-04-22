function [roiArray, classification, stats, images] = getRoiData(S)

    % Get roidata from a structure containing unknown set of fields. 
    
    % Initialize output
    roiArray = RoI.empty; %#ok<NASGU>
    classification = []; [stats, images] = deal( struct.empty );
    
    dataVariableNames = fieldnames(S);

    if contains('sessionData', fieldnames(S))
        S = S.sessionData;
        dataVariableNames = fieldnames(S);
    end

    refVariableNames = {'roi_arr', 'RoiArray', 'roiArray'};
    
    isMatch = contains(dataVariableNames, refVariableNames);
    
    
    if isempty(isMatch) || ~any(isMatch)
        error('Nansen:RoiGroupLoad:DataNotFound', ...
            'Did not find rois in the selected file')
        
    else
        if sum(isMatch) > 1; isMatch = find(isMatch, 1, 'first'); end

        roiArray = S.(dataVariableNames{isMatch});
        if isa(roiArray, 'struct')
            roiArray = roimanager.utilities.struct2roiarray(roiArray);

        end
    end

    if isa(roiArray, 'RoI') % struct and back again... necessary?
        roi_arr_struct = roimanager.utilities.roiarray2struct(roiArray);
        roiArray = roimanager.utilities.struct2roiarray(roi_arr_struct);
    end
    
    
    % Load complimentary variables (most of this is probably redundant by 
    % now, but roiClassification, roiImages and roiStats was not well 
    % incorporated before)
    % - - - - - - - - - - - - - - - - 
    
    numRois = numel(roiArray);
    
    if contains( 'roiClassification', dataVariableNames)
        classification = S.roiClassification;
        if numel(classification) ~= numRois
            warning('Roi classification vector did not match size of Roi Array. Classification vector was reset')
            classification = [];
        end
    end
    if isempty(classification)
        classification = zeros(numRois, 1);
    end
    
    if contains( 'roiStats', dataVariableNames)
        stats = S.roiStats;
        if ~isempty(stats)
            if ~isstruct(stats) || numel(stats) ~= numRois
                warning('Roi stats did not match size of Roi Array. Roi stats was reset')
                stats = struct.empty;
            end
        end
    end
    
    if contains( 'roiImages', dataVariableNames)
        images = S.roiImages;
        if ~isempty(images)
            if ~isstruct(images) || numel(images) ~= numRois
                warning('Roi image data did not match size of Roi Array. Image data was reset')
                images = struct.empty;
            end
        end
    end
    
    % Todo.. concatenate with others...
    roiArray = roiArray.setappdata('roiClassification', classification);
    roiArray = roiArray.setappdata('roiImages', images);
    roiArray = roiArray.setappdata('roiStats', stats);

end