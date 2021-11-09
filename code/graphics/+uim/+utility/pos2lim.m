function limits = pos2lim(position)
    numRows = size(position, 1);
    limits = position(:, [1,2,1,2]) + [ zeros(numRows, 2),  position(:, 3:4)];
end