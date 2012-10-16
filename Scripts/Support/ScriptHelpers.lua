-- Standard library imports --
local assert = assert
local asin = math.asin
local cos = math.cos
local pi = math.pi
local sqrt = math.sqrt
local type = type

-- Imports --
local color = color
local ObjectDistance = game.ObjectDistance
local VisionGame = VisionGame
local VisionMessage = VisionMessage
local vector3 = vector3
local DivRem = numeric_ops.DivRem
--- helpers for AI scripts, to avoid having math, lua internals etc in there

local Temp = vector3()

module "script_helpers"

function AddToPath( entity, path, initialPos ,acceleration, deceleration, maxSpeed,autoMove )
	local component = entity:GetComponentOfType( "PathFollowComponent_cl" ) or	VisionGame.CreateComponent( "PathFollowComponent_cl" )
	component:SetAutoMove(autoMove)
	component:SetPath(path)
	component:SetAcceleration(acceleration)
	component:SetDeceleration(deceleration)
	component:SetMaxSpeed(maxSpeed)
	component:SetMovement( 0 )
	entity:AddComponent( component )
	component:SetRelativePosition( initialPos )
	entity:SetPhysxPosition( component:GetPosition(Temp) )
	entity.pathComponent = component
	
	return component
end

function AddFiringComponent( entity, projectile, fireRate, range, heatRate, cooldownRate, attackPos, bulletType )
	
	local component = VisionGame.CreateComponent( "FiringComponent_cl" )
	
	component:SetProjectileData( projectile )
	component:SetAttackRate( fireRate )
	
	if type( range ) == "table" then
		component:SetMinRange( range.min )
		component:SetRange( range.max )
	else
		component:SetRange( range )
	end
	
	component:SetHeatRate( heatRate )
	component:SetCooldownRate( cooldownRate );
	component:SetPhysxType(bulletType);
	component:SetAnimationName( "attack1" )
	
	
	
	entity:AddComponent( component )
	if (type(attackPos) == "string") then
		component:SetAttackBone( attackPos )
	else
		component:SetAttackPosition( attackPos )
	end
	return component
	
	
end

function AddBuffComponent( entity, radius )
	
	local component = VisionGame.CreateComponent( "BuffComponent_cl" )
	entity:AddComponent( component )
	component:SetRadious( radius )
	
	entity.buffComponent = component
	
	return component
end

function AddMeleeComponent( entity, attackRate, range, animationName, attackBone, boxSize, trailInfo )
	local component = VisionGame.CreateComponent( "MeleeComponent_cl" )
	component:SetAttackRate(attackRate)
	component:SetRange( range )
	component:SetPhysxType(7)
	component:SetAnimationName( animationName )
	component:SetBoxSize( boxSize or 15 )
	entity:AddComponent( component )
	
	component:SetAttackBone( attackBone )
	
	if trailInfo ~= nil then
		entity.trail = entity:AddTrail(trailInfo.duration, color(trailInfo.color.r,trailInfo.color.g,trailInfo.color.b ), trailInfo.texture, trailInfo.bone)
		entity.trail:SetEnabled(false)
		
		if trailInfo.lenght ~= nil then
			entity.trail:SetRelStart( vector3(trailInfo.lenght[1], trailInfo.lenght[2], trailInfo.lenght[3]) )
		end
	end
	
	
	return component
end

function Distance( pos1, pos2 )
	Temp.x, Temp.y, Temp.z = pos1.x - pos2.x, pos1.y - pos2.y, pos1.z - pos2.z
--	return #( pos1 - pos2 )

	return #Temp
end

function IsInRange( enemy, target, maxRange, minRange )
--	 local targetPosition = target:GetPosition()
--	 local enemyPosition = enemy:GetPosition()
	 minRange = minRange or 0
	 local distance = ObjectDistance(target, enemy)--Distance( targetPosition, enemyPosition )
	 if distance < maxRange and distance > minRange  then
		return true 
	end
 
end

function Path_MoveAway( movePath, targetPath )
	local movePathPos =  movePath:GetRelativePosition()
	local targetPathPos =   targetPath:GetRelativePosition()
	
	if ( movePathPos < targetPathPos ) then
		movePath:SetMovement( -1 )
	elseif (movePathPos >= targetPathPos ) then
		movePath:SetMovement( 1 )
	end
	
