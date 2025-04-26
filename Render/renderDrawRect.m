function renderDrawRect(x, y, w, h, color)
%renderDrawRect Draws a rectangle using the custom rendering engine.
%
%   renderDrawRect(X, Y, W, H, COLOR) draws a rectangle at position (X,Y)
%   with width W and height H. COLOR should be a 1x4 uint8 array [R G B A]
%   with values from 0 to 255.
%
%   Example: renderDrawRect(10, 20, 50, 30, uint8([255, 0, 0, 255])); % Red rectangle
%
%   See also renderInit, renderDrawText.

    arguments
        x      (1,1) {mustBeNumeric, mustBeReal}
        y      (1,1) {mustBeNumeric, mustBeReal}
        w      (1,1) {mustBeNumeric, mustBeReal, mustBeNonnegative}
        h      (1,1) {mustBeNumeric, mustBeReal, mustBeNonnegative}
        color  (1,4) {mustBeA(color,'uint8')} % Validate color is 1x4 uint8
    end

    try
        % Call the MEX function with the 'drawRect' command
        % Pass coordinates as int32 and color as uint8 array
        renderMex('drawRect', int32(x), int32(y), int32(w), int32(h), color);
    catch ME
        warning('renderDrawRect:FailedToCallMEX', ...
                'Failed to call renderMex function for "drawRect": %s', ME.message);
    end
end