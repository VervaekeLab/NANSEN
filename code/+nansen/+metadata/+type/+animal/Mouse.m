classdef Mouse < nansen.metadata.type.Animal
    properties
        cageNumber      single                     % (REQ) Number of cage in SL
        animalNumber    single                     % (REQ) Number of mouse in SL
        earMark         single                     % (OPT) Earmark number if any
    end
end
