function renderBeginFrame()
%renderBeginFrame Signals the start of a rendering frame.
%   Typically clears the background in the rendering engine.
%
%   renderBeginFrame()
%
%   See also renderEndFrame.

    try
        % Call the MEX function with the 'beginFrame' command
        renderMex('beginFrame');
    catch ME
        warning('renderBeginFrame:FailedToCallMEX', ...
                'Failed to call renderMex function for "beginFrame": %s', ME.message);
    end
end