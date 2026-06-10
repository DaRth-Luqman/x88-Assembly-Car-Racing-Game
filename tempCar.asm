[org 0x0100]                          ; Code origin for .COM file

jmp gameStart                        ; Jump to start of code

; ==============================================================
; === DATA SECTION ===
; ==============================================================

screenBuffer: times 4000 db 0         ; Reserve 4000 bytes for double buffering
roadTemplate: times 160 dw 0          ; Reserve buffer for road scroll pattern
oldKbisr: dd 0                        ; Storage for old keyboard ISR address
oldTimer: dd 0                        ; Storage for old timer ISR address
gameActive: db 1                      ; Flag: 1=Active, 0=Game Over
exitRequested: db 0                   ; Flag: 1=Exit requested
enterPressed: db 0                    ; Flag: 1=Enter key pressed
tickCount: dw 0                       ; Counter for timer ticks
randomSeed: dw 0x3045                 ; Seed for random number generation
treeOffset: db 1                      ; Offset for tree drawing
treeSpawnCounter: dw 0                ; Counter for tree frequency
treePattern: db 0                     ; Current tree pattern index
playerScore: dw 0                     ; Player score variable
currentPlayerLane: db 2               ; Player lane (1, 2, or 3)

; Music Variables
musicPointer: dw marioMelody          ; Pointer to current note in melody
musicTimer: dw 1                      ; Counter for note duration
muteBackground: db 0                  ; Flag: 1=Mute music (for sound effects)

; Game Configuration
obstacleSpawnTimer: dw 1              ; Timer for obstacle spawning
obstacleLanePositions: dw 46, 72, 98  ; Lane X positions for obstacles
lastCarLane: dw 0xFFFF                ; Track the lane of the last spawned car
bonusSpawnTimer: dw 5                 ; Timer for bonus spawning
bonusLanePositions: dw 48, 74, 100    ; Lane X positions for bonuses

; Sound Constants
pitControl: equ 0x43                  ; PIT Control Port
pitChannel2: equ 0x42                 ; PIT Channel 2 Port
speakerPort: equ 0x61                 ; PC Speaker Port

; Strings
gameOverMessage: db 'GAME OVER! Final Score: ', '$'
pressAnyKeyMessage: db 'Press Any Key To Exit!', '$'
exitConfirmMsg: db 'Are You Sure You Want To Exit The Game? (Y/N)', '$'
gameName: db 'TRAFFIC RACER', '$'
rollNos: db '24L-0736 & 24L-0824', '$'
ourNames: db 'M.LUQMAN & SAAD QAMAR', '$'
semester: db 'FALL 2025', '$'
newLine: db 13, 10, '$'               ; Newline characters
introMsg: db 'Press Enter To Start!','$'
scoreMessage: db 'Score: ', 0

; Melody: Mario Kart 64 - Raceway Theme
; 0 divisor = Rest. 0 duration = End of Song.
marioMelody:
    dw 3417, 4    ; F4
    dw 2712, 4    ; A4
    dw 2280, 6    ; C5
    dw 2032, 2    ; D5
    dw 2280, 4    ; C5
    dw 2560, 4    ; Bb4
    dw 2712, 4    ; A4
    dw 3044, 8    ; G4
    dw 3417, 4    ; F4
    dw 3044, 4    ; G4
    dw 2712, 8    ; A4
    dw 2280, 8    ; C5
    dw 3417, 4    ; F4
    dw 2712, 4    ; A4
    dw 2280, 6    ; C5
    dw 2032, 2    ; D5
    dw 2280, 4    ; C5
    dw 2560, 4    ; Bb4
    dw 2712, 4    ; A4
    dw 3044, 8    ; G4
    dw 3417, 4    ; F4
    dw 3620, 4    ; E4
    dw 3417, 12   ; F4
    dw 0, 4       ; Rest
    dw 2280, 4    ; C5
    dw 2032, 4    ; D5
    dw 2280, 4    ; C5
    dw 2560, 4    ; Bb4
    dw 2712, 4    ; A4
    dw 3044, 4    ; G4
    dw 2712, 4    ; A4
    dw 2560, 4    ; Bb4
    dw 2280, 8    ; C5
    dw 2712, 4    ; A4
    dw 3417, 4    ; F4
    dw 3044, 12   ; G4
    dw 3417, 4    ; F4
    dw 3044, 4    ; G4
    dw 2712, 4    ; A4
    dw 2560, 4    ; Bb4
    dw 2280, 8    ; C5
    dw 3417, 4    ; F4
    dw 2712, 4    ; A4
    dw 2280, 16   ; C5
    dw 0, 8       ; Rest
    dw 0, 0       ; Loop

; ==============================================================
; === SUBROUTINES & FUNCTIONS ===
; ==============================================================

printStringBios:
    push bp                           ; Save base pointer
    mov bp,sp                         ; Set stack frame
    push ax                           ; Save registers
    push bx
    push cx
    push si
    push di
    push es
    mov ah, 0x02                      ; BIOS set cursor function
    mov bh, 0                         ; Page 0
    int 0x10                          ; Call BIOS
    mov ax, 0xB800                    ; Video memory segment
    mov es, ax                        ; Set ES to video memory
    mov al, 80                        ; Columns per row
    mul dh                            ; Calculate row offset
    add al, dl                        ; Add column offset
    adc ah, 0                         ; Handle carry
    shl ax, 1                         ; Multiply by 2 (byte offset)
    mov di, ax                        ; Set destination index
    mov bl, [bp+4]                    ; Get color attribute from stack
iterateStringChars:
    lodsb                             ; Load char from string
    cmp al, '$'                       ; Check for terminator
    je printStringEnd                 ; If end, jump to return
    mov [es:di], al                   ; Write char to screen
    mov [es:di+1], bl                 ; Write attribute to screen
    add di, 2                         ; Move to next cell
    jmp iterateStringChars            ; Loop
printStringEnd:
    pop es                            ; Restore registers
    pop di
    pop si
    pop cx
    pop bx
    pop ax
    pop bp                            ; Restore base pointer
    ret 2                             ; Return and clean stack

clearScreenGreen:
    push es                           ; Save registers
    push ax
    push cx
    push di
    mov ax, 0xb800                    ; Video memory segment
    mov es, ax                        ; Set ES
    mov di, 0                         ; Start at offset 0
    mov ax, 0x2020                    ; Green space char
    mov cx, 2000                      ; Full screen count
    cld                               ; Clear direction flag
    rep stosw                         ; Fill screen
    pop di                            ; Restore registers
    pop cx
    pop ax
    pop es
    ret
    
clearScreenRed:
    push es                           ; Save registers
    push ax
    push cx
    push di
    mov ax, 0xb800                    ; Video memory segment
    mov es, ax                        ; Set ES
    mov di, 0                         ; Start at offset 0
    mov ax, 0x4020                    ; Red space char
    mov cx, 2000                      ; Full screen count
    cld                               ; Clear direction flag
    rep stosw                         ; Fill screen
    pop di                            ; Restore registers
    pop cx
    pop ax
    pop es
    ret

drawRoad:
    push es                           ; Save registers
    push ax
    push cx
    push di
    mov ax, 0xb800                    ; Video memory segment
    mov es, ax                        ; Set ES
    mov di, 40                        ; Start at column 20
    mov ax, 0x0020                    ; Black space char
    mov cx, 25                        ; 25 rows
iterateRoadRows:
    push cx                           ; Save row counter
    push di                           ; Save row start
    mov cx, 40                        ; 40 columns wide
    rep stosw                         ; Draw row
    pop di                            ; Restore row start
    pop cx                            ; Restore row counter
    add di, 160                       ; Move to next line
    loop iterateRoadRows              ; Loop for all rows
    pop di                            ; Restore registers
    pop cx
    pop ax
    pop es
    ret

drawSideStripes:
    push es                           ; Save registers
    push ax
    push cx
    push di
    mov ax, 0xb800                    ; Video memory segment
    mov es, ax                        ; Set ES
    mov di, 40                        ; Left stripe position
    mov ax, 0x607C                    ; Brown bar char
    mov cx, 25                        ; 25 rows
