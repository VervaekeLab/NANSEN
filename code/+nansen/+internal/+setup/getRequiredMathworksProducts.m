function requiredToolboxNames = getRequiredMathworksProducts(options)
%getRequiredMathworksProducts Get names of required MathWorks toolboxes.
%
%   requiredToolboxNames = nansen.internal.setup.getRequiredMathworksProducts()
%   returns the names of required MathWorks toolboxes for core NANSEN.
%
%   requiredToolboxNames = nansen.internal.setup.getRequiredMathworksProducts(Name, Value)
%   accepts additional options for module-aware checking.
%
%   Name-Value Arguments:
%       ModuleNames (string array) - Module scope IDs to include.
%           Default: string.empty (core only).
%       RequirementLevel (string) - Filter by level: "all", "required",
%           "optional". Default: "required".
%
%   Output:
%       requiredToolboxNames (string array) - Names of the required
%           MathWorks toolboxes.

    arguments
        options.ModuleNames (1,:) string = string.empty
        options.RequirementLevel (1,1) string ...
            {mustBeMember(options.RequirementLevel, ...
                ["all", "required", "optional"])} = "required"
    end

    requirementLevels = string.empty;
    if options.RequirementLevel ~= "all"
        requirementLevels = options.RequirementLevel;
    end
    resolvedRequirements = nansen.internal.dependencies.resolveRequirements( ...
        "SelectedModules", options.ModuleNames, ...
        "DependencyTypes", "mathworks-product", ...
        "RequirementLevels", requirementLevels);

    if isempty(resolvedRequirements)
        requiredToolboxNames = string.empty;
    else
        requiredToolboxNames = [resolvedRequirements.Name];
    end
end
