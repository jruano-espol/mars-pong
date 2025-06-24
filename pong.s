
# Data Section
# ----------------------------------------------- #
.data
    .eqv SCREEN_WIDTH  512
    .eqv SCREEN_HEIGHT 256

    framebuffer: .space 0x80000 # 4 * 512 * 256

    .eqv BALL_SIZE 5
    .eqv BALL_STARTING_X     253 # ((SCREEN_WIDTH  - BALL_SIZE) / 2)
    .eqv BALL_STARTING_Y     125 # ((SCREEN_HEIGHT - BALL_SIZE) / 2)
    .eqv BALL_STARTING_SPEED 1

    ball:
        ball_x:     .word BALL_STARTING_X
        ball_y:     .word BALL_STARTING_Y
        ball_vel_x: .word 1
        ball_vel_y: .word 1
        ball_speed: .word BALL_STARTING_SPEED

    .eqv PADDLE_WIDTH  5
    .eqv PADDLE_HEIGHT 25
    .eqv PADDLE_SPEED  3

    .eqv PADDLE_0_STARTING_X 10
    .eqv PADDLE_0_STARTING_Y 115 # ((SCREEN_HEIGHT - PADDLE_HEIGHT) / 2)

    paddle_0:
        paddle_0_x:     .word PADDLE_0_STARTING_X
        paddle_0_y:     .word PADDLE_0_STARTING_Y
        paddle_0_score: .word 0

    .eqv PADDLE_1_STARTING_X 497 # (SCREEN_WIDTH - PADDLE_WIDTH - PADDLE_0_STARTING_X)
    .eqv PADDLE_1_STARTING_Y PADDLE_0_STARTING_Y

    paddle_1:
        paddle_1_x:     .word PADDLE_1_STARTING_X
        paddle_1_y:     .word PADDLE_1_STARTING_Y
        paddle_1_score: .word 0

    .eqv Game_State_Serving 0
    .eqv Game_State_Playing 1
    game_state:
        .word Game_State_Serving

# Text Section
# ----------------------------------------------- #
.text