renderLeftStripe:
    push cx                           ; Save counters
    push di
    mov cx, 1                         ; Width 1
    rep stosw                         ; Draw stripe
    pop di                            ; Restore counters
    pop cx
    add di, 160                       ; Next row
    loop renderLeftStripe             ; Loop
    mov di, 118                       ; Right stripe position
    mov cx, 25                        ; 25 rows
renderRightStripe:
    push cx                           ; Save counters
    push di
    mov cx, 1                         ; Width 1
    rep stosw                         ; Draw stripe
    pop di                            ; Restore counters
    pop cx
    add di, 160                       ; Next row
    loop renderRightStripe            ; Loop
    pop di                            ; Restore registers
    pop cx
    pop ax
    pop es
    ret

drawLaneDividers:
    push es                           ; Save registers
    push ax
    push cx
    push di
    mov ax, 0xb800                    ; Video memory segment
    mov es, ax                        ; Set ES
    mov di, 66                        ; Left divider position
    mov ax, 0x707C                    ; White bar char
    mov cx, 13                        ; 13 segments
renderLeftDivider:
    push cx                           ; Save counters
    push di
    mov cx, 1                         ; Width 1
    rep stosw                         ; Draw divider
    pop di                            ; Restore counters
    pop cx
    add di, 320                       ; Skip row for dashed effect
    loop renderLeftDivider            ; Loop
    mov di, 92                        ; Right divider position
    mov cx, 13                        ; 13 segments
renderRightDivider:
    push cx                           ; Save counters
    push di
    mov cx, 1                         ; Width 1
    rep stosw                         ; Draw divider
    pop di                            ; Restore counters
    pop cx
    add di, 320                       ; Skip row
    loop renderRightDivider           ; Loop
    pop di                            ; Restore registers
    pop cx
    pop ax
    pop es
    ret

drawPlayerCarMiddle:
    push es                           ; Save registers
    push ax
    push cx
    push di
    push cx
    mov ax, 0xb800                    ; Video memory segment
    mov es, ax                        ; Set ES
    mov di, 3112                      ; Middle lane position
    mov ax, 0x3020                    ; Cyan body color
    mov cx, 5                         ; 5 rows high
renderMiddleCarBody:
    push cx                           ; Save counters
    push di
    mov cx, 8                         ; 8 cols wide
    rep stosw                         ; Draw body
    pop di                            ; Restore counters
    pop cx
    add di, 160                       ; Next row
    loop renderMiddleCarBody          ; Loop
    mov di, 3116                      ; Interior position
    mov ax, 0x1020                    ; Blue interior color
    mov cx, 5                         ; 5 rows high
renderMiddleInteriorLeft:
    push cx                           ; Save counters
    push di
    mov cx, 1                         ; Width 1
    rep stosw                         ; Draw interior
    pop di                            ; Restore counters
    pop cx
    add di, 160                       ; Next row
    loop renderMiddleInteriorLeft     ; Loop
    mov di, 3122                      ; Right interior position
    mov ax, 0x1020                    ; Blue interior color
    mov cx, 5                         ; 5 rows high
renderMiddleInteriorRight:
    push cx                           ; Save counters
    push di
    mov cx, 1                         ; Width 1
    rep stosw                         ; Draw interior
    pop di                            ; Restore counters
    pop cx
    add di, 160                       ; Next row
    loop renderMiddleInteriorRight    ; Loop
    mov di, 3270                      ; Left wheel position
    mov ax, 0x507C                    ; Magenta wheel color
    mov cx, 2                         ; 2 wheels
renderMiddleWheelsLeft:
    push cx                           ; Save counters
    push di
    mov cx, 1                         ; Width 1
    rep stosw                         ; Draw wheel
    pop di                            ; Restore counters
    pop cx
    add di, 320                       ; Skip rows
    loop renderMiddleWheelsLeft       ; Loop
    mov di, 3288                      ; Right wheel position
    mov ax, 0x507C                    ; Magenta wheel color
    mov cx, 2                         ; 2 wheels
renderMiddleWheelsRight:
    push cx                           ; Save counters
    push di
    mov cx, 1                         ; Width 1
    rep stosw                         ; Draw wheel
    pop di                            ; Restore counters
    pop cx
    add di, 320                       ; Skip rows
    loop renderMiddleWheelsRight      ; Loop
    pop cx                            ; Restore registers
    pop di
    pop cx
    pop ax
    pop es
    ret

drawPlayerCarLeft:
    push es                           ; Save registers
    push ax
    push cx
    push di
    push cx
    mov ax, 0xb800                    ; Video memory segment
    mov es, ax                        ; Set ES
    mov di, 3086                      ; Left lane position
    mov ax, 0x3020                    ; Cyan body color
    mov cx, 5                         ; 5 rows high
renderLeftCarBody:
    push cx                           ; Save counters
    push di
    mov cx, 8                         ; 8 cols wide
    rep stosw                         ; Draw body
    pop di                            ; Restore counters
    pop cx
    add di, 160                       ; Next row
    loop renderLeftCarBody            ; Loop
    mov di, 3090                      ; Interior position
    mov ax, 0x1020                    ; Blue interior color
    mov cx, 5                         ; 5 rows high
renderLeftInteriorLeft:
    push cx                           ; Save counters
    push di
    mov cx, 1                         ; Width 1
    rep stosw                         ; Draw interior
    pop di                            ; Restore counters
    pop cx
    add di, 160                       ; Next row
    loop renderLeftInteriorLeft       ; Loop
    mov di, 3096                      ; Right interior position
    mov ax, 0x1020                    ; Blue interior color
    mov cx, 5                         ; 5 rows high
renderLeftInteriorRight:
    push cx                           ; Save counters
    push di
    mov cx, 1                         ; Width 1
    rep stosw                         ; Draw interior
    pop di                            ; Restore counters
    pop cx
    add di, 160                       ; Next row
    loop renderLeftInteriorRight      ; Loop
    mov di, 3244                      ; Left wheel position
    mov ax, 0x507C                    ; Magenta wheel color
    mov cx, 2                         ; 2 wheels
renderLeftWheelsLeft:
    push cx                           ; Save counters
    push di
    mov cx, 1                         ; Width 1
    rep stosw                         ; Draw wheel
    pop di                            ; Restore counters
    pop cx
    add di, 320                       ; Skip rows
    loop renderLeftWheelsLeft         ; Loop
    mov di, 3262                      ; Right wheel position
    mov ax, 0x507C                    ; Magenta wheel color
    mov cx, 2                         ; 2 wheels
renderLeftWheelsRight:
    push cx                           ; Save counters
    push di
    mov cx, 1                         ; Width 1
    rep stosw                         ; Draw wheel
    pop di                            ; Restore counters
    pop cx
    add di, 320                       ; Skip rows
    loop renderLeftWheelsRight        ; Loop
    pop cx                            ; Restore registers
    pop di
    pop cx
    pop ax
    pop es
    ret
    
drawPlayerCarRight:
    push es                           ; Save registers
    push ax
    push cx
    push di
    push cx
    mov ax, 0xb800                    ; Video memory segment
    mov es, ax                        ; Set ES
    mov di, 3138                      ; Right lane position
    mov ax, 0x3020                    ; Cyan body color
    mov cx, 5                         ; 5 rows high
renderRightCarBody:
    push cx                           ; Save counters
    push di
    mov cx, 8                         ; 8 cols wide
    rep stosw                         ; Draw body
    pop di                            ; Restore counters
    pop cx
    add di, 160                       ; Next row
    loop renderRightCarBody           ; Loop
    mov di, 3142                      ; Interior position
    mov ax, 0x1020                    ; Blue interior color
    mov cx, 5                         ; 5 rows high
renderRightInteriorLeft:
    push cx                           ; Save counters
    push di
    mov cx, 1                         ; Width 1
    rep stosw                         ; Draw interior
    pop di                            ; Restore counters
    pop cx
    add di, 160                       ; Next row
    loop renderRightInteriorLeft      ; Loop
    mov di, 3148                      ; Right interior position
    mov ax, 0x1020                    ; Blue interior color
    mov cx, 5                         ; 5 rows high
renderRightInteriorRight:
    push cx                           ; Save counters
    push di
    mov cx, 1                         ; Width 1
    rep stosw                         ; Draw interior
    pop di                            ; Restore counters
    pop cx
    add di, 160                       ; Next row
    loop renderRightInteriorRight     ; Loop
    mov di, 3296                      ; Left wheel position
    mov ax, 0x507C                    ; Magenta wheel color
    mov cx, 2                         ; 2 wheels