end

function Path_MoveTowards( movePath, targetPath )
	local movePathPos =  movePath:GetRelativePosition()
	local targetPathPos =   targetPath:GetRelativePosition()
	
	if ( movePathPos < targetPathPos ) then
		movePath:SetMovement( 1 )
	elseif ( movePathPos >= targetPathPos ) then
		movePath:SetMovement( - 1 )
	end
end

function Path_MoveToPosition( path, position )
	local P = path
	local pos = position
	path:SetMovement( 0 )
	return function ()
		local pathPosition = P:GetRelativePosition()
		if ( pathPosition < pos ) then
			if P:GetMovement() == -1 then
				P:SetMovement( 0 )
				return true
			end
			P:SetMovement( 1 )
		elseif ( pathPosition > pos ) then
			if P:GetMovement() == 1 then
				P:SetMovement( 0 )
				return true
			end
			P:SetMovement( -1 )
		else
			P:SetMovement( 0 )
			return true			
		end
	end
	
end

function OutsideRange(distance, range)

	 return distance > range
end

-- Helper for special case: vertical trajectories
-- Solve for t: y = v0 * t - g * t^2 / 2
local function VerticalLaunch (y, gravity, v0, get_times)
	local disc = v0 * v0 - 2 * gravity * y
	local a1, a2, t1, t2 = pi / 2, pi / 2

	if disc >= 0 then
		local root = sqrt(disc)

		-- If the target is below or coincident with the the launch point, it will always
		-- be a hit, given by the positive of the two times: when fired straight up, this
		-- is the time coming back down; when fired straight down, this is the expected
		-- drop time. In both cases the negative time is a virtual hit going up.
		if y <= 0 then
			-- The second angle is straight down.
			a2 = -a2

			-- The negative speed is used in the downward case. Since the discriminant >
			-- v0^2, sqrt(discriminant) > abs(v0). Accounting for this, determine the
			-- positive roots.
			if get_times then
				t1 = (v0 + root) / gravity
				t2 = (root - v0) / gravity
			end

		-- Otherwise, get the times going up and coming down when the point above is hit.
		elseif get_times then
			t1 = (v0 - root) / gravity
			t2 = (v0 + root) / gravity
		end

		return a1, a2, t1, t2
	end
end

--- Computes the launch angles needed to hit a target along a parabolic trajectory.<br><br>
-- Cf. "Mechanics", J.P. Den Hartog, pp. 187-9
-- @param point Launch point.
-- @param target Target point.
-- @param gravity Gravity constant.
-- @param v0 Launch speed.
-- @param get_times If true, return times after the angles.
-- @return If @e target can be hit, an angle that will yield a hit; otherwise, @b nil.
-- @return If @e target can be hit, another angle that will yield a hit; may be the same angle as the first.
-- @return Time lapse to hit with angle #1.
-- @return Time lapse to hit with angle #2; may differ even with same angles, i.e. when firing straight up.
function GetLaunchAngles (point, target, gravity, v0, get_times)
	assert(gravity > 0)
	assert(v0 > 0)

	local dx, dy, y = target[1] - point[1], target[2] - point[2], target[3] - point[3]
	local x2 = dx * dx + dy * dy
	local a1, a2, t1, t2

	-- If the target is above or below, do special vertical case.
	if x2 < 1e-5 then
		a1, a2, t1, t2 = VerticalLaunch(y, gravity, v0, get_times)

	-- x(t) = v0 * cos(alpha) * t
	-- y(t) = v0 * sin(alpha) * t - g * t^2 / 2
	-- t = x / (v0 * cos(alpha))
	-- y = v0 * sin(alpha) * x / (v0 * cos(alpha)) - g * x^2 / (2 * v0^2 * cos^2(alpha))
	-- phi = angle of sight to target
	-- Apply various transformations to get:
	-- sin(2 * alpha - phi) = right-hand side (RHS)
	-- If RHS > 1, the sine argument was invalid: the shot will miss.
	--
	-- Wikipedia offers the transformation:
	-- alpha = atan((v^2 +- sqrt(v^4 - g * (g * x^2 + 2 * y * v^2))) / (g * x))
	else
		local sin_numer = y + gravity * x2 / (v0 * v0)
		local dist = sqrt(x2 + y * y)

		if sin_numer <= dist then
			local phi = asin(y / dist)

			-- 2 * alpha - phi = asin(RHS)
			-- 2 * alpha = asin(RHS) + phi
			-- alpha = (asin(RHS) + phi) / 2
			local angle = asin(sin_numer / dist)

			a1 = (phi + angle) / 2

			-- sin(X) = sin(pi - X)
			-- sin(pi - (2 * alpha - phi)) = RHS
			-- pi - 2 * alpha + phi = asin(RHS)
			-- -2 * alpha = asin(RHS) - pi - phi
			-- 2 * alpha = phi + pi - asin(RHS)
			-- alpha = (phi + pi - asin(RHS)) / 2
			a2 = (phi - angle + pi) / 2

			-- Get times by solving for t: x(t) = v0 * cos(alpha) * t.
			if get_times then
				local x = sqrt(x2)

				t1 = x / (v0 * cos(a1))
				t2 = x / (v0 * cos(a2))
			end
		end
	end

	-- Return desired set of results.
	if t1 then
		return a1, a2, t1, t2
	elseif a1 then
		return a1, a2
	else
		return nil
	end
