classdef Subject < nansen.metadata.abstract.BaseSchema
%Subject A metadata schema/type for an experimental subject.

    % Set metaObject abstract properties
    properties (Constant, Hidden)
        ANCESTOR = ''
        IDNAME = 'SubjectID'
    end

    properties (Access = protected)
        ancestorID      % Add some validation scheme.... Can I dynamically set this according to some criteria?
    end
    
    properties
        SubjectID         char
        DateOfBirth       char
        BiologicalSex     char
        Species           char
        Strain            char % /or enum
    end

    properties (Access = private, Constant)
        Description = ''
    end
    
end