renderRightWheelsLeft:
    push cx                           ; Save counters
    push di
    mov cx, 1                         ; Width 1
    rep stosw                         ; Draw wheel
    pop di                            ; Restore counters
    pop cx
    add di, 320                       ; Skip rows
    loop renderRightWheelsLeft        ; Loop
    mov di, 3314                      ; Right wheel position
    mov ax, 0x507C                    ; Magenta wheel color
    mov cx, 2                         ; 2 wheels
renderRightWheelsRight:
    push cx                           ; Save counters
    push di
    mov cx, 1                         ; Width 1
    rep stosw                         ; Draw wheel
    pop di                            ; Restore counters
    pop cx
    add di, 320                       ; Skip rows
    loop renderRightWheelsRight       ; Loop
    pop cx                            ; Restore registers
    pop di
    pop cx
    pop ax
    pop es
    ret

erasePlayerCarMiddle:
    push es                           ; Save registers
    push ax
    push cx
    push di
    push cx
    mov ax, 0xb800                    ; Video memory segment
    mov es, ax                        ; Set ES
    mov di, 3110                      ; Car position
    mov ax, 0x0020                    ; Black space char
    mov cx, 5                         ; 5 rows
clearCarMiddleLoop:
    push cx                           ; Save counters
    push di
    mov cx, 10                        ; Clear 10 cols
    rep stosw                         ; Erase
    pop di                            ; Restore counters
    pop cx
    add di, 160                       ; Next row
    loop clearCarMiddleLoop           ; Loop
    pop cx                            ; Restore registers
    pop di
    pop cx
    pop ax
    pop es
    ret

erasePlayerCarLeft:
    push es                           ; Save registers
    push ax
    push cx
    push di
    push cx
    mov ax, 0xb800                    ; Video memory segment
    mov es, ax                        ; Set ES
    mov di, 3084                      ; Car position
    mov ax, 0x0020                    ; Black space char
    mov cx, 5                         ; 5 rows
clearCarLeftLoop:
    push cx                           ; Save counters
    push di
    mov cx, 10                        ; Clear 10 cols
    rep stosw                         ; Erase
    pop di                            ; Restore counters
    pop cx
    add di, 160                       ; Next row
    loop clearCarLeftLoop             ; Loop
    pop cx                            ; Restore registers
    pop di
    pop cx
    pop ax
    pop es
    ret    

erasePlayerCarRight:
    push es                           ; Save registers
    push ax
    push cx
    push di
    push cx
    mov ax, 0xb800                    ; Video memory segment
    mov es, ax                        ; Set ES
    mov di, 3136                      ; Car position
    mov ax, 0x0020                    ; Black space char
    mov cx, 5                         ; 5 rows
clearCarRightLoop:
    push cx                           ; Save counters
    push di
    mov cx, 10                        ; Clear 10 cols
    rep stosw                         ; Erase
    pop di                            ; Restore counters
    pop cx
    add di, 160                       ; Next row
    loop clearCarRightLoop            ; Loop
    pop cx                            ; Restore registers
    pop di
    pop cx
    pop ax
    pop es
    ret

saveScreenBuffer:
    pusha                             ; Save all registers
    push ds
	mov cx, 4000                      ; Screen size in bytes
    mov ax, 0xb800                    ; Video memory segment
    mov ds, ax                        ; DS = Video
    push cs                           ; CS -> ES
    pop es                            ; ES = Data
    mov si, 0                         ; Source offset
    mov di, screenBuffer              ; Dest buffer
    cld                               ; Clear direction
    rep movsb                         ; Copy bytes
    pop ds
	popa                              ; Restore all registers
    ret

restoreScreenBuffer:
    pusha                             ; Save all registers
    push ds
	push es
	mov cx, 4000                      ; Screen size in bytes
    mov ax, 0xb800                    ; Video memory segment
    mov es, ax                        ; ES = Video
    push cs                           ; CS -> DS
    pop ds                            ; DS = Data
    mov si, screenBuffer              ; Source buffer
    mov di, 0                         ; Dest offset
    cld                               ; Clear direction
    rep movsb                         ; Copy bytes
    pop es
	pop ds
	popa                              ; Restore all registers
    ret

scrollScreenDown:
    push bp                           ; Save base pointer
    mov  bp, sp                       ; Set stack frame
    push ax                           ; Save registers
    push bx
    push cx
    push dx
    push si
    push di
    push ds
    push es

    mov  al, [bp+4]                   ; Get lines to scroll
    xor  ah, ah                       ; Clear high byte
    mov  bl, 80                       ; Cols per line
    mul  bl                           ; AX = lines * 80
    mov  bx, ax                       ; BX = chars to scroll

    mov  cx, 2000                     ; Total screen chars
    sub  cx, bx                       ; Subtract scroll amount
    cmp  cx, 0                        ; Check if zero
    je   fillScrolledGap              ; If full scroll, skip

    mov  ax, 0B800h                   ; Video segment
    mov  ds, ax                       ; Source = Video
    mov  es, ax                       ; Dest = Video

    mov  dx, cx                       ; Save count
    dec  dx                           ; Adjust index
    mov  si, dx
    shl  si, 1                        ; Byte offset for source
    
    mov  di, 1999                     ; End of screen
    shl  di, 1                        ; Byte offset for dest
    
    std                               ; Reverse direction
    rep  movsw                        ; Move memory
    cld                               ; Clear direction

fillScrolledGap:
    push ds                           ; Save segments
    push es
    
    mov ax, cs                        ; DS = Data
    mov ds, ax 
    mov ax, 0xb800                    ; ES = Video
    mov es, ax 
    
    mov si, roadTemplate              ; Source template
    mov di, 0                         ; Dest top of screen
    mov cx, bx                        ; Count words
    cld                               ; Forward direction
    rep movsw                         ; Fill gap
    
    pop ds                            ; Restore segments
    pop es

    pop  es                           ; Restore registers
    pop  ds
    pop  di
    pop  si
    pop  dx
    pop  cx
    pop  bx
    pop  ax
    pop  bp                           ; Restore base pointer
    ret  2                            ; Return

spawnScrollingTrees:
    push ax                           ; Save registers
    push bx
    
    inc word [treeSpawnCounter]       ; Increment counter
    
    mov ax, [treeSpawnCounter]        ; Load counter
    cmp ax, 3                         ; Check threshold
    jl exitTreeSpawn                  ; If less, skip
    
    mov word [treeSpawnCounter], 0    ; Reset counter
    
    mov bl, [treePattern]             ; Load pattern index
    
    cmp bl, 0                         ; Check pattern 0
    jne tryTreePattern1
    mov ax, 1                         ; Draw tree 1
    push ax
    mov ax, 0
    push ax
    call drawTree
    
    mov ax, 14                        ; Draw tree 2
    push ax
    mov ax, 0
    push ax
    call drawTree
    
    mov ax, 61                        ; Draw tree 3
    push ax
    mov ax, 0
    push ax
    call drawTree
    
    mov ax, 74                        ; Draw tree 4
    push ax
    mov ax, 0
    push ax
    call drawTree
    jmp nextTreePattern               ; Next pattern
    
tryTreePattern1:
    cmp bl, 1                         ; Check pattern 1
    jne tryTreePattern2
    mov ax, 7                         ; Draw tree 1
    push ax
    mov ax, 0
    push ax
    call drawTree
    
    mov ax, 68                        ; Draw tree 2
    push ax
    mov ax, 0
    push ax
    call drawTree
    jmp nextTreePattern               ; Next pattern
    
tryTreePattern2:
    cmp bl, 2                         ; Check pattern 2
    jne tryTreePattern3
    mov ax, 7                         ; Draw tree 1
    push ax
    mov ax, 0
    push ax
    call drawTree
    
    mov ax, 68                        ; Draw tree 2
    push ax
    mov ax, 0
    push ax
    call drawTree
    jmp nextTreePattern               ; Next pattern
    
