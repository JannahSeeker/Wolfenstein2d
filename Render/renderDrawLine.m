function renderDrawLine(x1, y1, x2, y2, color)
%renderDrawLine Draws a line using the custom rendering engine.
%
%   renderDrawLine(X1, Y1, X2, Y2, COLOR) draws a line between points
%   (X1,Y1) and (X2,Y2). COLOR should be a 1x4 uint8 array [R G B A]
%   with values from 0 to 255.
%
%   Example: renderDrawLine(10, 10, 200, 150, uint8([255, 255, 255, 255])); % White line
%
%   See also renderDrawRect, renderDrawText.

    arguments
        x1     (1,1) {mustBeNumeric, mustBeReal}
        y1     (1,1) {mustBeNumeric, mustBeReal}
        x2     (1,1) {mustBeNumeric, mustBeReal}
        y2     (1,1) {mustBeNumeric, mustBeReal}
        color  (1,4) {mustBeA(color,'uint8')} % Validate color is 1x4 uint8
    end

    try
        % Call the MEX function with the 'drawLine' command
        renderMex('drawLine', int32(x1), int32(y1), int32(x2), int32(y2), color);
    catch ME
        warning('renderDrawLine:FailedToCallMEX', ...
                'Failed to call renderMex function for "drawLine": %s', ME.message);
    end
end