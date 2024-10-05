function C = sortlike(A, B, direction)

    if nargin < 3
        direction = 'ascend';
    end
    
    [~, ix] = sort(A, direction);
    C = B(ix);
end