tryTreePattern3:
    cmp bl, 3                         ; Check pattern 3
    jne tryTreePattern4
    mov ax, 1                         ; Draw tree 1
    push ax
    mov ax, 0
    push ax
    call drawTree
    
    mov ax, 14                        ; Draw tree 2
    push ax
    mov ax, 0
    push ax
    call drawTree
    
    mov ax, 61                        ; Draw tree 3
    push ax
    mov ax, 0
    push ax
    call drawTree
    
    mov ax, 74                        ; Draw tree 4
    push ax
    mov ax, 0
    push ax
    call drawTree
    jmp nextTreePattern               ; Next pattern

tryTreePattern4:
    jmp nextTreePattern               ; Empty pattern
    
nextTreePattern:
    inc byte [treePattern]            ; Increment pattern
    mov al, [treePattern]
    cmp al, 6                         ; Check max patterns
    jl exitTreeSpawn
    mov byte [treePattern], 0         ; Reset pattern

exitTreeSpawn:
    pop bx                            ; Restore registers
    pop ax
    ret

updateGameFrame:
    call restoreScreenBuffer          ; Restore background
    mov ax, 2                         ; Scroll 2 lines
    push ax
    call scrollScreenDown             ; Perform scroll
    
    call spawnScrollingTrees          ; Add trees
    
    call spawnObstacleCar             ; Add obstacles
    call spawnBonusStar               ; Add stars
    call saveScreenBuffer             ; Save background
    
checkCollisions: 
    call checkObstacleCollision       ; Check car hits
    call checkBonusCollision          ; Check star hits
    
    mov ax, cs                        ; Set DS
    mov ds, ax
    mov al, [currentPlayerLane]       ; Get lane
    cmp al, 1                         ; Check left
    je renderLeftLaneCar
    cmp al, 2                         ; Check middle
    je renderMiddleLaneCar 
    cmp al, 3                         ; Check right
    je renderRightLaneCar
    jmp finishFrameUpdate             ; Skip
    
renderLeftLaneCar:
    call drawPlayerCarLeft            ; Draw left
    jmp finishFrameUpdate
    
renderMiddleLaneCar:
    call drawPlayerCarMiddle          ; Draw middle
    jmp finishFrameUpdate
    
renderRightLaneCar:
    call drawPlayerCarRight           ; Draw right
    
finishFrameUpdate:
    ret

delayGame:
    push cx                           ; Save CX
    mov cx, 10                        ; Outer count
waitLoopOuter:
    push cx                           ; Save outer CX
    mov cx, 0xFFFF                    ; Inner count
waitLoopInner:
    loop waitLoopInner                ; Busy wait
    pop cx                            ; Restore outer CX
    loop waitLoopOuter                ; Loop outer
    pop cx                            ; Restore CX
    ret

; ==============================================================
; === SOUND FUNCTIONS ===
; ==============================================================

stopSound:
    in   al, speakerPort              ; Read port
    and  al, 0FCh                     ; Clear bits 0-1
    out  speakerPort, al              ; Write back
    ret

setFrequency:
    push ax                           ; Save registers
    push bx
    push dx
    push si
    cmp bx, 0                         ; Check if 0
    je setFreqDone                    ; Exit if 0
    mov ax, 0x3494                    ; Lower divisor bits
    mov dx, 0x0012                    ; Upper divisor bits
    div bx                            ; Divide
    push ax                           ; Save divisor
    mov al, 0B6h                      ; Mode 3
    out pitControl, al                ; Send control
    pop ax                            ; Restore divisor
    out pitChannel2, al               ; Send low byte
    mov al, ah                        ; Move high byte
    out pitChannel2, al               ; Send high byte
    in al, speakerPort                ; Read speaker
    or al, 03h                        ; Enable speaker
    out speakerPort, al               ; Write back
setFreqDone:
    pop si                            ; Restore registers
    pop dx
    pop bx
    pop ax
    ret

playTone:
    call setFrequency                 ; Start sound
    push cx                           ; Save delay
playToneOuter:
    push cx                           ; Save outer
    mov cx, 04000h                    ; Delay amount
playToneInner:
    loop playToneInner                ; Wait
    pop cx                            ; Restore outer
    loop playToneOuter                ; Loop
    pop cx                            ; Restore delay
    call stopSound                    ; Stop sound
    ret

collisionSound:
    push bx                           ; Save registers
    push cx
    mov byte [muteBackground], 1      ; Mute bg music
    mov bx, 1500                      ; High pitch
    mov cx, 1                         ; Short duration
    call playTone                     ; Play
    mov bx, 500                       ; Low pitch
    mov cx, 1                         ; Short duration
    call playTone                     ; Play
    mov cx, 500                       ; Noise duration
noiseLoopOuter:
    in al, speakerPort                ; Read port
    and al, 0FCh                      ; Turn off
    out speakerPort, al               ; Write
    push cx                           ; Save counter
    mov cx, 50                        ; Wait
noiseWait1: loop noiseWait1           ; Loop
    pop cx                            ; Restore
    in al, speakerPort                ; Read port
    or al, 02h                        ; Turn on bit 1
    out speakerPort, al               ; Write
    push cx                           ; Save counter
    mov cx, 50                        ; Wait
noiseWait2: loop noiseWait2           ; Loop
    pop cx                            ; Restore
    loop noiseLoopOuter               ; Main loop
    call stopSound                    ; Stop
    mov byte [muteBackground], 0      ; Unmute
    pop cx                            ; Restore registers
    pop bx
    ret

bonusSound:
    push ax                           ; Save registers
    push bx
    push cx
    mov byte [muteBackground], 1      ; Mute bg music
    mov bx, 800                       ; Note 1
    mov cx, 1                         ; Short
    call playTone                     ; Play
    mov bx, 1000                      ; Note 2
    mov cx, 1                         ; Short
    call playTone                     ; Play
    mov bx, 1200                      ; Note 3
    mov cx, 1                         ; Short
    call playTone                     ; Play
    mov byte [muteBackground], 0      ; Unmute
    pop cx                            ; Restore registers
    pop bx
    pop ax
    ret

updateBackgroundMusic:
    dec word [musicTimer]             ; Decrement tick
    jnz exitMusicUpdate               ; Exit if >0
    
loadNextBgNote:
    mov si, [musicPointer]            ; Load pointer
    mov ax, [si]                      ; Get Divisor
    mov bx, [si+2]                    ; Get Duration
    
    cmp bx, 0                         ; Check end
    jne playNextBgNote                ; If not end, play
    mov word [musicPointer], marioMelody ; Reset loop
    jmp loadNextBgNote                ; Restart now
    
playNextBgNote:
    mov [musicTimer], bx              ; Set new duration
    add word [musicPointer], 4        ; Advance pointer
    
    cmp ax, 0                         ; Check for Rest
    je silenceBgSpeaker               ; Silence
    
    mov dx, ax                        ; Move freq to DX
    mov al, 0B6h                      ; Control Word
    out pitControl, al                ; Send Control
    mov al, dl                        ; Low Byte
    out pitChannel2, al               ; Send Low
    mov al, dh                        ; High Byte
    out pitChannel2, al               ; Send High
    in al, speakerPort                ; Read Speaker
    or al, 3                          ; Turn On
    out speakerPort, al               ; Write
    ret
    
silenceBgSpeaker:
    in al, speakerPort                ; Read Speaker
    and al, 0FCh                      ; Turn Off
    out speakerPort, al               ; Write
exitMusicUpdate:
    ret

; ==============================================================
; === GRAPHICS FUNCTIONS CONTINUED ===
; ==============================================================

