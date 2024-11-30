function regionLabels = mergeRegions(regionLabels)
%brainmap.mergeRegions Merge names for some of the regions of the paxinos map

    % Merge some regions.
    regionLabels = strrep(regionLabels, 'RSCa', 'RSC');
    regionLabels = strrep(regionLabels, 'RSCg', 'RSC');
    
    regionLabels = strrep(regionLabels, 'mPPC', 'PPC');
    regionLabels = strrep(regionLabels, 'lPPC', 'PPC');
    
    regionLabels = strrep(regionLabels, 'S1Tr', 'S1');
    regionLabels = strrep(regionLabels, 'S1Sh', 'S1');
    regionLabels = strrep(regionLabels, 'S1HL', 'S1');
    regionLabels = strrep(regionLabels, 'S1FL', 'S1');
    
    regionLabels = strrep(regionLabels, 'V2MM', 'V2');
    regionLabels = strrep(regionLabels, 'V2ML', 'V2');
    
end
