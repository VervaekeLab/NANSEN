function [pos, siz] = subdividePosition(posInit, lengthInit, sizeSpecs, spacing)


    % Count number of panels
    numDivisions = numel(sizeSpecs);

    % Remove panel spacing from the available length
    availableLength = lengthInit - spacing*(numDivisions-1);


    if isempty(sizeSpecs)
        lengthPix = ones(1, numDivisions) .* availableLength ./ numDivisions;
    else
        if iscolumn(sizeSpecs); sizeSpecs = sizeSpecs'; end
        % Convert to pixels...

        % Initialize vector for panel lengths in pixels
        lengthPix = zeros(1, numDivisions);

        % Check if any size specs are in pixels
        isPixelSize = sizeSpecs > 1;
        lengthPix(isPixelSize) = sizeSpecs(isPixelSize);

        remainingLength = availableLength - sum(lengthPix);

        % Distribute remaning for panels specified in normalized
        % units
        lengthPix(~isPixelSize) = sizeSpecs(~isPixelSize) .* remainingLength;
    end


    % Get lengths for each panel and correct for rounding errors 
    % by adding 1 pixel to each panel starting at first panel 
    % and ending at the nth panel as needed to make sure panels 
    % correctly fill the available length.

    lengthPix = floor( lengthPix ); % Round down
    rem = floor( availableLength - sum(lengthPix) ); % Get remainders

    extra = zeros(1, numDivisions); 
    extra(1:rem) = 1; % Distribute remainders

    siz = lengthPix + extra; % Add remainders to lengths

    % Calculate the location values for all panels
    pos = cumsum( [1, siz(1:end-1)] ) + (0:numDivisions-1) .* spacing;
    pos = pos + posInit;
end