drawTree:
    push bp                           ; Save base pointer
    mov  bp, sp                       ; Set stack frame
    push ax                           ; Save registers
    push bx
    push cx
    push dx
    push si
    push di
    push es

    mov ax, 0xb800                    ; Video memory segment
    mov es, ax                        ; Set ES
    mov ax, 0                         ; Clear AX
    mov al, 80                        ; Cols
    mul byte [bp+4]                   ; Calculate Y
    add ax, [bp+6]                    ; Add X
    shl ax, 1                         ; Byte offset
    mov di, ax                        ; Set DI
    
    mov ah, 0x20                      ; Attribute
    mov al, ' '                       ; Char
    mov cx, 2                         ; Count
    cld                               ; Forward
    rep stosw                         ; Draw
    mov ah,0x2F                       ; Top color
    mov al, '^'                       ; Top char
    stosw                             ; Draw
    add cx, 3                         ; Increment
    add di, 156                       ; Next line
    rep stosw                         ; Draw
    add cx, 5                         ; Increment
    add di, 152                       ; Next line
    rep stosw                         ; Draw
    add cx, 1                         ; Increment
    add di, 152                       ; Next line
    mov ah, 0x60                      ; Trunk color
    mov al, 'I'                       ; Trunk char
    rep stosw                         ; Draw
    add cx, 1                         ; Increment
    add di, 2                         ; Offset
    rep stosw                         ; Draw
    add cx, 1                         ; Increment
    add di, 154                       ; Next line
    rep stosw                         ; Draw
    add cx, 1                         ; Increment
    add di, 2                         ; Offset
    rep stosw                         ; Draw

    pop  es                           ; Restore registers
    pop  di
    pop  si
    pop  dx
    pop  cx
    pop  bx
    pop  ax
    pop  bp                           ; Restore base pointer
    ret 4

createRoadTemplateBuffer:
    pusha                             ; Save all registers
    push es                           ; Save ES
    
    mov ax, cs                        ; Set ES to Data
    mov es, ax 
    mov di, roadTemplate              ; Set dest
    
    mov ax, 0x2020                    ; Green char
    mov cx, 160                       ; Fill size
    cld                               ; Forward
    rep stosw                         ; Fill

    mov di, roadTemplate              ; Reset dest
    add di, 40                        ; Offset
    mov ax, 0x0020                    ; Black char
    mov cx, 40                        ; Width
    rep stosw                         ; Draw
    add di, 80                        ; Next line
    mov cx, 40                        ; Width
    rep stosw                         ; Draw

    mov di, roadTemplate              ; Reset dest
    add di, 40                        ; Offset
    mov ax, 0x607C                    ; Stripe char
    stosw                             ; Draw
    add di, 158                       ; Next line
    stosw                             ; Draw
    mov di, roadTemplate              ; Reset dest
    add di, 118                       ; Offset
    stosw                             ; Draw
    add di, 158                       ; Next line
    stosw                             ; Draw

    mov di, roadTemplate              ; Reset dest
    add di, 66                        ; Offset
    mov ax, 0x707C                    ; Divider char
    stosw                             ; Draw
    mov di, roadTemplate              ; Reset dest
    add di, 92                        ; Offset
    stosw                             ; Draw

    pop es                            ; Restore ES
    popa                              ; Restore all
    ret

drawObstacleCar:
    push ax                           ; Save registers
    push cx
    push di
    push si 
    push es
    
    mov ax, 0xb800                    ; Video memory segment
    mov es, ax                        ; Set ES
    
    mov si, di                        ; Save start position
    
    mov ax, 0x4020                    ; Red body
    mov cx, 5                         ; Height
renderObstacleBody:
    push cx                           ; Save counter
    push di                           ; Save position
    mov cx, 8                         ; Width
    rep stosw                         ; Draw
    pop di                            ; Restore position
    pop cx                            ; Restore counter
    add di, 160                       ; Next line
    loop renderObstacleBody           ; Loop
    
    mov di, si                        ; Reset position
    add di, 4                         ; Offset
    mov ax, 0xE020                    ; Yellow stripe
    mov cx, 5                         ; Height
renderObstacleStripeLeft:
    push cx                           ; Save counter
    push di                           ; Save position
    mov cx, 1                         ; Width
    rep stosw                         ; Draw
    pop di                            ; Restore position
    pop cx                            ; Restore counter
    add di, 160                       ; Next line
    loop renderObstacleStripeLeft     ; Loop

    mov di, si                        ; Reset position
    add di, 10                        ; Offset
    mov ax, 0xE020                    ; Yellow stripe
    mov cx, 5                         ; Height
renderObstacleStripeRight:
    push cx                           ; Save counter
    push di                           ; Save position
    mov cx, 1                         ; Width
    rep stosw                         ; Draw
    pop di                            ; Restore position
    pop cx                            ; Restore counter
    add di, 160                       ; Next line
    loop renderObstacleStripeRight    ; Loop

    mov di, si                        ; Reset position
    add di, 158                       ; Offset
    mov ax, 0x107C                    ; Blue wheel
    mov cx, 2                         ; Count
renderObstacleWheelsLeft:
    push cx                           ; Save counter
    push di                           ; Save position
    mov cx, 1                         ; Width
    rep stosw                         ; Draw
    pop di                            ; Restore position
    pop cx                            ; Restore counter
    add di, 320                       ; Skip line
    loop renderObstacleWheelsLeft     ; Loop

    mov di, si                        ; Reset position
    add di, 176                       ; Offset
    mov ax, 0x107C                    ; Blue wheel
    mov cx, 2                         ; Count
renderObstacleWheelsRight:
    push cx                           ; Save counter
    push di                           ; Save position
    mov cx, 1                         ; Width
    rep stosw                         ; Draw
    pop di                            ; Restore position
    pop cx                            ; Restore counter
    add di, 320                       ; Skip line
    loop renderObstacleWheelsRight    ; Loop
    
    pop es                            ; Restore registers
    pop si
    pop di
    pop cx
    pop ax
    ret
    
getThreeLaneRandom:
    push bx                           ; Save registers
    push cx
    push dx
    push ds

    mov ax, cs                        ; Set DS
    mov ds, ax

    mov ax, [randomSeed]              ; Load seed
    
    mov bx, 25173                     ; Multiplier
    mul bx                            ; Multiply
    add ax, 13849                     ; Add constant
    
    mov [randomSeed], ax              ; Save seed
    
    mov cx, 3                         ; Divisor
    xor dx, dx                        ; Clear high word
    div cx                            ; Divide
    
    mov ax, dx                        ; Move remainder to AX
    
    pop ds                            ; Restore registers
    pop dx
    pop cx
    pop bx
    ret

spawnObstacleCar:
    push ax                           ; Save registers
    push bx
    push di
    push es

    dec word [obstacleSpawnTimer]     ; Decrement timer
    jnz exitObstacleSpawn             ; Check if zero

    mov word [obstacleSpawnTimer], 15 ; Reset timer

    call getThreeLaneRandom           ; Get random lane
    
	mov [lastCarLane], ax
	
    mov bx, ax                        ; Move random to BX
    shl bx, 1                         ; Word offset
    mov di, [obstacleLanePositions + bx] ; Get position

    call drawObstacleCar              ; Draw car

exitObstacleSpawn:
    pop es                            ; Restore registers
    pop di
    pop bx
    pop ax
    ret

drawBonusStar:
    push ax                           ; Save registers
    push cx
    push di
    push es
    
    mov ax, 0xb800                    ; Video memory segment
    mov es, ax                        ; Set ES
    
    mov ax, 0x0E2A                    ; Star char
    
    mov [es:di + 4], ax               ; Draw point
    mov [es:di + 6], ax               ; Draw point
    
    add di, 160                       ; Next line
    mov cx, 6                         ; Width
    rep stosw                         ; Draw line
    
    add di, 160                       ; Next line
    sub di, 10                        ; Offset back
    mov [es:di], ax                   ; Draw point
    mov [es:di + 6], ax               ; Draw point
    
    pop es                            ; Restore registers
    pop di
    pop cx
    pop ax
    ret

spawnBonusStar:
    push ax                           ; Save registers
    push bx
    push di
    push es

    dec word [bonusSpawnTimer]        ; Decrement timer
    jnz exitBonusSpawn                ; Check if zero

    mov word [bonusSpawnTimer], 23    ; Reset timer

    call getThreeLaneRandom           ; Get random lane
    
	cmp ax, [lastCarLane]             ; Check if this lane has a car
    jne starLaneOk                    ; If not equal, it's safe
    
    inc ax                            ; If equal, move to next lane
    cmp ax, 3                         ; Check if out of bounds (lane > 2)
    jne starLaneOk
    mov ax, 0                         ; Wrap around to lane 0
	
starLaneOk:	
    mov bx, ax                        ; Move random to BX
    shl bx, 1                         ; Word offset
    mov di, [bonusLanePositions + bx] ; Get position

    call drawBonusStar                ; Draw star

