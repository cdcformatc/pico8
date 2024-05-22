pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
function _init()
	debug=true

	-- set beige transparent
	palt(15, true)
	-- set black not transparent
	palt(0, false)
	
	-- set game state
	game_over=false

	-- make cats
	cat1=make_cat(1)
	cat2=make_cat(2)

	main_cat=cat1
	other_cat=cat2
end


function _update()
	if (not game_over) then
		check_swap()
		move_cat(main_cat)
		move_cat(other_cat)
	else
		if (btnp(5,0) or btnp(5,1)) _init()
	end
end


function _draw()
	cls(5)
	draw_cats()
	if debug then
		debug_cat(cat1)
		debug_cat(cat2)
	end

	if (game_over) then
		print("game over!",44,44,7)
		print("press ❎ to play again!",18,72,7)
	end
end


-->8
-- cat logic

-- movement constants
dy_gravity=0.2

dy_jump=-18*dy_gravity
dy_down=dy_gravity

dx_move=2
ddx_air=0.888
ddx_slow=.625

max_dx=4
max_dy=8

-- timer constants
sit_time=0.5*60
loaf_time=3*60
sleep_time=6*60

-- cat_states
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

function is_idle_state(state)
	return (state==state_sitting or state==state_loafing or state==state_sleeping)
end

local sprite_tbl = {
	3, 	--state_init
	3,	--state_unknown
	3,	--state_dead
	0,	--state_standing
	5,	--state_jumping
	6,	--state_falling
	0,	--state_running
	1,	--state_sitting
	2,	--state_loafing
	4,	--state_sleeping
}

function get_sprite(cat)
	return sprite_tbl[cat.state]+(cat.n*16)
end

function make_cat(n)
	c={}
	c.n=n-1
	c.p=c.n
	c.x=24
	c.y=60
	c.dy=0
	c.dx=0
	c.t=0
	c.state=state_init
	
	if (c.n == 1) then
		-- move cat1 on init
		c.x+=12
		c.flip_h=true
		c.lazy_factor=1
	else
		c.lazy_factor=1.25
	end
	return c
end

function check_btns(cat)
	local p=cat.p
	local d={}
	d.x=0
	d.y=0

	if (btn(⬅️,p)) then
		d.x-=dx_move
	end
	if (btn(➡️,p)) then
		d.x+=dx_move
	end
	if (btnp(⬆️,p) and not cat.falling) then
		sfx(0)
		d.y+=dy_jump
	end
	if (btnp(⬇️,p)) then
		d.y+=dy_down
	end
	if d.x>10 then
		d.x=10
	end
	if d.x<-10 then
		d.x=-10
	end
	return d
end

function is_on_floor(cat)
	return cat.y >= 120
end

function move_cat(cat)
	-- do gravity
	cat.dy+=dy_gravity

	-- check user input
	d=check_btns(cat)

	-- apply user input
	cat.dy+=d.y
	cat.dx+=d.x

	-- apply x friction
	if (is_on_floor(cat)) then
		cat.dx*=ddx_slow
	else
		cat.dx*=ddx_air
	end

	-- cap speed
	if (abs(cat.dx)<.1) cat.dx=0
	
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
	
	set_cat_state(cat)
end

function set_cat_state(cat)
	local old_state=cat.state
	local new_state=state_unknown

	if (is_on_floor(cat)) then
		printh("n: "..cat.n.."is_on_floor")
		if (cat.dx!=0) then
			new_state=state_running
		else
			local idle_time = cat.t*cat.lazy_factor
			if (idle_time>=sit_time) new_state=state_sitting
			if (idle_time>=loaf_time) new_state=state_loafing
			if (idle_time>=sleep_time) new_state=state_sleeping
		end
	else
		printh("n: "..cat.n.."is in air")
		-- cat is in the air
		if (cat.dy>0) then 
			new_state=state_falling
		else
			new_state=state_jumping
		end
	end
	
	printh("n: "..cat.n.." dx"..cat.dx.." dy"..cat.dy)
	printh("old: "..old_state.." new "..new_state)

	if (new_state!=old_state and new_state!=state_unknown) then
		-- set state
		cat.state=new_state
		
		if (not is_idle_state(new_state)) then
			-- reset idle timer
			cat.t=0
		end
	else
		-- increment idle timer
		cat.t+=1
	end
