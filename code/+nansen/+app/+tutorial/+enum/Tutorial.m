classdef Tutorial
    enumeration
        TwoPhotonQuickstart("Nansen - Two-photon Quickstart")
        ABO_VisualCodingEphys("Allen Brain Observatory - Visual Coding (Neuropixels)")
        %ABO_VisualCodingOphys("Allen Brain Observatory - Visual Coding (Calcium Imaging)")
        %EBRAINS_Ophys_Demo("EBRAINS D&K - L2/3 + L5 Visual occlusion (Calcium Imaging)");
    end

    properties
        Title (1,1) string
        ProjectName (1,1) string
        RepositoryName (1,1) string
    end

    methods
        function obj = Tutorial(titleStr)
            obj.Title = titleStr;

            switch titleStr
                case "Nansen - Two-photon Quickstart"
                    obj.RepositoryName = "Nansen_Demo";
                    obj.ProjectName = 'nansen_demo';
        
                case "Allen Brain Observatory - Visual Coding (Neuropixels)"
                    obj.RepositoryName = "ABO-VisualCoding-Neuropixels-Test";
                    obj.ProjectName = 'abo_ephys';
        
                case "Allen Brain Observatory - Visual Coding (Calcium Imaging)"
                    obj.RepositoryName = "ABO-VisualCoding-TwoPhoton-Test";
                    obj.ProjectName = 'abo_ophys';
        
                case "EBRAINS D&K - L2/3 + L5 Visual occlusion (Calcium Imaging)"
                    obj.RepositoryName = "EBRAINS-VisualOcclusion-TwoPhoton";
                    error('Not implemented yet')
            end
        end
    end
end
