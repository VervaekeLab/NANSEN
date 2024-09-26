function snakecaseStr = label2snakecase(label)
    %label2snakecase Convert a text label to  snake case
    %
    %
    
    label = strrep(label, ' ', '_');
    
    % Remove symbols. Todo: generalize this
    label = strrep(label, '(', '');
    label = strrep(label, ')', '');
    label = strrep(label, '-', '_');
    label = strrep(label, '/', '');
    
    snakecaseStr = lower(label);

end
