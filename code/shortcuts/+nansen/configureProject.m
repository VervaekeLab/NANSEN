function configureProject(flags, options)
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
        flags (1,1) string {mustBeMember(flags, ["d", "dependencies", "v", "variables"])}
    end
    arguments
        options.CreateNew (1,1) logical = false;
    end

    flags = string(flags);
    
    if options.CreateNew
        pagesToShow = "ProjectTab";
    else
        pagesToShow = string.empty();

        % Make sure there is a project to configure
        if isempty(nansen.getCurrentProject)
            projectManager = nansen.ProjectManager();
            if projectManager.NumProjects == 0
                ME = MException('NANSEN:Projects:NoAvailableProject', ...
                    'There are no available projects to configure. Please run nansen.createProject()');
                throwAsCaller(ME)
            else
                projectManager.uiSelectProject()
            end
        end
    end

    pagesToShow = [pagesToShow, "ModulesTab"];

    if any(flags == "d") || any(flags == "dependencies")
        pagesToShow = [pagesToShow, "AddonsTab"];
    end

    pagesToShow = [...
        pagesToShow, ...
        "DataLocationsTab", ...
        "FolderHierarchyTab", ...
        "MetadataTab" ...
    ];

    if any(flags == "v") || any(flags == "variables")
        pagesToShow(end+1) = "VariablesTab";
    end

    nansen.app.setup.SetupWizard(pagesToShow)
end
