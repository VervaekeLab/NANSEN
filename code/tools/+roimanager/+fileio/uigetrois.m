function [S, filePath] = uigetrois()
    
    [roiFileName, filePath, ~] = uigetfile({'*.mat', 'Mat Files (*.mat)'; ...
                                          '*', 'All Files (*.*)'}, ...
                                          'Find Roi File', ...
                                          '', 'MultiSelect', 'off');

    if filePath==0; S=[]; return; end
    
    filePath = fullfile(filePath, roiFileName);
    S = load(filePath);
    
    field = fieldnames(S);
    
    % Fix variable name
    if contains(field, 'roi_arr')
        S.roiArray = S.roi_arr;
        S = rmfield(S, 'roi_arr');
    end

end