exitBonusSpawn:
    pop es                            ; Restore registers
    pop di
    pop bx
    pop ax
    ret

checkObstacleCollision:
    push ax                           ; Save registers
    push es
    push di
    push ds
    push si

    mov ax, 0xb800                    ; Video memory segment
    mov es, ax                        ; Set ES
    mov ax, cs                        ; Set DS
    mov ds, ax
    
    cmp byte [gameActive], 0          ; Check active flag
    je exitCollisionCheck             ; If over, skip
    
    cmp byte [currentPlayerLane], 1   ; Check lane 1
    je setLeftCollisionPoints
    cmp byte [currentPlayerLane], 3   ; Check lane 3
    je setRightCollisionPoints
    
    mov di, 2962                      ; Mid lane front
    mov si, 3922                      ; Mid lane rear
    jmp verifyCollisionPoints
    
setLeftCollisionPoints:
    mov di, 2936                      ; Left lane front
    mov si, 3896                      ; Left lane rear
    jmp verifyCollisionPoints
    
setRightCollisionPoints:
    mov di, 2988                      ; Right lane front
    mov si, 3948                      ; Right lane rear

verifyCollisionPoints:
    mov ax, 0xE020                    ; Obstacle color
    cmp [es:di], ax                   ; Check front
    je triggerGameOver
    cmp [es:si], ax                   ; Check rear
    je triggerGameOver
    jmp exitCollisionCheck

triggerGameOver:
    mov byte [gameActive], 0          ; Set game over
    call collisionSound               ; Play sound
    
exitCollisionCheck:
    pop si                            ; Restore registers
    pop ds
    pop di
    pop es
    pop ax
    ret

checkLaneForBonusStar:
    push ds                           ; Save DS
    push cx                           ; Save CX
    mov di, bx                        ; Set check pos
    mov ax, 0x0E2A                    ; Star char
    
    cmp [es:di], ax                   ; Check pos 1
    je bonusStarFound
    
    add di, 320                       ; Offset
    cmp [es:di], ax                   ; Check pos 2
    je bonusStarFound

    add di, 320                       ; Offset
    cmp [es:di], ax                   ; Check pos 3
    je bonusStarFound

    pop cx                            ; Restore CX
    pop ds                            ; Restore DS
    ret

bonusStarFound:
    pop cx                            ; Restore CX
    push es                           ; Save registers
    push ax
    push bx
    push di
    push cx
    mov ax, cs                        ; Set DS
    mov ds, ax
    add word [playerScore], 10        ; Increment score
    call bonusSound                   ; Play sound
    
    cmp cx, 1                         ; Check lane 1
    je eraseLane1Star
    cmp cx, 2                         ; Check lane 2
    je eraseLane2Star
    mov di, 2820                      ; Lane 3 pos
    jmp calculateVideoEraseOffset
eraseLane1Star:
    mov di, 2768                      ; Lane 1 pos
    jmp calculateVideoEraseOffset
eraseLane2Star:
    mov di, 2794                      ; Lane 2 pos
calculateVideoEraseOffset: 
    mov ax, 0xb800                    ; Video memory
    mov es, ax                        ; Set ES
    mov ax, 0x0020                    ; Black char
    mov cx, 8                         ; Height
clearStarFromVideo:
    dec cx                            ; Decrement
    push cx                           ; Save count
    push di                           ; Save pos
    mov cx, 6                         ; Width
    rep stosw                         ; Clear
    pop di                            ; Restore pos
    add di, 160                       ; Next line
    pop cx                            ; Restore count
    cmp cx, 0                         ; Check zero
    jne clearStarFromVideo            ; Loop

    mov ax, cs                        ; Set ES to data
    mov es, ax
    pop cx                            ; Restore lane
    push cx                           ; Save lane
    
    cmp cx, 1                         ; Check lane 1
    je eraseLane1StarBuffer
    cmp cx, 2                         ; Check lane 2
    je eraseLane2StarBuffer
    mov di, 2820                      ; Lane 3 pos
    jmp calculateBufferEraseOffset
eraseLane1StarBuffer:
    mov di, 2768                      ; Lane 1 pos
    jmp calculateBufferEraseOffset
eraseLane2StarBuffer:
    mov di, 2794                      ; Lane 2 pos
calculateBufferEraseOffset:
    add di, screenBuffer              ; Buffer offset
    mov ax, 0x0020                    ; Black char
    mov cx, 8                         ; Height
clearStarFromBuffer:
    dec cx                            ; Decrement
    push cx                           ; Save count
    push di                           ; Save pos
    mov cx, 6                         ; Width
    rep stosw                         ; Clear
    pop di                            ; Restore pos
    add di, 160                       ; Next line
    pop cx                            ; Restore count
    cmp cx, 0                         ; Check zero
    jne clearStarFromBuffer           ; Loop

    pop cx                            ; Restore all
    pop di
    pop bx
    pop ax
    pop es
    pop ds
    ret

checkBonusCollision:
    push ax                           ; Save registers
    push es
    push bx
    push di
    push cx
    push ds

    mov ax, 0xb800                    ; Video memory
    mov es, ax                        ; Set ES
    mov ax, cs                        ; Data memory
    mov ds, ax

    cmp byte [currentPlayerLane], 1   ; Check lane 1
    jne checkLane2Bonus
    mov bx, 3094                      ; Pos
    mov cx, 1                         ; Lane
    call checkLaneForBonusStar
    jmp finishBonusCheck

checkLane2Bonus:
    cmp byte [currentPlayerLane], 2   ; Check lane 2
    jne checkLane3Bonus
    mov bx, 3120                      ; Pos
    mov cx, 2                         ; Lane
    call checkLaneForBonusStar
    jmp finishBonusCheck

checkLane3Bonus:
    mov bx, 3146                      ; Pos
    mov cx, 3                         ; Lane
    call checkLaneForBonusStar

finishBonusCheck:
    pop ds                            ; Restore registers
    pop cx
    pop di
    pop bx
    pop es
    pop ax
    ret

displayNumber:
    push bp                           ; Save base
    mov bp, sp                        ; Set stack
    push es                           ; Save registers
    push ax
    push bx
    push cx
    push dx
    push di
    mov ax, 0xb800                    ; Video memory
    mov es, ax                        ; Set ES
    mov ax, [bp+4]                    ; Get number
    mov bx, 10                        ; Divisor
    mov cx, 0                         ; Counter
extractDigitsLoop:
    mov dx, 0                         ; Clear high word
    div bx                            ; Divide
    add dl, 0x30                      ; Convert to char
    push dx                           ; Save digit
    inc cx                            ; Increment count
    cmp ax, 0                         ; Check zero
    jnz extractDigitsLoop             ; Loop
    
    mov ax, 0                         ; Clear AX
    mov al, 80                        ; Cols
    mul byte [bp+8]                   ; Y pos
    add ax, [bp+10]                   ; X pos
    shl ax, 1                         ; Byte offset
    mov di, ax                        ; Set DI
    
renderDigitsLoop:
    pop dx                            ; Get digit
    mov bx, [bp+6]                    ; Color
    mov dh, bl                        ; Set attr
    mov [es:di], dx                   ; Draw
    add di, 2                         ; Next cell
    loop renderDigitsLoop             ; Loop
    
    pop di                            ; Restore registers
    pop dx
    pop cx
    pop bx
    pop ax
    pop es
    pop bp                            ; Restore base
    ret 8                             ; Return

displayString:
    push bp                           ; Save base
    mov bp, sp                        ; Set stack
    push es                           ; Save registers
    push ax
    push cx
    push si
    push di
    push ds
    pop es                            ; Set ES
    mov di, [bp+4]                    ; Get string
    mov cx, 0xffff                    ; Max length
    xor al, al                        ; Clear AL
    repne scasb                       ; Scan string
    mov ax, 0xffff                    ; Max length
    sub ax, cx                        ; Calc length
    dec ax                            ; Adjust
    jz exitStringDisplay              ; Exit if empty
    mov cx, ax                        ; Set count
    mov ax, 0xb800                    ; Video memory
    mov es, ax                        ; Set ES
    mov al, 80                        ; Cols
    mul byte [bp+8]                   ; Y pos
    add ax, [bp+10]                   ; X pos
    shl ax, 1                         ; Byte offset
    mov di, ax                        ; Set DI
    mov si, [bp+4]                    ; Get string
    mov ah, [bp+6]                    ; Get color
    cld                               ; Forward
