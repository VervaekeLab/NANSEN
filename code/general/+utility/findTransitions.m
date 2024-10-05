function [ eventStartIdx, eventStopIdx ] = findTransitions( eventVector )
%findTransitions Find the transitions in an eventVector
%   [ eventStartIdx, eventStopIdx ]  = findTransitions( eventVector )
%   returns the indices in the eventVector where an event starts or stops.
%
%   Written by Eivind Hennestad | Vervaeke Lab

%   Todo: Adapt to all integer vectors...

    % Check that vector is an "event vector"
    msg = 'Input (eventVector) should consist of zeros and ones only';
    assert( all(ismember( unique(eventVector), [0,1] )), msg)

    % Find out if event vector is column or row
    if iscolumn(eventVector)
        dim = 1;
    elseif isrow(eventVector)
        dim = 2;
    else
        error('eventVector must be a row or column vector')
    end

    % Find transitions (start and stop) in the events vector
    eventStartStop = diff(eventVector);
    eventStartIdx = find((eventStartStop == 1)) + 1; % diff shifts start transition 1 step forward, so add one...
    eventStopIdx = find(eventStartStop == -1); % ...but stop transition is already one step after. Makes sense?
    
    % Maybe event is ongoing in the beginning or in the end?
    if eventVector(1)
        eventStartIdx = cat(dim, 1, eventStartIdx);
    end
    
    if eventVector(end)
        eventStopIdx = cat(dim, eventStopIdx, numel(eventVector));
    end
end
