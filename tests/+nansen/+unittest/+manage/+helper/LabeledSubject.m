classdef LabeledSubject < nansen.metadata.type.Subject
%LabeledSubject - A subject type with one property that nansen.metadata.type.Subject lacks
%
%   Tests use it as the class of a subject table, to check that functions
%   which add subjects create them with the class of the table.

    properties (SetObservable)
        Label char
    end
end