renderStringChars:
    lodsb                             ; Load char
    stosw                             ; Draw char
    loop renderStringChars            ; Loop
exitStringDisplay:
    pop di                            ; Restore registers
    pop si
    pop cx
    pop ax
    pop es
    pop bp                            ; Restore base
    ret 8                             ; Return
    
keyboardInterruptHandler: 
    push ax                           ; Save registers
    push es
    push bx
    push di
    push cx
    push ds

    mov ax, cs                        ; Set DS
    mov ds, ax
    cmp byte [gameActive], 0          ; Check active
    je finishKeyboardInterrupt        ; Exit if over
    
    mov ax, 0xb800                    ; Video memory
    mov es, ax                        ; Set ES
    in al, 0x60                       ; Read port
    
    cmp al, 0x01                      ; Check ESC
    jne verifyEnterKey
    mov byte [exitRequested], 1       ; Set flag
    jmp finishKeyboardInterrupt
    
verifyEnterKey:
    cmp al,1Ch                        ; Check Enter
    jne verifyLeftInput
    mov byte[enterPressed],1          ; Set flag

verifyLeftInput:
cmp byte[enterPressed],1              ; Check flag
jne finishKeyboardInterrupt
    cmp al, 0x4B                      ; Check Left
    jne verifyRightInput

    cmp byte [currentPlayerLane], 2   ; Check Mid
    je moveFromMiddleToLeft
    cmp byte [currentPlayerLane], 1   ; Check Left
    je finishKeyboardInterrupt

    mov bx, 3120                      ; Check star
    mov cx, 2
    call checkLaneForBonusStar
    call erasePlayerCarRight          ; Erase
    call drawPlayerCarMiddle          ; Draw
    mov byte [currentPlayerLane], 2   ; Update lane
    jmp finishKeyboardInterrupt

moveFromMiddleToLeft:
    mov bx, 3094                      ; Check star
    mov cx, 1
    call checkLaneForBonusStar
    call erasePlayerCarMiddle         ; Erase
    call drawPlayerCarLeft            ; Draw
    mov byte [currentPlayerLane], 1   ; Update lane
    jmp finishKeyboardInterrupt

verifyRightInput:
cmp byte[enterPressed],1              ; Check flag
jne finishKeyboardInterrupt 
    cmp al, 0x4D                      ; Check Right
    jne finishKeyboardInterrupt

    cmp byte [currentPlayerLane], 2   ; Check Mid
    je moveFromMiddleToRight
    cmp byte [currentPlayerLane], 3   ; Check Right
    je finishKeyboardInterrupt

    mov bx, 3120                      ; Check star
    mov cx, 2
    call checkLaneForBonusStar
    call erasePlayerCarLeft           ; Erase
    call drawPlayerCarMiddle          ; Draw
    mov byte [currentPlayerLane], 2   ; Update lane
    jmp finishKeyboardInterrupt

moveFromMiddleToRight:
    mov bx, 3146                      ; Check star
    mov cx, 3
    call checkLaneForBonusStar
    call erasePlayerCarMiddle         ; Erase
    call drawPlayerCarRight           ; Draw
    mov byte [currentPlayerLane], 3   ; Update lane

finishKeyboardInterrupt:
    mov al, 0x20                      ; EOI command
    out 0x20, al                      ; Send EOI
    pop ds                            ; Restore registers
    pop cx
    pop di
    pop bx
    pop es
    pop ax
    iret                              ; Return

installGameKbisr:
    pusha                             ; Save registers
    push es
    xor ax, ax                        ; Clear AX
    mov es, ax                        ; Set ES to 0
    mov ax, [es:9*4]                  ; Save offset
    mov [oldKbisr], ax
    mov ax, [es:9*4+2]                ; Save segment
    mov [oldKbisr+2], ax
    
    cli                               ; Disable ints
    mov word [es:9*4], keyboardInterruptHandler ; Set offset
    mov [es:9*4+2], cs                ; Set segment
    sti                               ; Enable ints
    pop es                            ; Restore
    popa
    ret

restoreOriginalKbisr:
    pusha                             ; Save registers
    push es
    xor ax, ax                        ; Clear AX
    mov es, ax                        ; Set ES to 0
    cli                               ; Disable ints
    mov ax, [oldKbisr]                ; Restore offset
    mov [es:9*4], ax
    mov ax, [oldKbisr+2]              ; Restore segment
    mov [es:9*4+2], ax
    sti                               ; Enable ints
    pop es                            ; Restore
    popa
    ret

displayGameOverScreen:
    pusha                             ; Save registers
    push es
    
    mov ax, 0xb800                    ; Video memory
    mov es, ax                        ; Set ES
    mov di, 0                         ; Reset DI
    mov ax, 0x4020                    ; Red char
    mov cx, 2000                      ; Count
    cld                               ; Forward
    rep stosw                         ; Fill
    
    mov di, 1494                      ; Position
    mov ax, 0x0720                    ; Grey char
    mov cx, 6                         ; Rows
    cld                               ; Forward
drawGameOverStripesLoop:
    dec cx                            ; Decrement
    push cx                           ; Save count
    mov cx, 31                        ; Width
    rep stosw                         ; Draw
    add di,98                         ; Next line
    pop cx                            ; Restore count
    cmp cx,0                          ; Check zero
    jne drawGameOverStripesLoop       ; Loop
    
    mov si, gameOverMessage           ; String
    mov dh, 10                        ; Y pos
    mov dl, 28                        ; X pos
push 0x0F                             ; Color
    call printStringBios              ; Print
    
    mov ah, 01h                       ; Cursor shape
mov ch, 32                            ; Hide
mov cl, 0                             ; End line
int 10h                               ; Call BIOS
    
    mov ax, 52                        ; X pos
    push ax
    mov ax, 10                        ; Y pos
    push ax
    mov ax, 0x0F                      ; Color
    push ax
    push word [playerScore]           ; Score
    call displayNumber                ; Print
    
    mov si, pressAnyKeyMessage        ; String
    mov dh, 13                        ; Y pos
    mov dl, 32                        ; X pos
    push 0x8E                         ; Color
    call printStringBios              ; Print
    
    mov ah, 01h                       ; Cursor shape
    mov ch, 32                        ; Hide
    mov cl, 0
    int 10h 
    
    pop es                            ; Restore
    popa
    ret

displayExitMessageBox:
    pusha                             ; Save registers
    push es
    mov ax, 0xb800                    ; Video memory
    mov es, ax                        ; Set ES
    
    mov di, 1636                      ; Position
    mov ax, 0x1F20                    ; Blue char
    mov cx, 45                        ; Width
    rep stosw                         ; Draw
    
    add di, 70                        ; Next line
    mov cx, 45                        ; Width
    rep stosw                         ; Draw
    
    add di, 70                        ; Next line
    mov cx, 45                        ; Width
    rep stosw                         ; Draw
    
    mov si, exitConfirmMsg            ; String
    mov dh, 11                        ; Y pos
    mov dl, 18                        ; X pos
    push 0x1F                         ; Color
    call printStringBios              ; Print
    
    mov ah, 01h                       ; Cursor shape
mov ch, 32                            ; Hide
mov cl, 0
int 10h                               ; Call BIOS
    
    pop es                            ; Restore
    popa
    ret
    
customTimerHandler: 
    pusha                             ; Save registers

    mov ax, cs                        ; Set DS
    mov ds, ax

    cmp byte [gameActive], 0          ; Check active
    je finishTimerInterrupt           ; If over, exit

    ; --- MUSIC UPDATE (Run every tick = 18.2 Hz for speed) ---
    cmp byte [muteBackground], 1      ; Check mute
    je skipMusicUpdate                ; Skip if muted
    call updateBackgroundMusic        ; Update music
skipMusicUpdate:

    ; --- GAME UPDATE (Run every 3rd tick to slow down graphics) ---
    inc word [cs:tickCount]           ; Increment tick
    cmp word[cs:tickCount], 3         ; Check threshold (was 6)
    jne finishTimerInterrupt          ; If not threshold, exit
    mov word [cs:tickCount], 0        ; Reset tick

    call updateGameFrame              ; Update game
    call drawScoreUi                  ; Draw score

