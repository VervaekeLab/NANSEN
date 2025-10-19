function checkRequiredMathworksProducts(mode)
% checkRequiredMathworksProducts - Checks for required Mathworks products.
%
% Syntax:
%   nansen.internal.setup.checkRequiredMathworksProducts() Checks if the 
%   required Mathworks products for NANSEN are installed.

    arguments
        mode (1,1) string {mustBeMember(mode, ["warning", "error"])} = "warning"
    end

    versionInfo = ver();
    installedToolboxNames = {versionInfo.Name};

    requiredToolboxNames = nansen.internal.setup.getRequiredMatlabToolboxes();

    missingToolboxNames = setdiff(requiredToolboxNames, installedToolboxNames);
    missingToolboxNames = string(missingToolboxNames);

    if ~isempty(missingToolboxNames)
        missingToolboxNames = "  - " + missingToolboxNames;
        
        message = sprintf(...
            "The following required Mathworks products are needed for NANSEN " + ...
            "to work reliably:\n%s\n\nYou can install these from MATLAB's Add-On Manager.", ...
            strjoin(missingToolboxNames, newline));
        
        fcn = str2func(mode);
        fcn("NANSEN:MathworksProductCheck:MissingRequiredProducts", message)
    end
end
