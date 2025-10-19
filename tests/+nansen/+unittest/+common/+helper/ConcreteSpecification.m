classdef ConcreteSpecification < nansen.common.abstract.Specification

    properties (Constant)
        TYPE = "ConcreteSpecification"
        VERSION = "1.0.1"
    end

    properties (Access = protected)
        RequiredProperties = ["Name", "RequiredValue"];
    end

    properties
        Name (1,1) string = missing
        RequiredValue (:,1) double = []
        OptionalValue (:,1) double = []
    end
end