finishTimerInterrupt:
    mov al, 0x20                      ; EOI command
    out 0x20, al                      ; Send EOI
    popa                              ; Restore registers
    iret                              ; Return

restoreOriginalTimer:
    pusha                             ; Save registers
    push es
    xor ax, ax                        ; Clear AX
    mov es, ax                        ; Set ES to 0
    cli                               ; Disable ints
    mov ax, [oldTimer]                ; Restore offset
    mov [es:8*4], ax
    mov ax, [oldTimer+2]              ; Restore segment
    mov [es:8*4+2], ax
    sti                               ; Enable ints
    pop es                            ; Restore
    popa
    ret
    
drawScoreUi:
    push ax                           ; Save registers
    
    mov ax, 63                        ; X pos
    push ax 
    mov ax, 0                         ; Y pos
    push ax 
    mov ax, 0x2E                      ; Color
    push ax 
    mov ax, scoreMessage              ; String
    push ax 
    call displayString                ; Print
    
    mov ax, 70                        ; X pos
    push ax
    mov ax, 0                         ; Y pos
    push ax
    mov ax, 0x2E                      ; Color
    push ax
    push word [playerScore]           ; Score
    call displayNumber                ; Print
    
    pop ax                            ; Restore
    ret

; ==============================================================
; === MAIN GAME LOGIC ===
; ==============================================================

gameStart:
    mov byte [cs:gameActive], 1          ; Set active
    mov word [cs:playerScore], 0         ; Reset score
    
    call clearScreenRed               ; Clear screen
    
    mov ax,0xB800                     ; Video memory
    mov es,ax                         ; Set ES
    mov di, 850                       ; Position
    mov ax, 0x0720                    ; Grey char
    mov cx, 15                        ; Height
    cld                               ; Forward
drawIntroBackgroundLoop:
    dec cx                            ; Decrement
    push cx                           ; Save count
    mov cx, 27                        ; Width
    rep stosw                         ; Draw
    add di,106                        ; Next line
    pop cx                            ; Restore count
    cmp cx,0                          ; Check zero
    jne drawIntroBackgroundLoop       ; Loop
    
    mov si, gameName                  ; String
    mov dh, 6                         ; Y pos
    mov dl, 32                        ; X pos
    push 0x0F                         ; Color
    call printStringBios              ; Print
    
    mov si, ourNames                  ; String
    mov dh, 9                         ; Y pos
    mov dl, 28                        ; X pos
    push 0x0F                         ; Color
    call printStringBios              ; Print
    
    mov si, rollNos                   ; String
    mov dh, 12                        ; Y pos
    mov dl, 29                        ; X pos
    push 0x0F                         ; Color
    call printStringBios              ; Print
    
    mov si, semester                  ; String
    mov dh, 15                        ; Y pos
    mov dl, 34                        ; X pos
    push 0x0F                         ; Color
    call printStringBios              ; Print
    
    mov si, introMsg                  ; String
    mov dh, 18                        ; Y pos
    mov dl, 28                        ; X pos
    push 0x8E                         ; Color
    call printStringBios              ; Print
    
    mov ah, 01h                       ; Cursor shape
mov ch, 32                            ; Hide
mov cl, 0
int 10h                               ; Call BIOS
    
    call installGameKbisr             ; Install KB
waitForEnterKey:
    cmp byte[cs:enterPressed],1          ; Check flag
    jne waitForEnterKey               ; Wait
    
    xor ax, ax                        ; Clear AX
mov es, ax                            ; Set ES to 0

mov ax,word [es:8*4]                  ; Save offset
mov word[cs:oldTimer],ax
mov ax,word [es:8*4+2]                ; Save segment
mov word[cs:oldTimer+2],ax

cli                                   ; Disable ints
mov word [es:8*4], customTimerHandler ; Set new ISR
mov [es:8*4+2], cs                    ; Set segment
sti                                   ; Enable ints

    call clearScreenGreen             ; Clear screen
    call drawRoad                     ; Draw road
    call drawSideStripes              ; Draw stripes
    call drawLaneDividers             ; Draw dividers
    
    call createRoadTemplateBuffer     ; Create buffer
    call saveScreenBuffer             ; Save buffer

    call drawPlayerCarMiddle          ; Draw car

mainGameLoop:
    mov ax, cs                        ; Set DS
    mov ds, ax
    cmp byte [cs:gameActive], 0          ; Check active
    je handleGameOver                 ; Jump if over
    
    call restoreOriginalTimer         ; Restore timer
    cmp byte [cs:exitRequested], 1       ; Check exit
    jne gameLoopContinue              ; Jump if no exit
    
    mov byte [cs:exitRequested], 0       ; Reset flag

    call stopSound                    ; Stop sound
    call restoreOriginalKbisr         ; Restore KB
    call displayExitMessageBox        ; Show box

    pollExitConfirmation:
        mov ah, 0
        int 0x16                      ; Get key

        cmp al, 'y'                   ; Check y
        je performCleanExit
        cmp al, 'Y'                   ; Check Y
        je performCleanExit
        
        cmp al, 'n'                   ; Check n
        je resumeGameWithIsr
        cmp al, 'N'                   ; Check N
        je resumeGameWithIsr

        jmp pollExitConfirmation      ; Loop

    resumeGameWithIsr:
    xor ax, ax                        ; Clear AX
mov es, ax                            ; Set ES to 0

cli                                   ; Disable ints
mov word [es:8*4], customTimerHandler ; Set ISR
mov [es:8*4+2], cs
sti                                   ; Enable ints
        call installGameKbisr         ; Install KB
        jmp mainGameLoop              ; Jump to loop

gameLoopContinue:
xor ax, ax                            ; Clear AX
mov es, ax                            ; Set ES to 0

cli                                   ; Disable ints
mov word [es:8*4], customTimerHandler ; Set ISR
mov [es:8*4+2], cs
sti                                   ; Enable ints
    call checkCollisions              ; Check collision
    
    mov ax, 63                        ; X pos
    push ax 
    mov ax, 0                         ; Y pos
    push ax 
    mov ax, 0x2E                      ; Color
    push ax 
    mov ax, scoreMessage              ; String
    push ax 
    call displayString                ; Print
    
    mov ax, 70                        ; X pos
    push ax
    mov ax, 0                         ; Y pos
    push ax
    mov ax, 0x2E                      ; Color
    push ax
    push word [cs:playerScore]           ; Score
    call displayNumber                ; Print
    
    call delayGame                    ; Delay
    jmp mainGameLoop                  ; Loop

performCleanExit:
    
    mov byte [cs:gameActive], 0          ; Set game over
    call stopSound                    ; Stop sound
    call restoreOriginalTimer         ; Restore timer
    
    call displayGameOverScreen        ; Show screen
call delayGame
clearBufferExit:
    mov ah, 01h                       ; Check if key available
    int 0x16
    jz bufferClearedExit              ; If no key, buffer is clear
    mov ah, 0                         ; Remove key from buffer
    int 0x16
    jmp clearBufferExit               ; Check again
    
bufferClearedExit:  
    mov ah, 0
    int 0x16                          ; Wait key
    
    mov ah, 01h                       ; Cursor shape
    mov cx, 0607h                     ; Show cursor
    int 10h                           ; Call BIOS
    mov ax, 0x4c00                    ; Exit code
    int 0x21                          ; Call DOS

handleGameOver:
    call stopSound                    ; Stop sound
    call restoreOriginalKbisr         ; Restore KB
    call restoreOriginalTimer         ; Restore Timer
    
    call displayGameOverScreen        ; Show screen
call delayGame
clearBufferGameOver:
    mov ah, 01h                       ; Check if key available
    int 0x16
    jz bufferClearedGameOver          ; If no key, buffer is clear
    mov ah, 0                         ; Remove key from buffer
    int 0x16
    jmp clearBufferGameOver           ; Check again
    
bufferClearedGameOver:    
    mov ah, 0
    int 0x16                          ; Wait key
    
    mov ah, 01h                       ; Cursor shape
    mov cx, 0607h                     ; Show cursor
    int 10h                           ; Call BIOS
    mov ax, 0x4c00                    ; Exit code
    int 0x21                          ; Call DOS