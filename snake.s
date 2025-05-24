# Змейка на GAS для Windows, x86, компиляция с GCC/MinGW

.intel_syntax noprefix
.section .data
    ClassName: .asciz "SnakeClass"
    AppName: .asciz "Snake Game"
    game_over_msg: .asciz "Game Over!"
    snake_x: .long 160        # X-координата головы
    snake_y: .long 100        # Y-координата головы
    direction: .byte 0         # 0=вправо, 1=вниз, 2=влево, 3=вверх
    food_x: .long 0           # X-координата еды
    food_y: .long 0           # Y-координата еды
    snake_length: .long 3     # Длина змейки
    snake_body: .fill 100, 8, 0 # Массив для координат тела (x, y)
    hInstance: .long 0
    hWnd: .long 0
    seed: .long 0
    game_over_flag: .byte 0   # Флаг завершения игры
    FIELD_WIDTH = 320
    FIELD_HEIGHT = 200
    SNAKE_SIZE = 10
    DELAY = 100

    # Структуры для Win32
    .align 4
    wc: .fill 40, 1, 0       # WNDCLASS (40 байт)
    msg: .fill 28, 1, 0      # MSG (28 байт)
    ps: .fill 32, 1, 0       # PAINTSTRUCT (32 байта)

.section .text
.global _WinMain@16
_WinMain@16:
    # Сохранить регистры
    push ebp
    mov ebp, esp
    push ebx
    push esi
    push edi

    # Получить дескриптор экземпляра
    push 0
    call _GetModuleHandleA@4
    mov dword ptr [hInstance], eax

    # Инициализация генератора случайных чисел
    call _GetTickCount@0
    mov dword ptr [seed], eax

    # Регистрация класса окна
    lea eax, [WndProc]
    mov dword ptr [wc+12], eax  # lpfnWndProc
    mov eax, [hInstance]
    mov dword ptr [wc+16], eax  # hInstance
    mov dword ptr [wc+36], offset ClassName # lpszClassName
    mov eax, 1                  # COLOR_WINDOW
    mov dword ptr [wc+28], eax  # hbrBackground
    push offset wc
    call _RegisterClassA@4

    # Создание окна
    push 0
    push [hInstance]
    push 0
    push 0
    push 260                    # Высота окна
    push 340                    # Ширина окна
    push 0x80000000             # CW_USEDEFAULT
    push 0x80000000             # CW_USEDEFAULT
    push 0x00CF0000             # WS_OVERLAPPEDWINDOW
    push offset AppName
    push offset ClassName
    push 0
    call _CreateWindowExA@48
    mov dword ptr [hWnd], eax

    # Показать окно
    push 1                      # SW_SHOWNORMAL
    push [hWnd]
    call _ShowWindow@8
    push [hWnd]
    call _UpdateWindow@4

    # Разместить первую еду
    call spawn_food

    # Основной цикл сообщений
msg_loop:
    lea eax, [msg]
    push 0
    push 0
    push 0
    push eax
    call _GetMessageA@16
    test eax, eax
    jz end_program
    lea eax, [msg]
    push eax
    call _TranslateMessage@4
    lea eax, [msg]
    push eax
    call _DispatchMessageA@4
    jmp msg_loop

end_program:
    push [msg+8]                # wParam
    call _ExitProcess@4

WndProc:
    push ebp
    mov ebp, esp
    sub esp, 4                  # Локальная переменная для hdc
    push ebx
    push esi
    push edi

    mov eax, [ebp+12]           # uMsg
    cmp eax, 2                  # WM_DESTROY
    je wm_destroy
    cmp eax, 15                 # WM_PAINT
    je wm_paint
    cmp eax, 258                # WM_KEYDOWN
    je wm_keydown
    cmp eax, 275                # WM_TIMER
    je wm_timer
    push [ebp+20]               # lParam
    push [ebp+16]               # wParam
    push [ebp+12]               # uMsg
    push [ebp+8]                # hWnd
    call _DefWindowProcA@16
    jmp wndproc_end

wm_destroy:
    push 1
    push [ebp+8]
    call _KillTimer@8
    push 0
    call _PostQuitMessage@4
    xor eax, eax
    jmp wndproc_end

wm_keydown:
    mov eax, [ebp+16]           # wParam
    cmp eax, 38                 # VK_UP
    je set_up
    cmp eax, 40                 # VK_DOWN
    je set_down
    cmp eax, 37                 # VK_LEFT
    je set_left
    cmp eax, 39                 # VK_RIGHT
    je set_right
    xor eax, eax
    jmp wndproc_end

set_up:
    cmp byte ptr [direction], 1
    je skip_key
    mov byte ptr [direction], 3
    jmp skip_key
set_down:
    cmp byte ptr [direction], 3
    je skip_key
    mov byte ptr [direction], 1
    jmp skip_key
set_left:
    cmp byte ptr [direction], 0
    je skip_key
    mov byte ptr [direction], 2
    jmp skip_key
set_right:
    cmp byte ptr [direction], 2
    je skip_key
    mov byte ptr [direction], 0
skip_key:
    xor eax, eax
    jmp wndproc_end

wm_timer:
    cmp byte ptr [game_over_flag], 1
    je skip_timer
    # Обновить позицию змейки
    mov eax, [snake_x]
    mov ebx, [snake_y]
    movzx ecx, byte ptr [direction]
    cmp ecx, 0
    je move_right
    cmp ecx, 1
    je move_down
    cmp ecx, 2
    je move_left
    cmp ecx, 3
    je move_up

