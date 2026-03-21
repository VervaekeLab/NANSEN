function checkRequiredMathworksProducts(mode, options)
%checkRequiredMathworksProducts Check for required MathWorks products.
%
%   nansen.internal.dependencies.checkRequiredMathworksProducts() checks if the
%   required MathWorks products for core NANSEN are installed.
%
%   nansen.internal.dependencies.checkRequiredMathworksProducts(mode) uses the
%   specified mode ("warning" or "error") for reporting missing products.
%
%   nansen.internal.dependencies.checkRequiredMathworksProducts(mode, Name, Value)
%   accepts additional options for module-aware checking.
%
%   Name-Value Arguments:
%       ModuleNames (string array) - Module scope IDs to include in the
%           check. Default: string.empty (core only).

    arguments
        mode (1,1) string {mustBeMember(mode, ["warning", "error"])} = "warning"
        options.ModuleNames (1,:) string = string.empty
    end

    % Use the resolver to get missing required MathWorks products
    missingProducts = nansen.internal.dependencies.resolveRequirements( ...
        "SelectedModules", options.ModuleNames, ...
        "DependencyTypes", "mathworks-product", ...
        "RequirementLevels", "required", ...
        "MissingOnly", true);

    if isempty(missingProducts)
        return
    end

    missingNames = "  - " + [missingProducts.Name];

    message = sprintf( ...
        "The following required MathWorks products are needed for NANSEN " + ...
        "to work reliably:\n%s\n\nYou can install these from MATLAB's " + ...
        "Add-On Explorer.", ...
        strjoin(missingNames, newline));

    reportFunction = str2func(mode);
    reportFunction("NANSEN:MathworksProductCheck:MissingRequiredProducts", message)
end