end

function draw_cat(cat)
	if (cat.dx<0) cat.flip_h=true
	if (cat.dx>0) cat.flip_h=false
	
	spr(get_sprite(cat),cat.x,cat.y,1,1,cat.flip_h)

	--if (game_over) then
		--do_draw(cat.s.dead,cat)
	--elseif (cat.dy<0) then
	--	do_draw(cat.s.fall,cat)
	--elseif (cat.dy>0) then
		--do_draw(cat.s.jump,cat)
	--elseif (cat.dy==0 and cat.dx==0) then
		--if (cat.falling) then
			--do_draw(cat.s.fall,cat)
		--elseif cat.t>60*3 then
			--do_draw(cat.s.loaf,cat)
		--elseif cat.t>30 then
			--do_draw(cat.s.sit,cat)
		--else
			--do_draw(cat.s.stand,cat)
		--end
	--else
		--do_draw(cat.s.stand,cat)
	--end
end

function draw_cats()
	draw_cat(other_cat)
	draw_cat(main_cat)
end
-->8
-- cat swap control

function swap_cats(what,player)
	-- swap cats
	if (what==0) then
		main_cat=cat1
		other_cat=cat2
	else
		main_cat=cat2
		other_cat=cat1
	end

	-- play cat sfx
	if (player==0) then
	 sfx(2+main_cat.n)
	else
	 sfx(2+other_cat.n)
	end

	main_cat.p=0
	other_cat.p=1
end

function check_swap()
	-- check if swap button pressed
	if (btnp(🅾️,0)) then
		swap_cats(0,0)
	end 
	if (btnp(❎,0)) then
		swap_cats(1,0)
	end
	if (btnp(🅾️,1)) then
		swap_cats(0,1)
	end
	if (btnp(❎,1)) then
		swap_cats(1,1)
	end
end
-->8


function printn(s,n,x,y)
	print(sub(s,0,n),x,y)
end

function debug_cat(cat)
	c_w=4
	c_h=6
	x=cat.n*8*c_w
	y=0

	print(cat.n,x,y)
	y+=c_h
	print(cat.state,x,y)
	y+=c_h
	printn(cat.x,7,x,y)
	y+=c_h
	printn(cat.y,7,x,y)
	y+=c_h
	printn(cat.dx,7,x,y)
	y+=c_h
	printn(cat.dy,7,x,y)
	y+=c_h
	printn(cat.t,7,x,y)
