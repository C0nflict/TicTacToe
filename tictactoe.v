module main

import gx
import gg
import glfw
import time
import freetype

const (
    Width = 450
    Height = Width
    GridSize = 3
    StrokesPerDimen = GridSize - 1
    Increment = Width / GridSize

    TextSize = 12
    Red = gx.rgb(253, 32, 47)
)

const (
	text_cfg = gx.TextCfg{
		align:gx.ALIGN_LEFT
		size:TextSize
		color:gx.rgb(0, 0, 0)
	}
)

struct Game {
    mut:
    grid    [][]int
    turn    int     // 0 = player1; 1 = player2
    gg      &gg.GG
    // ft context for font drawing
	ft          &freetype.Context
	font_loaded bool
    nav_x    int
    nav_y    int
    selecting   int   // Who is selecting?
                      // -1 (nobody), 0 (p1), 1 (p2)
    game_over   bool
}

fn main() {
    glfw.init()

    mut game := &Game {
        gg: gg.new_context(gg.Cfg {
            width: Width
            height: Height
            use_ortho: true
            create_window: true
            window_title: 'Tic-Tac-Toe'
            window_user_ptr: game
        })
        ft: 0
    }

    game.grid = []array_int
    game.turn = 0
    game.selecting = 0

    game.gg.window.set_user_ptr(game)
    game.gg.window.onkeydown(key_down)

    game.init_grid()
    // Try to load font
	game.ft = freetype.new_context(gg.Cfg{
			width: Width
			height: Height
			use_ortho: true
			font_size: 18
			scale: 2
	})
	game.font_loaded = (game.ft != 0 )

    for {
        gg.clear(gx.White)
        game.draw()
        game.gg.render()
        if game.gg.window.should_close() {
            game.gg.window.destroy()
            return
        }
    }
}

fn (g mut Game) init_grid() {
    for i := 0; i < GridSize; i++ {
        g.grid << [-1].repeat(GridSize)
    }
}

fn (g mut Game) draw_current_player() {
    if g.font_loaded {
        if g.game_over {
            g.ft.draw_text(Width / 2, 10, "Game Over!", text_cfg)
        } else {
            g.ft.draw_text(Width / 2, 10, "Player: $g.turn", text_cfg)
        }
    }
}

fn (g mut Game) draw() {
    g.draw_current_player()
    g.draw_skeleton()
    if g.selecting != -1 {
        g.surround_nav()
    }
    for y := 0; y < GridSize; y++ {
        row := g.grid[y]
        for x := 0; x < GridSize; x++ {
            // Draw the appropriate symbol
            if row[x] == 0 {
                g.draw_cross(x, y)
            } else if row[x] == 1 {
                g.draw_plus(x, y)
            }
        }
    }
}

fn (g mut Game) surround_nav() {
    dx := g.nav_x * Increment
    dy := g.nav_y * Increment
    dx2 := Increment
    dy2 := Increment
    g.gg.draw_rect(dx, dy, dx2, dy2, Red)
}

// x,y coords, value, for player
fn (g mut Game) set(x, y, p int) {
    for yg := 0; yg <= y; yg++ {
        if yg == y {
            for xg := 0; xg <= x; xg++ {
                if xg == x {
                    mut row := g.grid[y]
                    if row[x] != -1 {
                        return
                    }

                    row[x] = p
                    g.grid[y] = row

                    return
                }
            }
        }
    }
}

// -2 = invalid
fn (g Game) check_tile(x, y int) int {
    if x < 0 || x > (GridSize - 1) || y < 0 || y > (GridSize - 1) {
        return -2
    }

    println("Checking tile x=$x,y=$y")
    row := g.grid[y]
    return row[x]
}

fn (g mut Game) draw_skeleton() {
    for i := 1; i <= StrokesPerDimen; i++ {
        xy := i * Increment
        g.gg.draw_line(xy, 0, xy, Height)
        g.gg.draw_line(0, xy, Width, xy)
    }
}

