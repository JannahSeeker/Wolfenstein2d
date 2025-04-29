classdef MapManager < handle
    %MAPMANAGER  Builds a 3D tile map and stores floor info.
    properties
        map           uint8       % H×W×F 3D tile codes
        height        double      % H
        width         double      % W
        currentFloor  double      = 1
        elevators     double    = zeros(0,3)   % N×3 array of [x,y,z]
        chests              % M×3 array of [x,y,z]
        numChests   uint8 = 10    % total number of chests to place
        numKeys     uint8 = 3     % how many of those chests contain keys
        keyManager    struct      % simple struct for key
        gs GameState
        ELEVATOR_TILE_ID uint8 = 8
        numFloors uint8 = 3
        numElevators uint8 = 15;


    end

    methods
        function obj = MapManager(gs)
            % Floor 1 (original layout)
            obj.createMap()
            obj.placeElevators()
            obj.placeChests_Keys();
            obj.gs = gs;
        end

        function placeElevators(obj)
            %PLACEELEVATORS  Mark elevator tiles in the map
            for i = 1:obj.numElevators
                x = randi(obj.width);
                y = randi(obj.height);
                f = randi(obj.numFloors);
                obj.elevators(end+1, :) = [x, y, f];
            end
            for i = 1:size(obj.elevators, 1)
                % pos is [x, y, floor]
                x = obj.elevators(i, 1);
                y = obj.elevators(i, 2);
                f = obj.elevators(i, 3);
                % Ensure indices are within bounds
                if y >= 1 && y <= obj.height && x >= 1 && x <= obj.width
                    obj.map(y, x, f) = obj.ELEVATOR_TILE_ID;
                end
            end
        end


        function free = isCellFree(obj, row, col, floor)
            % clamp first, then test 0==empty
            row = max(1, min(obj.height, row));
            col = max(1, min(obj.width,  col));
            free = ( obj.map(row, col, floor) == 0 );
        end
        function tf = isCellElevator(obj, row, col, floor)
            tf = ( obj.map(row,col,floor) == obj.ELEVATOR_TILE_ID );
        end

        function destFloor = getElevatorDestination(obj, row, col, floor)
            % Choose a random destination floor (1–3), excluding the current floor
            floors = 1:3;
            floors(floors == floor) = [];
            destFloor = floors(randi(numel(floors)));
        end

        function moveKey(obj,pos,index)
            obj.keyManager(index).keyPosition = pos;
        end
        function dropKey(obj,index)
            obj.keyManager(index).isHeld = false;
        end
        function holdKey(obj,index)
            obj.keyManager(index).isHeld = true;
        end

        function [isChest,hasKey,km] = isChestandKey(obj, row, col, floor)
            %ISCELLCHEST  Return true if a chest struct occupies [col,row,floor]
            tf = false;
            isChest = false;
            hasKey = false;
            km = false;
            for k = 1:numel(obj.chests)
                pos = obj.chests(k).position;  % [x,y,z]
                if pos(1) == col && pos(2) == row && pos(3) == floor
                    isChest = true;
                    if ~obj.chests(k).isOpen
                        disp("Opened chest!");
                        if obj.chests(k).hasKey == true;
                            hasKey = true;
                            obj.chests(k).hasKey = false;
                            obj.chests(k).isOpen = true;
                            %find index for key manager
                            %returns appropaite keymanager index if the chest has a key.
                            for j = 1:obj.numKeys
                                if isequal(pos, obj.keyManager(j).keyPosition)                                    km = j;
                                end
                            end
                        end
                    end
                    return;

                else
                end
            end

        end
        function km = isCellKey(obj,pos)
            %ISCELLCHEST  Return true if a chest struct occupies [col,row,floor]
            km = false;
            for j = 1:obj.numKeys
                if isequal(pos, obj.keyManager(j).keyPosition)
                    km = j;

                end
            end
        end



        function clearCell(obj, row, col, floor)
            obj.map(row,col,floor) = 0;         % remove the chest or key
        end

        function createMap(obj)
            floor1 = [
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
                1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
                ];

            % Floor 2 (central block of walls)
            floor2 = [
                1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1;
                1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1;
                1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1;
                1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1;
                1,0,0,0,2,2,2,2,0,2,2,2,0,0,0,1;
                1,0,0,0,2,0,0,0,0,0,0,2,0,0,0,1;
                1,0,0,0,2,0,3,3,3,3,0,2,0,0,0,1;
                1,0,0,0,2,0,3,0,0,3,0,2,0,0,0,1;
                1,0,0,0,2,0,3,0,0,3,0,2,0,0,0,1;
                1,0,0,0,2,0,0,0,0,0,0,2,0,0,0,1;
                1,0,0,0,2,2,2,2,0,2,2,2,0,0,0,1;
                1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1;
                1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1;
                1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1;
                1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1;
                1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
                ];

            % Floor 3 (diagonal corridor)
            floor3 = [
                1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1;
                1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1;
                1,0,3,0,0,0,0,0,0,0,0,0,0,0,0,1;
                1,0,0,3,0,0,0,0,0,0,0,0,0,0,0,1;
                1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1;
                1,0,0,0,0,3,0,0,0,0,0,0,0,0,0,1;
                1,0,0,0,0,0,3,0,0,0,0,0,0,0,0,1;
                1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1;
                1,0,0,0,0,0,0,0,3,0,0,0,0,0,0,1;
                1,0,0,0,0,0,0,0,0,3,0,0,0,0,0,1;
                1,0,0,0,0,0,0,0,0,0,3,0,0,0,0,1;
                1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1;
                1,0,0,0,0,0,0,0,0,0,0,0,3,0,0,1;
                1,0,0,0,0,0,0,0,0,0,0,0,0,3,0,1;
                1,0,0,0,0,0,0,0,0,0,0,0,0,0,3,1;
                1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
                ];

            % Use the three distinct floor layouts
            obj.height = size(floor1,1);
            obj.width  = size(floor1,2);
            obj.map    = cat(3, uint8(floor1), uint8(floor2), uint8(floor3));

        end
        function placeChests_Keys(obj)
            %PLACECHESTS  Generate random chests and assign keys
            % Preallocate struct array
            ch = repmat(struct(...
                'position', [0,0,0], ...
                'isOpen',   false, ...
                'hasKey',   false), ...
                obj.numChests, 1);
            % Generate random chest positions with x and y between 2 and 15
            xs = randi([2, 15], obj.numChests, 1);
            ys = randi([2, 15], obj.numChests, 1);
            fs = randi([1, obj.numFloors], obj.numChests, 1);
            for i = 1:obj.numChests
                ch(i).position = [xs(i), ys(i), fs(i)];
                ch(i).isOpen   = false;
                ch(i).hasKey   = false;
            end
            % Randomly select which chests contain keys
            keyIdx = randperm(obj.numChests, obj.numKeys);
            for k = keyIdx
                ch(k).hasKey = true;
            end
            obj.chests = ch;
            % Build keyManager entries for each key
            km = repmat(struct('keyPosition',[0,0,0],'isHeld',false,'animFrame',0), ...
                obj.numKeys, 1);
            for j = 1:obj.numKeys
                idx = keyIdx(j);                    % chest index holding a key
                km(j).keyPosition = ch(idx).position;
                km(j).isHeld      = false;
                km(j).animFrame   = 0;
            end
            obj.keyManager = km;
        end

        function pushMapToFlask(obj, serverURL)
            %PUSHMAPTOFLASK  Upload entire 3D map to the live-map server.
            %   serverURL should be the root URL (no trailing slash), e.g. "http://localhost:5555"
            % Include map and current chest states
            rawChests = obj.chests;
            payloadChests = arrayfun(@(c) struct(...
                'position', c.position - [1 1 1], ...
                'isOpen',   c.isOpen, ...
                'hasKey',   c.hasKey), rawChests);
            payload = struct( ...
                'map', {obj.map}, ...
                'chests',  {payloadChests} ...
                );
            try
                webwrite(serverURL + "/update", payload, ...
                    weboptions('MediaType','application/json', 'Timeout',5));
            catch ME
                warning("MapManager:pushMapFailed", ...
                    "Could not POST map to %s/update — %s", serverURL, ME.message);
            end
        end
    end
end