end
__gfx__
f0ff0ff0ffff0ff0fff0fff000fff00fffffffffffff0ff0ffff0ff0000000000000000000000000000000000000000000000000000000000000000000000000
0fff0000f0ff0000fff00f000ffff0ffffffffff0fff00000fff0000000000000000000000000000000000000000000000000000000000000000000000000000
0fff0a0a0fff0a0af0f00000000000fffff0fff0f0ff0a0af0ff0a0a000000000000000000000000000000000000000000000000000000000000000000000000
0fff00000fff0000f0f0a0a0000000fffff00f00f0ff0000f0ff0000000000000000000000000000000000000000000000000000000000000000000000000000
000000ff0f0000ff0ff000000fff0000fff00000f00000fff00000ff000000000000000000000000000000000000000000000000000000000000000000000000
000000fff00000ff0fff00ff0fff0a0a00000000f000000ff00000ff000000000000000000000000000000000000000000000000000000000000000000000000
0ffff0fff000f0ff000000ff0fff000000000000f0ffff0ff0fff0ff000000000000000000000000000000000000000000000000000000000000000000000000
00fff00ff000f00f00000000f0ff0ff00000000000ffffff0ffff00f000000000000000000000000000000000000000000000000000000000000000000000000
f4ff9ff4ffff9ff4fff9fff444fff44fffffffffffff9ff400000000000000000000000000000000000000000000000000000000000000000000000000000000
4fff4444f4ff4444fff99f444ffff4ffffffffff4fff444400000000000000000000000000000000000000000000000000000000000000000000000000000000
4fff4a4a4fff4a4af4f44444994449fffff9fff4f4ff4a4a00000000000000000000000000000000000000000000000000000000000000000000000000000000
4fff44444fff4444f4f4a4a4944944fffff99f44f4ff444400000000000000000000000000000000000000000000000000000000000000000000000000000000
944944ff4f4944ff4ff444444fff4444fff44444f94944ff00000000000000000000000000000000000000000000000000000000000000000000000000000000
994449fff44449ff4fff44ff4fff4a4a44444444f944494f00000000000000000000000000000000000000000000000000000000000000000000000000000000
4ffff4fff944f4ff944494ff4fff444494449444f9ffff4f00000000000000000000000000000000000000000000000000000000000000000000000000000000
44fff44ff994f44f99444444f4ff9ff49944444444ffffff00000000000000000000000000000000000000000000000000000000000000000000000000000000
__label__
88888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888
88888eeeeee888777777888888888888888888888888888888888888888888888888888888888888888ff8ff8888228822888222822888888822888888228888
8888ee888ee88778877788888888888888888888888888888888888888888888888888888888888888ff888ff888222222888222822888882282888888222888
888eee8e8ee87777877788888e88888888888888888888888888888888888888888888888888888888ff888ff888282282888222888888228882888888288888
888eee8e8ee8777787778888eee8888888888888888888888888888888888888888888888888888888ff888ff888222222888888222888228882888822288888
888eee8e8ee87777877788888e88888888888888888888888888888888888888888888888888888888ff888ff888822228888228222888882282888222288888
888eee888ee877788877888888888888888888888888888888888888888888888888888888888888888ff8ff8888828828888228222888888822888222888888
888eeeeeeee877777777888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66556555655565556655656566666666655566666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
65666566656565656566656566566666656566666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
65556556655565566566655566666666655566666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66656566656565656566656566566666656666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
65566555656565656655656566666656656666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
11111661117116661661161616111111166616161661166611111ccc111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111166111116611666166616611111166616661166166611111ccc111111111111111111111111111111111111111111111111111111111111111111111111
1111161111111616161116161616177716161616161116111171111c111111111111111111111111111111111111111111111111111111111111111111111111
111116661111161616611666161611111661166616661661177711cc111111111111111111111111111111111111111111111111111111111111111111111111
1111111611111616161116161616177716161616111616111171111c111111111111111111111111111111111111111111111111111111111111111111111111
11111661117116661666161616661111166616161661166611111ccc111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111eee1eee1eee1e1e1eee1ee11111116611111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111e1e1e1111e11e1e1e1e1e1e1111161111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111ee11ee111e11e1e1ee11e1e1111166611111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111e1e1e1111e11e1e1e1e1e1e1111111611111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111e1e1eee11e111ee1e1e1e1e1111166111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
1eee1ee11ee111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
1e111e1e1e1e11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
1ee11e1e1e1e11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
1e111e1e1e1e11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
1eee1e1e1eee11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
1eee1e1e1ee111ee1eee1eee11ee1ee1111116661666161616661111116616661666117116611171111111111111111111111111111111111111111111111111
1e111e1e1e1e1e1111e111e11e1e1e1e111116661616161616111111161116161161171116161117111111111111111111111111111111111111111111111111
1ee11e1e1e1e1e1111e111e11e1e1e1e111116161666166116611111161116661161171116161117111111111111111111111111111111111111111111111111
1e111e1e1e1e1e1111e111e11e1e1e1e111116161616161616111111161116161161171116161117111111111111111111111111111111111111111111111111
1e1111ee1e1e11ee11e11eee1ee11e1e111116161616161616661666116616161161117116161171111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111166111111771771111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111611177711711171111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111611111117711177111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111611177711711171111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111166111111771771111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111166111116611111166111111cc1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
111116111111161617771616111111c1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
111116111111161611111616177711c1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
111116111111161617771616111111c1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111166117116161111161611111ccc111111111711111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111aaaaaaaaa111111111111111111111111771111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111166aaaaa666a111116611111661111111111777111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111611aaaaa6a6a777161111111616111111111777711111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111611aaaaa666a111161111111616111111111771111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111611aaaaa6aaa777161111111616111111111117111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111166aa7aa6aaa111116611711616111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
111111661111161611111ccc1c1c1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111611111116161777111c1c1c1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
111116111111116111111ccc1ccc1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
111116111111161617771c11111c1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
111111661171161611111ccc111c1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
111111661111161611111c111ccc1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
111116111111161617771c111c1c1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
111116111111166611111ccc1c1c1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
111116111111111617771c1c1c1c1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
111111661171166611111ccc1ccc1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
1111116611111661161611111ccc1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
1111161111111616161617771c1c1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
1111161111111616166611111c1c1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
1111161111111616111617771c1c1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
1111116611711666166611111ccc1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
1111116611111661161611111ccc1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
1111161111111616161617771c1c1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
1111161111111616116111111c1c1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
1111161111111616161617771c1c1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
1111116611711666161611111ccc1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111166111111661111166616661616166611111166166616661666166616661166117111661111166117171cc11c1111711111111111111111111111111111
111116111111161117771666161616161611111116111616161611611161161116111711161111111616117111c11c1111171111111111111111111111111111
111116111111166611111616166616611661111116661666166111611161166116661711161111111616177711c11ccc11171111111111111111111111111111
111116111111111617771616161616161611111111161611161611611161161111161711161111111616117111c11c1c11171111111111111111111111111111
11111166117116611111161616161616166616661661161116161666116116661661117111661171161617171ccc1ccc11711111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111eee1eee11111171116611111661111111111cc1117111111eee1e1e1eee1ee1111111111111111111111111111111111111111111111111111111111111
111111e11e11111117111611111116161777177711c11117111111e11e1e1e111e1e111111111111111111111111111111111111111111111111111111111111
111111e11ee1111117111611111116161111111111c11117111111e11eee1ee11e1e111111111111111111111111111111111111111111111111111111111111
111111e11e11111117111611111116161777177711c11117111111e11e1e1e111e1e111111111111111111111111111111111111111111111111111111111111
11111eee1e1111111171116611711616111111111ccc1171111111e11e1e1eee1e1e111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111116611111616111111111cc11ccc11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
111111111611111116161171177711c1111c11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
111111111611111111611777111111c11ccc11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
111111111611111116161171177711c11c1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111116611711616111111111ccc1ccc11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
111111111166111116661611166616661111161611111ccc1ccc1c1c1ccc11111111111111111111111111111111111111111111111111111111111111111111
1111111116111111161116111161161611111616177711c11c1c1c1c1c1111111111111111111111111111111111111111111111111111111111111111111111
1111111116111111166116111161166611111666111111c11cc11c1c1cc111111111111111111111111111111111111111111111111111111111111111111111
1111111116111111161116111161161111111616177711c11c1c1c1c1c1111111111111111111111111111111111111111111111111111111111111111111111
1111111111661171161116661666161116661616111111c11c1c11cc1ccc11111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111eee1ee11ee11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111e111e1e1e1e1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111ee11e1e1e1e1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111e111e1e1e1e1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111eee1e1e1eee1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
88888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888
82888222822882228888822282228882822882828222888888888888888888888888888888888888888888888228888882228822828282228228882288866688
82888828828282888888888288828828882882828882888888888888888888888888888888888888888888888828888888288282828282888282828888888888
82888828828282288888822288228828882882228222888888888888888888888888888888888888888888888828888888288282822882288282822288822288
82888828828282888888828888828828882888828288888888888888888888888888888888888888888888888828888888288282828282888282888288888888
82228222828282228888822282228288822288828222888888888888888888888888888888888888888888888222888888288228828282228282822888822288
88888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888

__map__
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0101010100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0101000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
000400000c0500e0501110020100231002c1002e1003010023200232002220022200202001e2001d2001d2002cd002cd002bd002bd002bd002bd002bd001ab002bd002ad002bd002cd002cd002cd002cd0000000
00100000290501d0001f0500000019050000000804008030080300803008020080200802008010080100801000000000000000000000000000000000000000000000000000000000000000000000000000000000
0008000027150291502b1500000000000000000000000000000000000000000000000000000000000000000033100000000000000000000000000000000000000000000000000000000000000000000000000000
0008000015150181501c15020100231002c1002e1003010023200232002220022200202001e2001d2001d2002cd002cd002bd002bd002bd002bd002bd001ab002bd002ad002bd002cd002cd002cd002cd0000000
0008000015100181001c10020100231002c1002e1003010023200232002220022200202001e2001d2001d2002cd002cd002bd002bd002bd002bd002bd001ab002bd002ad002bd002cd002cd002cd002cd0000000