end

-- function GetLaunchSpeed (point, target, gravity, angle, time) ???

function GetOffsetMultiplier( maxEnemies, whichEnemy )
	
	local mult = (whichEnemy % 2 == 0 and -1 or 1 )
	local Dividend = maxEnemies % 2 == 0 and whichEnemy or ( whichEnemy + 1)
	local sum = maxEnemies % 2 == 0 and 0.5 or 0
	local div = DivRem (Dividend , 2)
	ret = mult * ( sum + div )
	return ret
	
end

function TooClose( distance, range )
	return distance < range
end

function GetAttackPattern( spawnPoint )
	local attackPattern	
	for i, entity in spawnPoint:RefEntities() do 
		local type = entity:GetType()
		
		if type == "AttackPattern_cl" then
			attackPattern = entity
		end	
	end
	
	if attackPattern then
		local location = attackPattern:GetLocationType()
		local spawnType = attackPattern:GetSpawnType()
		local patternType = attackPattern:GetPatternType()
		return attackPattern, location, spawnType, patternType
	end

end

function AddTargetableComponent( enemy, useOwnerBB, useWholeBB, shootingMarker )
	local TC = VisionGame.CreateComponent( "TargetableComponent_cl" )
	enemy:AddComponent( TC )
	
	if useOwnerBB then
		TC:UseOwnerBoundingBox()
	else
		TC:UseOwnerPhysicsObject()
	end
	
	TC:SetUseWholeBoundingBox( useWholeBB )
	if shootingMarker then
		TC:SetShootingMarker( shootingMarker )
	end	
	
	return TC
end

function AddTargetableDummy( enemy, hitPoints, colliderSize ,boneName, notifyOnHit, notifyOnDeath, removeOnDeath, canRespawn, owner )
	local Dummy = VisionGame.CreateEntity ("TargetableDummy_cl", vector3( 0,0,0 ) )
	
	if owner then
		Dummy:AttachToEntity( enemy, boneName )
		Dummy:SetOwner( owner )
	else
		Dummy:AttachToOwner( enemy, boneName )
	end
	
	if type( colliderSize ) == "number" then
		Dummy:InitComponentsSphere( colliderSize, hitPoints )
	else
		DummyInitCompomentsBox( colliderSize, hitPoints )
	end
	
	Dummy:SetNotifyOnHit( not not notifyOnHit )
	Dummy:SetNotifyOnDeath( not not notifyOnDeath )
	Dummy:SetRemoveOnDeath( not not removeOnDeath )
	Dummy:SetCanRespawn( not not canRespawn )
	
	return Dummy
		
end

function IsVectorInAngleRange( vector, referenceVector, range )
	local V, RV = vector, referenceVector
	
	V:Normalize()
	RV:Normalize()
	
	local dot = RV:DotProduct( V )
	return (dot < range and dot > (-range)), dot
end

function IsInFront( vector, direction )
	local V, D = vector, direction
	V:Normalize()
	D:Normalize()
	
	local dot = D:DotProduct( V )
	return dot > 0.0
	
end

