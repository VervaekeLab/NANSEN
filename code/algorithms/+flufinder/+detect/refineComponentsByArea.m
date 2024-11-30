function S = refineComponentsByArea(S, varargin)

    % Get rid of obviously large outliers to minimize overlapping candidates:
    medianArea = median([S.Area]);
    medianRadius = sqrt(medianArea/pi);

    areaCutoff = pi * (1.5*medianRadius)^2;
    keep = [S.Area] < areaCutoff;
    S = S(keep);

    % Use a 2 STD cutoff for the rest:
    areaCutoff = median([S.Area])+2*std([S.Area]);
    keep = [S.Area] < areaCutoff;
    S = S(keep);
        
end