main:
    main_loop:
        la $t0, framebuffer
        li $t1, 0 # Black Color Value
        li $t2, 0 # i = 0
        clear_screen_loop:
            sw   $t1, 0($t0)  # *Bitmap = 0
            addi $t0, $t0, 4  # Bitmap += bytes_per_pixel
            addi $t2, $t2, 1  # i++
            li   $t3, 0x20000 # SCREEN_WIDTH * SCREEN_HEIGHT
            bne  $t2, $t3, clear_screen_loop

        jal draw_scores

        lw $a0, ball_x
        lw $a1, ball_y
        li $a2, BALL_SIZE
        li $a3, BALL_SIZE
        jal draw_rect

        lw $a0, paddle_0_x
        lw $a1, paddle_0_y
        li $a2, PADDLE_WIDTH
        li $a3, PADDLE_HEIGHT
        jal draw_rect

        lw $a0, paddle_1_x
        lw $a1, paddle_1_y
        li $a2, PADDLE_WIDTH
        li $a3, PADDLE_HEIGHT
        jal draw_rect

        lw $t0, game_state
        li $t1, Game_State_Serving
        beq $t0, $t1, case_serving

        case_playing:
            lw  $t1, ball_speed
            # Move the ball on the X Axis.
            lw  $t2, ball_vel_x
            mul $t2, $t2, $t1
            lw  $t0, ball_x
            add $t0, $t0, $t2
            sw  $t0, ball_x
            # Move the ball on the Y Axis.
            lw  $t2, ball_vel_y
            mul $t2, $t2, $t1
            lw  $t0, ball_y
            add $t0, $t0, $t2
            sw  $t0, ball_y

            # Checking if Player 0 moves up.
            lw  $t0, 0xffff0000
            beq $t0, $zero, key_w_is_NOT_held # if (key_event != 0)
                lw  $t0, 0xffff0004
                li  $t1, 119 # w
                bne $t0, $t1, key_w_is_NOT_held # if (key_pressed == 'w')
                    lw   $t0, paddle_0_y
                    addi $t0, $t0, -PADDLE_SPEED
                    sw   $t0, paddle_0_y
            key_w_is_NOT_held:

            # Checking if Player 0 moves down.
            lw  $t0, 0xffff0000
            beq $t0, $zero, key_s_is_NOT_held # if (key_event != 0)
                lw  $t0, 0xffff0004
                li  $t1, 115 # s
                bne $t0, $t1, key_s_is_NOT_held # if (key_pressed == 's')
                    lw   $t0, paddle_0_y
                    addi $t0, $t0, PADDLE_SPEED
                    sw   $t0, paddle_0_y
            key_s_is_NOT_held:

            # Checking if Player 1 moves up.
            lw  $t0, 0xffff0000
            beq $t0, $zero, key_i_is_NOT_held # if (key_event != 0)
                lw  $t0, 0xffff0004
                li  $t1, 105 # i
                bne $t0, $t1, key_i_is_NOT_held # if (key_pressed == 'i')
                    lw   $t0, paddle_1_y
                    addi $t0, $t0, -PADDLE_SPEED
                    sw   $t0, paddle_1_y
            key_i_is_NOT_held:

            # Checking if Player 1 moves down.
            lw  $t0, 0xffff0000
            beq $t0, $zero, key_k_is_NOT_held # if (key_event != 0)
                lw  $t0, 0xffff0004
                li  $t1, 107 # k
                bne $t0, $t1, key_k_is_NOT_held # if (key_pressed == 'k')
                    lw   $t0, paddle_1_y
                    addi $t0, $t0, PADDLE_SPEED
                    sw   $t0, paddle_1_y
            key_k_is_NOT_held:

            # Clamping the first paddle's position to always appear in the screen.
            lw   $a0, paddle_0_y
            li   $a1, 0
            li   $a2, SCREEN_HEIGHT
            addi $a2, $a2, -PADDLE_HEIGHT
            jal  clamp
            sw   $v0, paddle_0_y

            # Clamping the second paddle's position to always appear in the screen.
            lw   $a0, paddle_1_y
            li   $a1, 0
            li   $a2, SCREEN_HEIGHT
            addi $a2, $a2, -PADDLE_HEIGHT
            jal  clamp
            sw   $v0, paddle_1_y

            # Ball collision with the ceiling or floor
            lw   $t0, ball_y
            slti $t1, $t0, 1
            #    $t1 = 1 if (ball_y <= 0) else 0
            bne  $t1, $zero, collided_with_ceiling_OR_floor
            li   $t2, SCREEN_HEIGHT
            addi $t2, $t2, -BALL_SIZE
            slt  $t1, $t0, $t2
            #    $t1 = 0 if (ball_y + BALL_SIZE >= SCREEN_HEIGHT) else 1
            bne  $t1, $zero, did_NOT_collide_with_ceiling_OR_floor
            collided_with_ceiling_OR_floor:
                la  $a0, ball_vel_y
                jal bounce_ball
            did_NOT_collide_with_ceiling_OR_floor:

            # Ball collision with the paddles.
            lw  $a0, paddle_0_x
            lw  $a1, paddle_0_y
            jal does_ball_collide_with_paddle
            bne $v0, $zero, ball_collided_with_paddle
            lw  $a0, paddle_1_x
            lw  $a1, paddle_1_y
            jal does_ball_collide_with_paddle
            beq $v0, $zero, ball_did_NOT_collide_with_paddle
            ball_collided_with_paddle:
                la  $a0, ball_vel_x
                jal bounce_ball
                jal accelerate_ball
            ball_did_NOT_collide_with_paddle:

            # Player 0 scored.
            lw   $t0, ball_x
            li   $t1, SCREEN_WIDTH
            addi $t1, $t1, -BALL_SIZE
            slt  $t0, $t0, $t1
            #    $t0 = 0 if (ball_x + BALL_SIZE >= SCREEN_WIDTH) else 1
            bne  $t0, $zero, player_0_did_not_score
                lw   $t0, paddle_0_score
                addi $t0, $t0, 1
                sw   $t0, paddle_0_score
                jal  transition_to_serving
            player_0_did_not_score:

            # Player 1 scored.
            lw   $t0, ball_x
            slti $t0, $t0, 1
            #    $t0 = 1 if (ball_x <= 0) else 0
            beq  $t0, $zero, player_1_did_not_score
                lw   $t0, paddle_1_score
                addi $t0, $t0, 1
                sw   $t0, paddle_1_score
                jal  transition_to_serving
            player_1_did_not_score:

            j case_none

        case_serving:
            lw  $t0, 0xffff0000
            beq $t0, $zero, case_none # if (key_event != 0)
                lw  $t0, 0xffff0004
                li  $t1, 32 # space
                bne $t0, $t1, case_none # if (key_pressed == ' ')
                    li $t0, Game_State_Playing
                    sw $t0, game_state

        case_none:
        j   main_loop

# Helper Functions
# ----------------------------------------------- #

# args:
#     - a0: value
#     - a1: min
#     - a2: max
# returns:
#     - v0: min <= result <= max
clamp:
        slt $t0, $a0, $a1 # t0 = 1 if (value < min) else 0
        bne $t0, $zero, clamp__return_min
        slt $t0, $a0, $a2 # t0 = 0 if (value >= max) else 1
        beq $t0, $zero, clamp__return_max
        move $v0, $a0
        jr $ra
        clamp__return_min:
            move $v0, $a1
            jr $ra
        clamp__return_max:
            move $v0, $a2
            jr $ra


