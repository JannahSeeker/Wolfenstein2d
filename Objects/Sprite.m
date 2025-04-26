classdef Sprite < handle
    %SPRITE  Represents an entity that can move and chase the player.

    properties
        id int32 
        pos        (1,3) double    % [x, y, floor]
        speed      double           % cells per second
        health     double
        maxHealth  double
        opacity    double
        type       string
        state      string
        animFrame  int32
        aiBrain    string           % e.g. 'DirectChaser'
        damage double = 2.9
        radius  double = 0.4    % collision radius (in world units)
        manager SpriteManager

    end

    methods
        function obj = Sprite(pos, type, state, animFrame, aiBrain)
            %SPRITE  Constructor
            obj.pos       = pos;
            obj.type      = type;
            obj.state     = state;
            obj.animFrame = int32(animFrame);
            obj.aiBrain   = aiBrain;
            % Default attributes by AI type
            switch aiBrain
                case 'DirectChaser'
                    obj.speed     = 10.0;
                    obj.health    = 10;
                    obj.maxHealth = 10;
                    obj.opacity   = 1.0;
                otherwise
                    obj.speed     = 0.5;
                    obj.health    = 5;
                    obj.maxHealth = 5;
                    obj.opacity   = 0.5;
            end
            %add switch statement to discern ghost and soldier attributes
        end

        function update(obj, players, mapMgr, dt)
            %UPDATE  Called each frame with an array of Player objects
            switch obj.aiBrain
                case 'DirectChaser'
                    obj.chaseClosestPlayer(players, mapMgr, dt);
                    % add other AI types here...
                case 'SmartChaser'
                    % 1) pick nearest player
                    dists = arrayfun(@(p) norm(p.position(1:2)-obj.pos(1:2)), players);
                    [~, idx] = min(dists);
                    targetCell = floor(players(idx).position(1:2));

                    % 2) replan if needed
                    if isempty(obj.path) || any(obj.lastTarget ~= targetCell)
                        obj.path       = obj.planPathGrid(targetCell, mapMgr);
                        obj.lastTarget = targetCell;
                    end

                    % 3) move along the planned path
                    obj.followPath(dt, mapMgr);
            end
            % Advance animation frame
            obj.animFrame = mod(obj.animFrame + 1, 60);
        end

        function onCollidePlayer(obj, player)
            player.takeDamage(obj.damage);
            % maybe bounce back, play sound, change obj.state, etc.
        end

        function chasePlayer(obj, targetPos, mapMgr, dt)
            %CHASEPLAYER  Move directly toward the player, with collision.
            dir = targetPos(1:2) - obj.pos(1:2);
            d   = norm(dir);
            if d < eps, return; end
            dir = dir / d;  % unit direction vector

            % compute proposed step
            dx = dir(1) * obj.speed * dt;
            dy = dir(2) * obj.speed * dt;

            % attempt X move
            newX = obj.pos(1) + dx;
            r    = floor(obj.pos(2));
            c    = floor(newX);
            if mapMgr.isCellFree(r, c, obj.pos(3))
                obj.pos(1) = newX;
            end

            % attempt Y move
            newY = obj.pos(2) + dy;
            r    = floor(newY);
            c    = floor(obj.pos(1));
            if mapMgr.isCellFree(r, c, obj.pos(3))
                obj.pos(2) = newY;
            end
        end
        function chaseClosestPlayer(obj, players, mapMgr, dt)
            % Compute distances to each player
            n = numel(players);
            dists = zeros(1,n);
            for i = 1:n
                delta = players(i).position(1:2) - obj.pos(1:2);
                dists(i) = norm(delta);
            end
            % Find the nearest player
            [~, idx] = min(dists);
            targetPos = players(idx).position;

            % Now do the usual direct‐chase logic toward targetPos
            dir = targetPos(1:2) - obj.pos(1:2);
            if norm(dir) < eps
                return;
            end
            dir = dir / norm(dir);

            % Step proposal
            dx = dir(1) * obj.speed * dt;
            dy = dir(2) * obj.speed * dt;

            % X‐axis move with collision
            newX = obj.pos(1) + dx;
            r    = floor(obj.pos(2));
            c    = floor(newX);
            if mapMgr.isCellFree(r, c, obj.pos(3))
                obj.pos(1) = newX;
            end

            % Y‐axis move with collision
            newY = obj.pos(2) + dy;
            r    = floor(newY);
            c    = floor(obj.pos(1));
            if mapMgr.isCellFree(r, c, obj.pos(3))
                obj.pos(2) = newY;
            end
        end

        function takeDamage(obj, amount, fromId)
            obj.health = obj.health - amount;
            if obj.health <= 0
                obj.onDeath(fromId);
            end
        end
        function onDeath(obj, killerId)
            % Play death animation, drop loot, award score, etc.
            fprintf("%s died (killed by player %d)\n", obj.type, killerId);
        end
        function waypoints = planPathGrid(obj, goalCell, mapMgr)
            % plan a BFS path on the tile grid from current cell → goalCell
            startCell = floor(obj.pos(1:2));           % [x,y] continuous → [col,row]
            grid      = mapMgr.map(:,:,obj.pos(3));    % 2D occupancy
            [nRows,nCols] = size(grid);

            % Visited flags + predecessor map
            visited  = false(nRows,nCols);
            prevCell = zeros(nRows,nCols,2);

            % Queue of [row,col]
            queue = zeros(nRows*nCols,2);
            head = 1; tail = 1;
            % enqueue start
            sr = startCell(2); sc = startCell(1);
            queue(tail,:)     = [sr,sc];
            visited(sr,sc)    = true;

            % Offsets: up/down/left/right
            dirs = [ -1 0; 1 0; 0 -1; 0 1 ];
            found = false;

            while head <= tail
                cell = queue(head,:); head = head + 1;
                if isequal(cell, [goalCell(2), goalCell(1)])
                    found = true;
                    break;
                end
                for d = 1:4
                    nr = cell(1) + dirs(d,1);
                    nc = cell(2) + dirs(d,2);
                    if nr>=1 && nr<=nRows && nc>=1 && nc<=nCols ...
                            && ~visited(nr,nc) && grid(nr,nc)==0
                        visited(nr,nc)           = true;
                        prevCell(nr,nc,:)        = cell;
                        tail = tail + 1;
                        queue(tail,:) = [nr,nc];
                    end
                end
            end

            % Reconstruct path of [x,y] waypoints
            waypoints = zeros(0,2);
            if found
                cur = [goalCell(2), goalCell(1)];
                while ~isequal(cur, [sr,sc])
                    % prepend (col,row) as [x,y]
                    waypoints = [[cur(2),cur(1)]; waypoints];
                    cur = squeeze(prevCell(cur(1),cur(2),:))';
                end
            end
        end
        function followPath(obj, dt, mapMgr)
            if isempty(obj.path), return; end
            nextWP = obj.path(1,:);               % [x,y] next cell center
            dir    = nextWP - obj.pos(1:2);
            dist   = norm(dir);
            if dist < 0.1
                % reached that waypoint → pop it
                obj.path(1,:) = [];
            else
                dir = dir / dist;
                dx  = dir(1) * obj.speed * dt;
                dy  = dir(2) * obj.speed * dt;
                obj.move(dx, dy, mapMgr);         % reuse your collision‐safe move
            end
        end



    end

end