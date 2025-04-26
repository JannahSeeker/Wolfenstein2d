function renderDrawText(text, x, y, fontSize, color)
%renderDrawText Draws text using the custom rendering engine.
%
%   renderDrawText(TEXT, X, Y, FONTSIZE, COLOR) draws the TEXT string at
%   position (X,Y) with the specified FONTSIZE. COLOR should be a 1x4 uint8
%   array [R G B A] with values from 0 to 255.
%
%   Example: renderDrawText('Hello', 100, 150, 20, uint8([0, 255, 0, 255])); % Green text
%
%   See also renderInit, renderDrawRect.

    arguments
        text       (1,:) {mustBeTextScalar} % Use mustBeTextScalar (R2020a+) or mustBeA(..., 'char')/mustBeA(..., 'string')
        x          (1,1) {mustBeNumeric, mustBeReal}
        y          (1,1) {mustBeNumeric, mustBeReal}
        fontSize   (1,1) {mustBeNumeric, mustBeInteger, mustBePositive}
        color      (1,4) {mustBeA(color,'uint8')} % Validate color is 1x4 uint8
    end

    try
        % Call the MEX function with the 'drawText' command
        % Pass coordinates/size as int32, color as uint8 array, text as string
        renderMex('drawText', text, int32(x), int32(y), int32(fontSize), color);
    catch ME
        warning('renderDrawText:FailedToCallMEX', ...
               'Failed to call renderMex function for "drawText": %s', ME.message);
    end
end