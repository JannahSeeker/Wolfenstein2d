
function run2d()
% Basic Raycaster Demo using renderMex engine
% Input handling is performed by C++/Raylib via renderGetInputState()

url     = 'http://localhost:5100/api/joystick';
options = weboptions('Timeout',0.1, 'ContentType','json');
gs = GameState();
player = gs.player;
baseFloor = [ % Define the map (0=empty, 1-4=wall types)
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1;
    1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1;
    1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1;
    1,0,0,1,1,0,0,0,2,2,0,0,0,0,0,1;
    1,0,0,1,0,0,0,0,2,0,0,0,0,0,0,1;
    1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1;
    1,0,0,0,0,0,3,3,3,3,0,0,0,0,0,1;
    1,0,0,0,0,0,3,0,0,3,0,0,0,0,0,1;
    1,0,0,0,0,0,3,0,0,3,0,0,0,0,0,1;
    1,0,2,0,0,0,0,0,0,0,0,0,0,0,0,1;
    1,0,2,0,0,0,0,0,0,4,4,4,4,0,0,1;
    1,0,2,0,0,0,0,0,0,0,0,0,0,0,0,1;
    1,0,2,2,2,2,0,0,0,0,0,0,0,0,0,1;
    1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1;
    1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1;
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1;
    ];
gs.mapManager.map = repmat(baseFloor,1,1,3);


% --- Main Loop ---
while (gs.running)

    collectInput(gs,url,options);
    runAsciiWindow(gs,0.01,2,1);


end

end % function runRaycasterDemo

function runAsciiWindow(gs, frameTime, hScale, vScale)
% RUNASCIWINDOW  Continuously redraws the current floor map in place.
%   gs        – game‐state struct
%   frameTime – pause time between frames (e.g. 0.1 for 10 FPS)
%   hScale    – repeat each cell this many times horizontally
%   vScale    – repeat each row this many times vertically

%–– Prepare data once

map     = gs.mapManager.map(:,:,gs.mapManager.currentFloor);
symbols = [' ' '█' '▓' '▒' '░','X','P','O'];
nRows   = size(map,1);
footerLines = 2;            % 2 lines after the grid
totalLines  = 1 + nRows*vScale + footerLines;
% 1 header + (nRows*vScale) map lines + 2 footer

%–– Initial draw
printMapScaled(map, symbols, gs, hScale, vScale);

%–– Loop: static map, but keep redrawing at new “resolution”
% while true
pause(frameTime);

%–– Jump cursor up to overwrite entire block
fprintf('\033[%dA', totalLines);

%–– Redraw
printMapScaled(map, symbols, gs, hScale, vScale);
% end
end

function gs = collectInput(gs, url, options)
% Poll the Flask joystick API
js = webread(url, options);
% disp(js);
dt = 0.1;

% Before
oldPos = gs.player.position(1:2);
fprintf("Old pos: [%.2f, %.2f]\n", oldPos);

% Delta
dx = js.xl * gs.player.speed * dt;
dy = js.yl * gs.player.speed * dt;
fprintf("Delta : [%.2f, %.2f]\n", dx, dy);

% Update
gs.player.position(1) = oldPos(1) + dx;
gs.player.position(2) = oldPos(2) + dy;

% After
newPos = gs.player.position(1:2);
fprintf("New pos: [%.2f, %.2f]\n\n", newPos);


% Convert to integer map indices and clamp
row = round(gs.player.position(1));
col = round(gs.player.position(2));
row = max(1, min(size(gs.mapManager.map,1), row));
col = max(1, min(size(gs.mapManager.map,2), col));

% Mark the player’s cell (for debugging or “trail”)
gs.mapManager.map(row, col, gs.mapManager.currentFloor) = 1;
disp(gs.mapManager.map(row, col, gs.mapManager.currentFloor));

end
function printMapScaled(map, symbols, gs, hScale, vScale)
% Prints header + ASCII picture with adjustable scaling.

% Header
fprintf('===== RAYCASTER MAP (Floor %d, %d×%d) =====\n', ...
    gs.mapManager.currentFloor, size(map,1), size(map,2));

% Body: each row, scaled
for r = 1:size(map,1)
    rowChars = symbols(map(r,:) + 1);         % pick glyphs
    rowScaled = repelem(rowChars, 1, hScale);  % repeat each char horizontally
    for vv = 1:vScale                         % repeat entire row vertically
        fprintf('%s\n', rowScaled);
    end
end

% Footer
fprintf('Press Ctrl-C to stop.\n');
fprintf('Timestamp: %s\n', datestr(now,'HH:MM:SS.FFF'));
end
function demoMapAnimation(gs, nSteps)
% DEMOMAPANIMATION  Reprints the map in-place, nSteps times, as a “game” loop.
%   gs      – your game-state struct
%   nSteps  – how many updates to show

map = gs.mapManager.map(:, :, gs.mapManager.currentFloor);
disp(map);
symbols = [' ' '█' '▓' '▒' '░','X','P','6'];     % tile → glyph
nRows   = size(map,1);
% ---- Initial full draw ---------------------------------------------
printMap(map, symbols, gs);

for k = 1:nSteps
    pause(0.10);                     % pretend we did game logic here

    % --- update something for the demo ------------------------------
    map = circshift(map, [0 1]);     % just slide the walls for fun

    % --- move cursor BACK to top-left & redraw ----------------------
    fprintf('\033[%dA', nRows + 5);  % move cursor up (rows + header lines)
    printMap(map, symbols, gs);
end
end

function printMap(map, symbols, gs)
% PRINTMAP  Prints header + ASCII picture of the map at the *current* cursor.

fprintf('===== RAYCASTER MAP (Floor %d, %d×%d) =====\n', ...
    gs.mapManager.currentFloor, size(map,1), size(map,2));

for r = 1:size(map,1)
    rowChars = symbols(map(r,:) + 1);
    fprintf('%s\n', rowChars);
end

fprintf('Use ESC sequences to overwrite this block in the next frame.\n');
fprintf('Timestamp: %s\n', datestr(now,'HH:MM:SS.FFF'));
end