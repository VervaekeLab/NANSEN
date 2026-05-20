classdef EventCounter < handle
%EventCounter Simple handle-based event counter for unit tests.
%
%   counter = EventCounter()
%   addlistener(obj, 'SomeEvent', @counter.increment)
%   counter.Count   % number of times the event fired

    properties
        Count (1,1) double = 0
    end

    methods
        function increment(obj, ~, ~)
            obj.Count = obj.Count + 1;
        end
    end
end
