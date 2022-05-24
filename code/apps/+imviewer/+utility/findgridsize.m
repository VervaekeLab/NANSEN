function [nRows, nCols] = findgridsize(n, squareAr, fullAr)

if nargin < 2
    squareAr = 1; % SquareAspecratio...?
end

if nargin < 3
    lowerlim = 4/3;
    upperlim = 16/9;
else
    upperlim = fullAr+0.2;
    lowerlim = fullAr-0.2;
end

finished = false;

while ~finished

    factors = factor(n);
    
    if numel(factors) == 1
        n=n+1;
        continue
    end
    
    P = perms(factors);
    P = unique(P, 'rows');

    candidates = zeros(0, 2);
    
    nFactors = numel(factors);
    for i = 1 : floor(nFactors / 2)
        
        prod1 = arrayfun( @(j) sprintf('P(:, %d)', j), 1:i , 'uni', 0 );
        prod2 = arrayfun( @(j) sprintf('P(:, %d)', j), i+1:nFactors , 'uni', 0 );
        
        prod1 = strcat(prod1{:});
        prod2 = strcat(prod2{:});
        
        prod1 = strrep(prod1, ')P', ').*P' );
        prod2 = strrep(prod2, ')P', ').*P' );
        
        prod1 = eval( prod1 );
        prod2 = eval( prod2 );
        
        candidates = vertcat(candidates, horzcat(prod1, prod2));
        candidates = unique(candidates, 'rows');
        
    end
    
    candidates = vertcat(candidates, fliplr(candidates));
    
    ratio = candidates(:,1) ./ candidates(:,2);
        
%     lowerlim = 4/3;
%     upperlim = 16/9;
    
    hits = ratio < upperlim & ratio > lowerlim;
    
    if any(hits)
        candidates = candidates(find(hits), :);
        nCols = candidates(1, 1); nRows = candidates(1, 2);
        finished = true;
    else
        n = n+1;
    end
    
    
end
        