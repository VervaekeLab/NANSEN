function roiArray = getrois(sVar)
    % Function that loads roi array from sData or sessionID
    
    if strcmp(sVar, fovmanager.utility.atlas.strfindsid(sVar)) % sVar is a session Id
        
        % Insert/replace code here:
        try
            roiArray = loaddata(sVar, 'roi_arr', []); % Eivind's example
        
        % Try one more time....
        catch
            sData = fovmanager.fileio.getdata(sVar, 'roiArray');
            roiArray = sData.roiArray;
        end
        
    elseif isa(sVar, 'char') && contains(sVar, '.mat') % sVar is a sdata path (hopefully)
        
        S = load(sVar);
        roiArray = S.sData.imdata.roiArray;
        
    end
    
    

end