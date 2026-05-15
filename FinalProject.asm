; Snake Game
name "snake"
org 100h

jmp start

; ------ data section ------
s_size      equ     30      
snake       dw s_size dup(0)
tail        dw      ?
slen        dw      7
left        equ     4bh
right       equ     4dh
up          equ     48h
down        equ     50h

min_x       equ     1
max_x       equ     78
min_y       equ     2
max_y       equ     23

cur_dir     db      right
wait_time   dw      0
fx          db      30
fy          db      12
score       dw      0

msg         db "==== SNAKE GAME ====", 0dh,0ah
            db "Arrow keys to move (Up, Down, Left, Right)", 0dh,0ah
            db "Eat the hearts (", 03h, ")", 0dh,0ah
            db "Don't hit walls or tail!", 0dh,0ah
            db "Esc to exit", 0dh,0ah
            db "====================", 0dh,0ah, 0ah
            db "Press any key to start!$"
sc_msg      db "Score:$"
over_msg    db 0dh, 0ah, "GAME OVER! Final Score: $"
replay_msg  db 0dh, 0ah, "Play again? (Y/N): $"

; ------ code section ------
start:
    mov dx, offset msg
    mov ah, 9 
    int 21h
    mov ah, 00h
    int 16h
    cmp al, 1bh
    je exit_p

init_game:
    mov score, 0
    mov slen, 7
    mov cur_dir, right
    mov fx, 30
    mov fy, 15
    
    mov cx, s_size
    mov di, 0
clear_array:
    mov snake[di], 0FFFFh 
    add di, 2
    loop clear_array

    mov snake[0], 0A14h   ; Start at X=20, Y=10 (Safe middle)
    
    mov ax, 0003h       
    int 10h
    mov ah, 01h         
    mov ch, 3Fh
    int 10h

    mov ax, 0B800h
    mov es, ax      

    call draw_borders

game_loop:
    ; 1. Draw Food (Heart)
    mov al, fy
    mov bl, 80
    mul bl
    add al, fx
    adc ah, 0
    shl ax, 1
    mov di, ax
    mov es:[di], 0C03h 

    ; 2. Draw Snake Body (Full Blocks)
    mov cx, slen
    mov si, 0
draw_body_loop:
    mov dx, snake[si]
    cmp dx, 0FFFFh     
    je skip_draw
    mov al, dh
    mov bl, 80
    mul bl
    add al, dl
    adc ah, 0
    shl ax, 1
    mov di, ax
    mov es:[di], 02DBh 
skip_draw:
    add si, 2
    loop draw_body_loop

    ; 3. Draw Snake Head (Directional)
    mov dx, snake[0]
    mov al, dh
    mov bl, 80
    mul bl
    add al, dl
    adc ah, 0
    shl ax, 1
    mov di, ax
    
    mov al, 10h        
    cmp cur_dir, left
    jne check_up
    mov al, 11h
    jmp apply_head
check_up:
    cmp cur_dir, up
    jne check_down
    mov al, 1Eh
    jmp apply_head
check_down:
    cmp cur_dir, down
    jne apply_head
    mov al, 1Fh
apply_head:
    mov ah, 0Ah        
    mov es:[di], ax

    ; 4. Show Score 
    mov dh, 0
    mov dl, 0
    mov ah, 02h
    int 10h
    mov dx, offset sc_msg
    mov ah, 9
    int 21h
    mov ax, score
    call pnum

    ; 5. Move Logic
    mov bx, slen
    shl bx, 1
    sub bx, 2
    mov ax, snake[bx]
    mov tail, ax
    call move_snake

    call check_collision

    ; 6. Food Logic
    mov al, b.snake[0]
    cmp al, fx
    jne nofood
    mov al, b.snake[1]
    cmp al, fy
    jne nofood

    inc score
    cmp slen, s_size
    jae nofood
    inc slen
    
    ; Randomize Food
    mov ah, 00h
    int 1ah
    mov ax, dx
    xor dx, dx
    mov bx, (max_x - min_x + 1)
    div bx
    add dl, min_x
    mov fx, dl      

    mov ah, 00h
    int 1ah
    mov ax, dx
    xor dx, dx
    mov bx, (max_y - min_y + 1)
    div bx
    add dl, min_y
    mov fy, dl      

