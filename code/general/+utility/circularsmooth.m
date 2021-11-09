function data = circularsmooth(data, N, method)
% Note: Only works for vectors.

    if nargin < 3
        method = 'movmean';
    end

    % Make sure data is a column vector
    if isrow(data)
        data = data';
        isTransposed = true;
    else
        isTransposed = false;
    end

    % Add circular padding
    data = cat(1, data(end-N+1:end), data, data(1:N)); 

    data = smoothdata(data, 1, method, N);
    
    % Remove circular padding
    data = data((1+N):end-N);
    
    % Make sure output has same shape as input
    if isTransposed
        data = data';
    end

end