fn (g mut Game) draw_cross(x, y int) {
    dx := x * Increment
    dy := y * Increment
    g.gg.draw_line(dx, dy, dx + Increment, dy + Increment)
    g.gg.draw_line(dx + Increment, dy, dx, dy + Increment)
}

// gg.circle is yet unimplemented
/*fn (g mut Game) draw_circle(x, y int) {
    g.gg.circle(x * Increment, y * Increment, Increment - 5)
}*/

fn (g Game) draw_plus(x, y int) {
    dx := x * Increment
    dy := y * Increment
    dxmid := dx + (Increment / 2)
    dymid := dy + (Increment / 2)
    g.gg.draw_line(dxmid, dy, dxmid, dy + Increment)
    g.gg.draw_line(dx, dymid, dx + Increment, dymid)
}

fn check_equal(a []int) bool {
    cmp := a[0]
    for i := 1; i < a.len; i++ {
        if a[i] != cmp {
            return false
        }
    }
    return true
}

fn only_contains(a []int, except int) bool {
    for i := 0; i < a.len; i++ {
        if a[i] != except {
            return false
        }
    }
    return true
}

fn (g Game) check_over() bool {
    // Check horizontally
    for y := 0; y < GridSize; y++ {
        row := g.grid[y]

        if only_contains(row, -1) {
            continue
        }

        if check_equal(row) {
            return true
        }
    }

    println("Checking vertically")
    for x := 0; x < GridSize; x++ {
        mut column := []int
        for y := 0; y < GridSize; y++ {
            column << g.check_tile(x, y)
        }

        if only_contains(column, -1) {
            println("This column only contains empty tiles.")
            continue
        }

        if check_equal(column) {
            println("Found a game over")
            return true
        }
    }
    println("End vertical check")

    // Check diagonally from the top left
    // to the bottom right
    mut diag_arr_lr := []int
    for i := 0; i < GridSize; i++ {
        diag_arr_lr << g.check_tile(i, i)
    }

    // If there are not only empty tiles in the diagonal
    if !only_contains(diag_arr_lr, -1) {
        if check_equal(diag_arr_lr) {
            return true
        }
    }

    mut diag_arr_rl := []int
    for i := GridSize; i > 0; i-- {
        diag_arr_rl << g.check_tile(i, i)
    }

    if !only_contains(diag_arr_rl, -1) {
        if check_equal(diag_arr_rl) {
            return true
        }
    }

    return false
}

fn (g mut Game) confirm_selection() {
    g.set(g.nav_x, g.nav_y, g.turn)
}

fn key_down(wnd voidptr, key, code, action, mods int) {
	if action != 2 && action != 1 {
		return
	}

	mut game := &Game(glfw.get_window_user_pointer(wnd))

    if game.game_over {
        game.selecting = -1
        return
    }

	switch key {
	case glfw.KEY_ESCAPE:
		glfw.set_should_close(wnd, true)
	case glfw.key_space:
        if game.check_tile(game.nav_x, game.nav_y) != -1 {
            return
        }

        tile := game.check_tile(game.nav_x, game.nav_y)

        game.confirm_selection()
        if game.check_over() {
            game.game_over = true
            return
        }
        game.turn = 1 - game.turn
    case glfw.KeyUp:
        if game.selecting != -1 && game.nav_y > 0 {
            game.nav_y--
            println("$game.nav_x,$game.nav_y")
        }
    case glfw.KeyDown:
        if game.selecting != -1 && game.nav_y < GridSize - 1 {
            game.nav_y++
            println("$game.nav_x,$game.nav_y")
        }
    case glfw.KeyLeft:
        if game.selecting != -1 && game.nav_x > 0 {
            game.nav_x--
            println("$game.nav_x,$game.nav_y")
        }
    case glfw.KeyRight:
        if game.selecting != -1 && game.nav_x < GridSize - 1 {
            game.nav_x++
            println("$game.nav_x,$game.nav_y")
        }
	}
}