# args:
#     - a0: x coordinate
#     - a1: y coordinate
#     - a2: width
#     - a3: height
draw_rect:
    li $t0, SCREEN_WIDTH
    li $t1, 0xFFFFFFFF # color

    li $t2, 0 # $t2: y_offset
    rectangle_loop_y:
        li $t3, 0 # $t3: x_offset
        rectangle_loop_x:
            add $t4, $t3, $a0  # $t4: X = x + x_offset
            add $t5, $t2, $a1  # $t5: Y = y + y_offset

            mul $t6, $t5, $t0  # $t6 = (Y * screen_width)
            add $t6, $t6, $t4  # $t6 = (Y * screen_width + X)
            sll $t6, $t6, 2    # $t6 = (Y * screen_width + X) * 4
            la  $t7, framebuffer
            add $t7, $t7, $t6  # $t7 = Bitmap + $t6
            sw  $t1, 0($t7)    # Bitmap[4 * (Y * screen_width + X)] = color

            addi $t3, $t3, 1 # x_offset++
            bne  $t3, $a2, rectangle_loop_x  # if x_offset < width

        addi $t2, $t2, 1 # y_offset++
        bne  $t2, $a3, rectangle_loop_y  # if y_offset < height
    jr  $ra


transition_to_serving:
    li $t0, PADDLE_0_STARTING_X
    sw $t0, paddle_0_x
    li $t0, PADDLE_0_STARTING_Y
    sw $t0, paddle_0_y

    li $t0, PADDLE_1_STARTING_X
    sw $t0, paddle_1_x
    li $t0, PADDLE_1_STARTING_Y
    sw $t0, paddle_1_y

    li $t0, BALL_STARTING_X
    sw $t0, ball_x
    li $t0, BALL_STARTING_Y
    sw $t0, ball_y

    li $t0, 1
    sw $t0, ball_vel_x
    sw $t0, ball_vel_y

    li $t0, BALL_STARTING_SPEED
    sw $t0, ball_speed

    li $t0, Game_State_Serving
    sw $t0, game_state

    jr $ra


# args:
#     - a0: paddle_x
#     - a1: paddle_y
# returns:
#     - v0: boolean result
does_ball_collide_with_paddle:
    lw $t0, ball_x
    lw $t1, ball_y

    # Check (ball_x + BALL_SIZE >= paddle_x)
    addi $t2, $t0, BALL_SIZE
    slt  $t2, $t2, $a0 # $t2 = 0 if (ball_x + BALL_SIZE >= paddle_x) else 1
    bne  $t2, $zero, ball_collided_with_paddle_false

    # Check (paddle_x + PADDLE_WIDTH >= ball_x)
    addi $t2, $a0, PADDLE_WIDTH
    slt  $t2, $t2, $t0 # $t2 = 0 if (paddle_x + PADDLE_WIDTH >= ball_x) else 1
    bne  $t2, $zero, ball_collided_with_paddle_false

    # Check (ball_y + BALL_SIZE >= paddle_y)
    addi $t2, $t1, BALL_SIZE
    slt  $t2, $t2, $a1 # $t2 = 0 if (ball_y + BALL_SIZE >= paddle_y) else 1
    bne  $t2, $zero, ball_collided_with_paddle_false

    # Check (paddle_y + PADDLE_HEIGHT >= ball_y)
    addi $t2, $a1, PADDLE_HEIGHT
    slt  $t2, $t2, $t1 # $t2 = 0 if (paddle_y + PADDLE_HEIGHT >= ball_y) else 1
    bne  $t2, $zero, ball_collided_with_paddle_false

    # Return true
    li $v0, 1
    jr $ra

    # Return false
    ball_collided_with_paddle_false:
    li $v0, 0
    jr $ra


# args:
#     - a0: la ball_vel_(x or y)
bounce_ball:
    # ball_vel_? *= -1
    lw  $t0, 0($a0)
    mul $t0, $t0, -1
    sw  $t0, 0($a0)
    jr $ra


accelerate_ball:
    lw   $t0, ball_speed
    addi $t0, $t0, 1
    sw   $t0, ball_speed
    jr $ra

# TODO: Fix this (Will probably print the numbers in the console.)
draw_scores:
    # addi $sp, $sp, -4
    # sw   $ra, 0($sp)
    #
    # lw   $a0, paddle_0_score
    # jal  get_digit_count
    #
    # li   $a0, SCREEN_WIDTH/2 - 2
    # li   $a1, 10
    # lw   $a2, paddle_0_score
    # move $a3, $v0
    # jal  draw_u32
    #
    # lw   $a0, paddle_1_score
    # jal  get_digit_count
    #
    # li   $a0, SCREEN_WIDTH/2 + 2
    # li   $a1, 10
    # lw   $a2, paddle_1_score
    # move $a3, $v0
    # jal  draw_u32
    #
    # lw   $ra, 0($sp)
    # addi $sp, $sp, 4
    jr   $ra


