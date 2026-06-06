function value = unWrap(value)
% unwrap - Unwrap a nested cell value
    isFinished = false;
    while ~isFinished
        if nansen.util.cell.isWrapped(value)
            value = value{1};
        else
            isFinished = true;
        end
    end
end
