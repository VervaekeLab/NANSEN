function tf = isRoiFormatValid(filepath, data)

    tf = false;
    %[~, name, ~] = fileparts(filepath);
    
    refVarNames = {'sessionData', 'roi_arr', 'RoiArray', 'roiArray'};
    
    if isa(data, 'struct')
        dataVarNames = fieldnames(data);
        isMatch = contains(dataVarNames, refVarNames);
        
        if any(isMatch)
            tf = true;
        end
    end
end