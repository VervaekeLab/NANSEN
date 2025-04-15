function configureProject(flags)
% configureProject - Runs the project setup wizard.
%
% Syntax:
%   nansen.configureProject() opens the project setup wizard with a minimal
%   set of pages
%
%   nansen.configureProject(flags) opens the project setup wizard with an
%   extended set of pages
%
% Input Arguments:
%   flags (1,1) string - A list of flags that determine which tabs to display.
%       Valid options are "d" for dependencies, "v" for variables.
%
% Examples:
%   Opens the project setup wizard with the minimal set of pages, but also
%   adds a page for configuring variables.
%
%   nansen.configureProject("v") 

    arguments (Repeating)
        flags (1,1) string {mustBeMember(flags, ["d", "depenencies", "v", "variables"])}
    end
    flags = string(flags);

    pagesToShow = [...
        "ProjectTab", ...
        "ModulesTab", ...
        "DataLocationsTab", ...
        "FolderHierarchyTab", ...
        "MetadataTab" ...
        ];

    if any(flags == "v") || any(flags == "variables")
        pagesToShow(end+1) = "VariablesTab";
    end

    if any(flags == "d") || any(flags == "depenencies")
        pagesToShow = [pagesToShow(1:2), "AddonsTab", pagesToShow(3:end)];
    end

    nansen.app.setup.SetupWizard(pagesToShow)
end
