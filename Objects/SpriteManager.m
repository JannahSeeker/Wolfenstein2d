classdef SpriteManager < handle
    %SPRITEMANAGER  Example enemy list
    properties
        sprites
        gs GameState
    end

    methods
        function obj = SpriteManager(gs)
            % Start with no sprites, then add your defaults
            obj.sprites = Sprite.empty;
            obj.addSprite([5,5,1], "ghost", "Idle", 0, "DirectChaser");
            obj.addSprite([5,6,1], "ghost", "Idle", 0, "DirectChaser");
            obj.addSprite([5,5,1], "ghost", "Idle", 0, "DirectChaser");
            obj.gs = gs;
        end
        function addSprite(obj, pos, type, state, animFrame, aiBrain)
            %ADDSPRITE  Create a new Sprite, assign it an ID & manager, and append
            s = Sprite(pos, type, state, animFrame, aiBrain);
            s.id      = numel(obj.sprites) + 1;
            s.manager = obj;
            obj.sprites(end+1) = s;
        end

        function removeSprite(obj, id)
            %REMOVESPRITE  Find by ID, remove from the array, and renumber
            
            idx = find([obj.sprites.id] == id, 1);
            if isempty(idx)
                return
            end
            obj.sprites(idx) = [];
            % Re-assign consecutive IDs so they stay 1…N
            for k = 1:numel(obj.sprites)
                obj.sprites(k).id = k;
            end
        end
    end
end

function sprite = createSprite(pos, type, state, animFrame, aiBrain)
%CREATESPRITE Constructs a single sprite struct.
%
%   sprite = createSprite([x y z], typeID, state, animFrame, aiBrain)

if strcmp(type, "soldier")
    sprite = struct( ...
        'speed', 2.0, ...
        'health', 20, ...
        'maxHealth', 20, ...
        'opacity', 1.0, ...
        'pos',       pos, ...
        'type',      type, ...
        'state',     state, ...
        'animFrame', int32(animFrame), ...
        'aiBrain',   aiBrain ...
        );
else
    sprite = struct( ...
        'speed', 4.0, ...
        'health', 10, ...
        'maxHealth', 10, ...
        'opacity', 0.4, ...
        'pos',       pos, ...
        'type',      type, ...
        'state',     state, ...
        'animFrame', int32(animFrame), ...
        'aiBrain',   aiBrain ...
        );
end

end
% managers/SpriteManager.m