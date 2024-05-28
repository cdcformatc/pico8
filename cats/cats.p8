pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
-- cats!
#include cats_version.lua

function _init()
	debug=false
	printh("init")

	-- set game state
	g_timer=0
	last_swp=-1
	game_over=false

	-- make cats
	cats = {[1]=make_cat(1),[2]=make_cat(2)}
	main_cat=cats[1]
	other_cat=cats[2]

	-- make effects
	init_effects()
end

function _update()
	g_timer+=1

	if (not game_over) then
		update_effects()
		check_swap()

		do_action(main_cat)
		do_action(other_cat)

		move_cat(main_cat)
		move_cat(other_cat)
	else
		if (btnp(5,0) or btnp(5,1)) _init()
	end
end

function _draw()
	cls(5)
	camera()

	-- reset palette
	reset_pal()

	-- print version
	local vstr="v"..version
	print(vstr,128-(#vstr-1)*char_width,0,12)

	set_camera()
	draw_map()
	draw_cats()
	draw_effects()

	if debug then
		debug_cat(cat1)
		debug_cat(cat2)
	end

	if (game_over) then
		print("game over!",44,44,7)
		print("press ❎ to play again!",18,72,7)
	end
end

--debug and printing
char_width=5
char_height=6

function round(x)
	return flr(x+.5)
end

function printn(s,n,x,y)
	print(sub(s,0,n),x,y)
end

function debug_cat(cat)
	x=cat.n*7*char_width
	y=0

	print(cat.n,x,y)
	y+=char_height
	print(cat.state,x,y)
	y+=char_height
	printn(cat.x,7,x,y)
	y+=char_height
	printn(cat.y,7,x,y)
	y+=char_height
	printn(cat.dx,7,x,y)
	y+=char_height
	printn(cat.dy,7,x,y)
	y+=char_height
	printn(cat.t,7,x,y)
end

-->8
-- cat state control

-- cat states
state_init=1
state_unknown=2
state_dead=3
state_standing=4
state_jumping=5
state_falling=6
state_running=7
state_sitting=8
state_loafing=9
state_sleeping=10

-- timer constants
local sit_time=0.5*60
local loaf_time=3*60
local sleep_time=6*60

function is_idle_state(state)
	return (state==state_sitting or state==state_loafing or state==state_sleeping)
end

function is_idle(cat)
	return is_idle_state(cat.state)
end

function is_on_floor(cat)
	return cat.y >= 120
end

function is_falling(cat)
	return cat.state==state_falling
end

function is_jumping(cat)
	return cat.state==state_jumping
end

function is_airborne(cat)
	return is_falling(cat) or is_jumping(cat)
end

function make_cat(n)
	c={}
	c.n=n-1
	c.p=c.n

	-- position and speed
	c.x=24
	c.y=60
	c.dy=0
	c.dx=0

	-- attributes
	c.sprite_base=0
	c.lazy_factor=1
	c.pal_swaps=nil
	c.fh=7
	c.hh=3.5
	c.fw=7
	c.hw=3.5

	-- state
	c.t=0
	c.last_act=-1
	c.state=state_init

	-- set unique attributes
	if (c.n==1) then
		c.sprite_base=16
		-- move cat1 on init
		c.x+=12
		c.flip_h=true

		-- set palette swaps
		c.pal_swaps={}
		c.pal_swaps.flip = {[13]=9,[14]=4}
		c.pal_swaps.noflip = {[14]=9,[13]=4}
	else
		c.lazy_factor=1.25
	end
	return c
end

function set_cat_state(cat)
	local old_state=cat.state
	local new_state=state_unknown

	if (is_on_floor(cat)) then
		--printh("n: "..cat.n.."is_on_floor")
		if (cat.dx!=0) then
			new_state=state_running
		else
			local idle_time = cat.t*cat.lazy_factor
			new_state=state_standing
			if (idle_time>=sit_time) new_state=state_sitting
			if (idle_time>=loaf_time) new_state=state_loafing
			if (idle_time>=sleep_time) new_state=state_sleeping
		end
	else
		--printh("n: "..cat.n.."is in air")
		-- cat is in the air
		if (cat.dy>0) then
			new_state=state_falling
		else
			new_state=state_jumping
		end
	end

	--printh("n: "..cat.n.." dx"..cat.dx.." dy"..cat.dy)
	--printh("old: "..old_state.." new "..new_state)

	if (new_state!=old_state and new_state!=state_unknown) then
		-- set state
		cat.state=new_state
		printh(cat.n.." state "..old_state.." to "..new_state)

		if (not is_idle_state(new_state)) then
			-- reset idle timer
			cat.t=0
		end
	else
		-- increment idle timer
		cat.t+=1
	end
end

-->8
-- cat movement

-- controls
b_left=0
b_right=1
b_up=2
b_down=3
b_swp=4
b_act=5

-- movement constants
dy_gravity=0.4

dy_jump=-15*dy_gravity
dy_float=-.5*dy_gravity
dy_down=.75*dy_gravity

dx_move=2
ddx_air=0.888
ddx_air=0.950
ddx_slow=.625

max_dx=4
max_dy=8

min_dx=0.25

function move_cat(cat)
	local p=cat.p

	-- apply user input
	-- left
	if (btn(b_left,p)) then
		cat.dx-=dx_move
	end

	-- right
	if (btn(b_right,p)) then
		cat.dx+=dx_move
	end

	-- up
	if (btn(b_up,p)) then
		if (is_on_floor(cat)) then
				-- jump
				sfx(0)
				cat.dy+=dy_jump
				printh("jump")
			elseif (is_falling(cat)) then
				-- float
				cat.dy+=dy_float
				printh("float")
			end
	end

	--down
	--if (btnp(b_down,p)) then
		--if (is_jumping(cat)) then
			--cat.dy=-dy_gravity
		--end
	--end
	if (btn(b_down,p)) then
		cat.dy+=dy_down
	end

	-- do gravity
	cat.dy+=dy_gravity

	-- apply x friction
	if (is_on_floor(cat)) then
		cat.dx*=ddx_slow
	else
		cat.dx*=ddx_air
	end

	--apply y friction
	cat.dy*=.99

	-- cap speed
	if (abs(cat.dx)<min_dx) cat.dx=0

	if (cat.dx>max_dx) cat.dx=max_dx
	if (cat.dx<-max_dx) cat.dx=-max_dx
	if (cat.dy>max_dy) cat.dy=max_dy
	if (cat.dy<-max_dy) cat.dy=-max_dy

	-- finally apply speed
	cat.y+=cat.dy
	cat.x+=cat.dx

	-- cat is on the ceiling
	if (cat.y <= 0) then
		cat.y=0
		cat.dy=0
	end

	-- set cat on the floor
	if (is_on_floor(cat)) then
		cat.dy=0
		cat.y=120
	end

	-- left bound
	if (cat.x < 0) then
		cat.dx=0
		cat.x=0
	end

	-- right bound
	if (cat.x > 120) then
		cat.dx=0
		cat.x=120
	end

	-- update cat state
	set_cat_state(cat)
end

function cat_speed(cat)
	return sqrt(cat.dx^2+cat.dy^2)
end

-->8
-- cat actions
act_deb=1

function do_action(cat)
	local p = cat.p
	if (btn(b_act,p)) then
		if (cat.last_act+act_deb>=g_timer) return false
		--else
		cat.last_act=g_timer
		sparkle(cat.x,cat.y)
		printh(cat.n.." action")
	end
	return true
end

-->8
-- cat graphics

-- animation constants
-- speeds: lower is faster
local max_ani_spd=1.5
local min_ani_spd=4

local sprite_tbl = {
	{3},     --state_init
	{3},     --state_unknown
	{3},     --state_dead
	{0},     --state_standing
	{5},     --state_jumping
	{6},     --state_falling
	{5,6}, --state_running
	{1},     --state_sitting
	{2},     --state_loafing
	{4},     --state_sleeping
}

function get_sprite(cat)
	local ani=sprite_tbl[cat.state]
	local dur=#ani
	-- calc ani speed based on cat speed
	spd=max(max_ani_spd,min_ani_spd-cat_speed(cat))
	-- speed can not go below 1
	spd=max(1, spd)

	if cat.t%5==0 then
		--printh(cat.dx.." "..cat.dy.." "..spd)
	end

	-- find frame of animation
	local f=(round((cat.t+1+dur)/spd)-1)%dur

	-- find sprite for frame and cat
	return ani[f+1]+cat.sprite_base
end

function draw_cat(cat)
	--printh("draw "..cat.n)
	-- maybe flip cat
	if (cat.dx<0) cat.flip_h=true
	if (cat.dx>0) cat.flip_h=false

	-- get sprite
	local s=get_sprite(cat)
	local f=fget(s)

	-- swap palette
	swap_pal(cat, f)

	-- draw sprite
	spr(s,cat.x,cat.y,1,1,cat.flip_h)

	-- reset palette
	reset_pal()
end

function draw_cats()
	draw_cat(other_cat)
	draw_cat(main_cat)
end

-- fun with pals (palettes)
function reset_pal()
	pal()
	palt()
end

function swap_pal(cat, t_col)
	local swaps = cat.pal_swaps
	if (swaps) then
		--printh(cat.n.." swaps")
		local s=swaps.noflip
		if (cat.flip_h) s=swaps.flip
		pal(s)
 end
	-- set transparency
	--printh(t_col)
	if (t_col!=0) then
		palt(t_col)
	end
end

-->8
-- effects
local animations = {
	[1]={33,34,35,36,37,38} -- [1]=sparkle
}

e_sparkle=1

function init_effects()
	effects={}
end

function update_effects()
	foreach(effects,update_effect)
end

function draw_effects()
	foreach(effects, draw_effect)
end

function new_effect(e,x,y,s)
	e={e=e,x=x,y=y,s=s,f=0,sf=-1}
	return e
end

function sparkle(x,y)
	-- sparkle_speed = 2
	e=new_effect(e_sparkle,x,y,2)
	add(effects, e)
end

function update_effect(e)
	-- increment subframe
	e.sf+=1
	if (e.sf>=e.s) then
		e.f+=1
		e.sf=0
	end
	-- remove completed effect from table
	if (e.f+1 > #animations[e.e]) then
		del(effects,e)
	end
	--printh("f "..e.f.."."..e.sf.." "..#animations[e.e])
end

function draw_effect(e)
	--if (e.f+1 > #animations[e.e]) return false
	-- get the animation and then the frame of the animation
	local frame = animations[e.e][e.f+1]
	spr(frame, e.x, e.y)
end

-->8
-- cat swap control
local swp_deb=15

function swap_cats(p)
	-- debounce cat swap
	if (last_swp+swp_deb>=g_timer) return false
	last_swp=g_timer

	-- swap cats
	local t_cat=main_cat
	main_cat=other_cat
	other_cat=t_cat

	-- play cat sfx
	if (p==0) then
		sfx(2+main_cat.n)
	else
		sfx(2+other_cat.n)
	end

	-- set cat state
	main_cat.p=0
	other_cat.p=1

	return true
end

function check_swap()
	-- check if swap button pressed
	local s0=btn(b_swp,0)
	local s1=btn(b_swp,1)
	if (s0) swap_cats(0)
	if (s1) swap_cats(1)
	-- if neither swap button pressed then reset swap timer
	if (not s0 and not s1) last_swp=-1
end

-->8
--map?

function set_camera()
	local cx=(cats[1].x+cats[2].x)/2
	local cy=(cats[1].y+cats[2].y)/2
	camera(
		flr(cx - 64),
		flr(cy - 64)
	)
end

function draw_map()
	map()
end

__gfx__
f0ff0ff0ffff0ff0fff0fff000fff00ffffffffff0ff0ff00fff0ff0000000000000000000000000000000000000000000000000000000000000000000000000
00ff0000f0ff0000fff00f000ffff0ffffffffff00ff00000fff0000000000000000000000000000000000000000000000000000000000000000000000000000
0fff0a0a00ff0a0af0f00000000000fffff0fff00fff0a0a00ff0a0a000000000000000000000000000000000000000000000000000000000000000000000000
0fff00000fff0000f0f0a0a0000000fffff00f000fff0000f0ff0000000000000000000000000000000000000000000000000000000000000000000000000000
000000ff0f0000ff00f000000fff0000fff000000000000ff000000f000000000000000000000000000000000000000000000000000000000000000000000000
000000ff000000ff0fff00ff0fff0a0a00000000f0000000f000000f000000000000000000000000000000000000000000000000000000000000000000000000
0ffff0fff000f0ff000000ff0fff000000000000f0fffff0f0fffff0000000000000000000000000000000000000000000000000000000000000000000000000
00fff00ff000f00f00000000f0ff0ff0000000000ffffffff00ffff0000000000000000000000000000000000000000000000000000000000000000000000000
0400e00d0000e00d000e000d47000470000000000400e00d4000e00d000000000000000000000000000000000000000000000000000000000000000000000000
4400444404004444000ee0dd40000400000000004400444440004444000000000000000000000000000000000000000000000000000000000000000000000000
40004a4a44004a4a0404444499444900000d000e40004a4a44004a4a000000000000000000000000000000000000000000000000000000000000000000000000
40004444400044440404a4a494494400000dd0ee4000444404004444000000000000000000000000000000000000000000000000000000000000000000000000
44494400404944004404444440004444000444444449444004494440000000000000000000000000000000000000000000000000000000000000000000000000
99444900444449004000440040004a4a444444440994494409944940000000000000000000000000000000000000000000000000000000000000000000000000
90000400094404009444940040004444944494440400000709000004000000000000000000000000000000000000000000000000000000000000000000000000
4700047009940470994444470400e00d994444447000000004700007000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
888888880000000000000000000aa00000b00b000c0000c00d0000d0000000000000000000000000000000000000000000000000000000000000000000000000
999999990000000000099000000000000b0000b000c00c0000000000000000000000000000000000000000000000000000000000000000000000000000000000
aaaaaaaa00088000009009000a0000a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
bbbbbbbb00088000009009000a0000a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
cccccccc0000000000099000000000000b0000b000c00c0000000000000000000000000000000000000000000000000000000000000000000000000000000000
dddddddd0000000000000000000aa00000b00b000c0000c00d0000d0000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000004664444664444644444444440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000004446466444644444444444440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000006444466444446444444444440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000005646445464444444444444440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000bbbbbbbb6445446444444444444444440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000b4bb4b445544544564464446444444440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000044b444444665566544444644444444440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000444444445555555546644644444444440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
6d66d66d666666666666600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
d6dd6dd6606060606060600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
6d66d66d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
6d66d66d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__label__
7000000000000555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555c5c5ccc55555ccc55555ccc55
0700000000000555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555c5c5c5c5555555c55555c5c55
0070000000000555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555c5c5c5c555555cc55555c5c55
0700000000000555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555ccc5c5c5555555c55555c5c55
70000000000005555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555c55ccc55c55ccc55c55ccc55
00000000000005555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555550555055055555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555550555000055555555555555555555555555555555555555555555555555555555555555555555
555555555555555555555555555555555555555555555555555500550a0a55555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555558855555555055000055555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555995555558855555555000000555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555559559555555555555555000000555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555559559555555555555555055555055555555555555555555555555555555555555555555555555555555555555555555
5555555555555555555555555555aa55555995555555555555555005555055555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555a5555a555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555a5555a555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
555555555555555555555b55b555aa55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555b5555b555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555b5555b555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
555555555555555555555b55b5555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
5555555555555c5555c5555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555c55c55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555c55c55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
5555555555555c5555c5555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555d5555d555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555d5555d555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555545559555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555544599555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555544444555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555544444444555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555544494449555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555544444499555555555555555555555555555555555555555555555555555555555555555555555555555555555555

__gff__
0f0f0f0f0f0f0f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000090101010000000000000000000000090b0f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
4040404040404040404040404040400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4040404040404040404040404040400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4040404040404040404040404040400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4040404040404040404040404040400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4040404040404040404040404040400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4040404040404040404040404040400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4040404040404040404040404040400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4040404040404040404040404040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4440404040404040404040404040000000004400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4440404040404040404040404040400000444400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4440404040404040404040404040400000444400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4440404040404040404040404040400000004400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4440404040404040404040404040400000004400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4440404040404040404040404040400000004400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4440404044444040404040404040404444444400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4444444444444444404040404040400000004400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4444444444444444444440400040400000004400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4444444444444444444444444040400000004400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4444444444444444444444444440400000004400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4444444444444444444444444444444444444400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4444444444444444444444444444444444444400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
000400000c0500e0501110020100231002c1002e1003010023200232002220022200202001e2001d2001d2002cd002cd002bd002bd002bd002bd002bd001ab002bd002ad002bd002cd002cd002cd002cd0000000
00100000290501d0001f0500000019050000000804008030080300803008020080200802008010080100801000000000000000000000000000000000000000000000000000000000000000000000000000000000
0008000027150291502b1500000000000000000000000000000000000000000000000000000000000000000033100000000000000000000000000000000000000000000000000000000000000000000000000000
0008000015150181501c15020100231002c1002e1003010023200232002220022200202001e2001d2001d2002cd002cd002bd002bd002bd002bd002bd001ab002bd002ad002bd002cd002cd002cd002cd0000000
960600000113001130011400114001140011400113001130011300113001130001000110001100011000110001100011000110001100011000110001100001000010000100001000010000100001000010000100
000600001510018100000300004000040000400104000040000300003000030000500010000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100
