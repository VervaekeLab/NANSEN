classdef buttonSymbol2 < uim.style.buttonScheme
    
    properties (Constant)
        
        HighlightedOn = struct(...
            'ForegroundColor', ones(1,3) * 1, ...
            'BackgroundColor', ones(1,3) * 0.2, ...
            'BackgroundAlpha', 0, ...
            'BorderColor', 'none', ...%[0.6,0.6,0.6], ...
            'BorderWidth', 1)
        HighlightedOff = struct(...
            'ForegroundColor', ones(1,3) * 0.85, ...
            'BackgroundColor', ones(1,3) * 0.2, ...
            'BackgroundAlpha', 0, ...
            'BorderColor', 'none', ...%[0.3,0.3,0.3], ...
            'BorderWidth', 1)
        On = struct(...
            'ForegroundColor', ones(1,3) * 1, ...
            'BackgroundColor', ones(1,3) * 0.4, ...
            'BackgroundAlpha', 0, ...
            'BorderColor', 'none', ...%[0.3,0.3,0.3], ...
            'BorderWidth', 0.5)
        Off = struct(...
            'ForegroundColor', ones(1,3) * 0.7, ...
            'BackgroundColor', ones(1,3) * 0.4, ...
            'BackgroundAlpha', 0, ...
            'BorderColor', 'none', ...%[0.3,0.3,0.3], ...
            'BorderWidth', 0.5)
        
    end
end
