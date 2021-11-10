function roiArray = getrois(sVar)
    % Function that loads roi array from sData or sessionID
    
    % Will be replaced by getdata in a future version
    
    if strcmp(sVar, fovmanager.utility.atlas.strfindsid(sVar)) % sVar is a session Id
        
        % Insert/replace code here:
        roiArray = loaddata(sVar, 'roi_arr'); % Eivind's example
        
    elseif isa(sVar, 'char') && contains(sVar, '.mat') % sVar is a sdata path (hopefully)
        
        S = load(sVar);
        roiArray = S.sData.imdata.roiArray;
        
    end

end