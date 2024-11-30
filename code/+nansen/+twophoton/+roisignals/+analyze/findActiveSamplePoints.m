function IND = findActiveSamplePoints(signal, varargin)

    % Set activity threshold.
    % Todo: Optimize this based on more  informed methods.

    val = prctile(signal, [5, 50]);
    thresh = val(2) - (val(2)-val(1));
    
    TF = signal > thresh;
    if isrow(signal)
        TF = imdilate( TF, ones(1,5) );
    elseif iscolumn(signal)
        TF = imdilate( TF, ones(5,1) );
    end
    
    IND = find(TF);
    
end