nofood:
    ; 7. Hide Tail
    mov dx, tail
    cmp dx, 0FFFFh
    je no_hide
    mov al, dh
    mov bl, 80
    mul bl
    add al, dl
    adc ah, 0
    shl ax, 1
    mov di, ax
    mov es:[di], 0720h 
no_hide:

    ; 8. Input & Delay
    mov ah, 01h
    int 16h
    jz no_key
    mov ah, 00h
    int 16h
    cmp al, 1bh
    je exit_p
    
    cmp ah, left
    jne c_right
    cmp cur_dir, right
    je no_key
    jmp upd
c_right:
    cmp ah, right
    jne c_up
    cmp cur_dir, left
    je no_key
    jmp upd
c_up:
    cmp ah, up
    jne c_down
    cmp cur_dir, down
    je no_key
    jmp upd
c_down:
    cmp ah, down
    jne no_key
    cmp cur_dir, up
    je no_key
upd:
    mov cur_dir, ah

no_key:
    mov ah, 00h
    int 1ah
    cmp dx, wait_time
    jb no_key
    add dx, 1
    mov wait_time, dx
    jmp game_loop

stop_game:
    mov ax, 0003h
    int 10h
    mov dx, offset over_msg
    mov ah, 9
    int 21h
    mov ax, score
    call pnum
    mov dx, offset replay_msg
    mov ah, 9
    int 21h

ask_key:
    mov ah, 00h
    int 16h
    cmp al, 1bh
    je exit_p
    cmp al, 'y'
    je init_game
    cmp al, 'Y'
    je init_game
    cmp al, 'n'
    je exit_p
    cmp al, 'N'
    je exit_p
    jmp ask_key

exit_p:
    mov ax, 0003h
    int 10h
    ret

; --- Subroutines ---

draw_borders proc near
    mov cx, 80
    mov di, 0
draw_tb:
    mov es:[di + (min_y-1)*160], 07B0h 
    mov es:[di + (max_y+1)*160], 07B0h 
    add di, 2
    loop draw_tb
    mov cx, (max_y - min_y + 3)
    mov di, (min_y-1)*160
draw_lr:
    mov es:[di + (min_x-1)*2], 07B0h   
    mov es:[di + (max_x+1)*2], 07B0h   
    add di, 160
    loop draw_lr
    ret
draw_borders endp

check_collision proc near
    mov al, b.snake[0] 
    cmp al, min_x
    jb stop_jump
    cmp al, max_x
    ja stop_jump
    mov al, b.snake[1] 
    cmp al, min_y
    jb stop_jump
    cmp al, max_y
    ja stop_jump
    mov ax, snake[0]    
    mov cx, slen
    dec cx              
    jz no_coll     
    mov si, 2           
coll_loop:
    cmp ax, snake[si]   
    je stop_jump
    add si, 2
    loop coll_loop
no_coll:
    ret
stop_jump:
    pop ax
    jmp stop_game
check_collision endp

move_snake proc near
    mov bx, slen
    shl bx, 1
    sub bx, 2
    mov di, bx
    mov cx, slen
    dec cx
move_arr:
    test cx, cx
    jz d_move
    mov ax, snake[di-2]
    mov snake[di], ax
    sub di, 2
    loop move_arr
d_move:
    cmp cur_dir, left
    je ml
    cmp cur_dir, right
    je mr
    cmp cur_dir, up
    je mu
    cmp cur_dir, down
    je md
    ret
ml: dec b.snake[0]
    ret
mr: inc b.snake[0]
    ret
mu: dec b.snake[1]
    ret
md: inc b.snake[1]
    ret
move_snake endp

pnum proc near
    mov cx, 0
    mov bx, 10
p1: xor dx, dx
    div bx
    push dx
    inc cx
    test ax, ax
    jne p1
p2: pop dx
    add dl, '0'
    mov ah, 02h
    int 21h
    loop p2
    ret
pnum endp
