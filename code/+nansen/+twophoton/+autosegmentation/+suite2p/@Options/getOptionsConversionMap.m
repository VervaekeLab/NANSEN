function S = getOptionsConversionMap()

S                                       = struct();             %
S.CellDetection.cellDiameter            = 'diameter';
S.CellDetection.smoothingSigma          = 'sig';
S.CellDetection.numSvdComponents        = 'nSVDforROI';
S.CellDetection.svdFrameBinningSize     = 'NavgFramesSVD';
S.CellDetection.signalExtractionType    = 'signalExtraction';
S.CellDetection.refineDetectedRois      = 'refine';

S.Neuropil.neuropilPadding              = 'innerNeuropil';
S.Neuropil.radius                       = 'outerNeuropil';
S.Neuropil.minNeuropilPixels            = 'minNeuropilPixels';
S.Neuropil.neuropilCellRatio            = 'ratioNeuropil';

S.Deconvolution.imagingRate             = 'imageRate';
S.Deconvolution.sensorTimeConstant      = 'sensorTau';
S.Deconvolution.maxNeuropil             = 'maxNeurop';

end