move_right:
    add eax, SNAKE_SIZE
    jmp update_pos
move_down:
    add ebx, SNAKE_SIZE
    jmp update_pos
move_left:
    sub eax, SNAKE_SIZE
    jmp update_pos
move_up:
    sub ebx, SNAKE_SIZE

update_pos:
    # Проверка столкновения со стенками
    cmp eax, 0
    jl game_over_label
    cmp eax, FIELD_WIDTH
    jge game_over_label
    cmp ebx, 0
    jl game_over_label
    cmp ebx, FIELD_HEIGHT
    jge game_over_label

    # Проверка столкновения с едой
    cmp eax, [food_x]
    jne no_food
    cmp ebx, [food_y]
    jne no_food
    inc dword ptr [snake_length]
    call spawn_food

no_food:
    # Сдвинуть тело змейки
    mov esi, offset snake_body
    mov ecx, [snake_length]
    dec ecx
    shl ecx, 3
    add esi, ecx
    mov edi, esi
    sub edi, 8
    mov ecx, [snake_length]
    dec ecx
shift_loop:
    mov eax, [edi]
    mov [esi], eax
    mov eax, [edi+4]
    mov [esi+4], eax
    sub esi, 8
    sub edi, 8
    loop shift_loop

    # Обновить голову
    mov [snake_x], eax
    mov [snake_y], ebx
    mov [snake_body], eax
    mov [snake_body+4], ebx

    # Проверка столкновения с телом
    mov esi, offset snake_body+8
    mov ecx, [snake_length]
    dec ecx
check_collision:
    cmp eax, [esi]
    jne no_collision
    cmp ebx, [esi+4]
    je game_over_label
no_collision:
    add esi, 8
    loop check_collision

    # Перерисовать окно
    push 1
    push 0
    push [ebp+8]
    call _InvalidateRect@12
skip_timer:
    xor eax, eax
    jmp wndproc_end

game_over_label:
    mov byte ptr [game_over_flag], 1
    push 0
    push offset AppName
    push offset game_over_msg
    push [ebp+8]
    call _MessageBoxA@16
    push 0
    call _PostQuitMessage@4
    xor eax, eax
    jmp wndproc_end

wm_paint:
    # Начало рисования
    lea eax, [ps]
    push eax
    push [ebp+8]
    call _BeginPaint@8
    mov [ebp-4], eax            # hdc

    # Отрисовка змейки
    push 0xFFFFFF               # Белый цвет
    call _CreateSolidBrush@4
    mov ebx, eax
    mov esi, offset snake_body
    mov ecx, [snake_length]
draw_snake:
    mov eax, [esi]
    mov edx, [esi+4]
    push ebx
    push [ebp-4]
    call _SelectObject@8
    push eax
    push edx
    add edx, SNAKE_SIZE
    push edx
    push eax
    add eax, SNAKE_SIZE
    push eax
    push [ebp-4]
    call _Rectangle@20
    add esi, 8
    loop draw_snake
    push ebx
    call _DeleteObject@4

    # Отрисовка еды
    push 0xFF                   # Красный цвет
    call _CreateSolidBrush@4
    mov ebx, eax
    push ebx
    push [ebp-4]
    call _SelectObject@8
    mov eax, [food_x]
    mov edx, [food_y]
    push edx
    add edx, SNAKE_SIZE
    push edx
    push eax
    add eax, SNAKE_SIZE
    push eax
    push [ebp-4]
    call _Rectangle@20
    push ebx
    call _DeleteObject@4

    # Завершение рисования
    lea eax, [ps]
    push eax
    push [ebp+8]
    call _EndPaint@8

    # Установить таймер
    push 0
    push DELAY
    push 1
    push [ebp+8]
    call _SetTimer@16
    xor eax, eax
    jmp wndproc_end

wndproc_end:
    pop edi
    pop esi
    pop ebx
    mov esp, ebp
    pop ebp
    ret

spawn_food:
    # Генерация случайных координат
    call _GetTickCount@0
    mov [seed], eax
    mov eax, [seed]
    imul eax, 22677
    add eax, 12345
    mov [seed], eax
    xor edx, edx
    mov ecx, FIELD_WIDTH-SNAKE_SIZE
    div ecx
    mov [food_x], edx
    mov eax, [seed]
    imul eax, 22677
    add eax, 12345
    mov [seed], eax
    xor edx, edx
    mov ecx, FIELD_HEIGHT-SNAKE_SIZE
    div ecx
    mov [food_y], edx
    ret

# Объявления внешних функций Win32 API
.extern _GetModuleHandleA@4
.extern _RegisterClassA@4
.extern _CreateWindowExA@48
.extern _ShowWindow@8
.extern _UpdateWindow@4
.extern _GetMessageA@16
.extern _TranslateMessage@4
.extern _DispatchMessageA@4
.extern _ExitProcess@4
.extern _DefWindowProcA@16
.extern _KillTimer@8
.extern _PostQuitMessage@4
.extern _BeginPaint@8
.extern _EndPaint@8
.extern _CreateSolidBrush@4
.extern _SelectObject@8
.extern _Rectangle@20
.extern _DeleteObject@4
.extern _InvalidateRect@12
.extern _SetTimer@16
.extern _GetTickCount@0
.extern _MessageBoxA@16

# Пустая строка для корректного завершения файла