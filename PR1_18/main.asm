.386
.model flat,stdcall
.stack 4096

; Объявление внешних функций Windows API
GetStdHandle proto stdcall :dword
WriteConsoleA proto stdcall :dword, :ptr, :dword, :ptr, :dword
ReadConsoleA proto stdcall :dword, :ptr, :dword, :ptr, :dword
ExitProcess proto stdcall :dword

.const
STD_OUTPUT_HANDLE equ -11
STD_INPUT_HANDLE equ -10

.data
promptX db 'Enter a value for X: ', 0                       ; Сообщение для ввода X
promptY db 'Enter a value for Y: ', 0                       ; Сообщение для ввода Y
inputBufferX db 16 dup(0)                                   ; Буфер для значения X
inputBufferY db 16 dup(0)                                   ; Буфер для значения Y
bytesReadX dd 0                                             ; Кол-во прочитанных байт X
bytesReadY dd 0                                             ; Кол-во прочитанных байт Y
inputLength dd 16                                           ; Длина буфера входа
resultBuffer db 16 dup(0)                                   ; Буфер для вывода результата
resultBytes dd 0                                            ; Кол-во байт, записанных в буфер результата
errorMessage db 'Error: Non-numeric input.', 0              ; Сообщение об ошибке
xValue dd 0                                                 ; Хранимое значение X
yValue dd 0                                                 ; Хранимое значение Y
resultMessage db 'The result of the ((X+Y)/Y^2 - 1)*X: ', 0 ; Сообщение о результате
bytesResultMessage dd 0                                     ; Кол-во прочитанных байт в сообщении о результате

.code
main proc
	; === Получаем OutputHandle ===
    push STD_OUTPUT_HANDLE
    call GetStdHandle
    mov edi, eax                      ; Сохраняем Handle в EDI (стандартный вывод)
    test edi, edi                     ; Проверяем, корректный ли Handle
    jz error                          ; Если Handle = 0, переходим к error

    ; === Получаем InputHandle ===
    push STD_INPUT_HANDLE
    call GetStdHandle
    mov esi, eax                      ; Сохраняем Handle в ESI (стандартный ввод)
    test esi, esi                     ; Проверяем, корректный ли Handle
    jz error                          ; Если Handle = 0, переходим к error

    ; === Вывод сообщения для X ===
    push 0
    push OFFSET bytesReadX
    push LENGTHOF promptX
    lea edx, promptX
    push edx
    push edi
    call WriteConsoleA

    ; === Ввод значения X ===
    push 0
    push OFFSET bytesReadX
    push inputLength
    lea edx, inputBufferX
    push edx
    push esi
    call ReadConsoleA

    ; === Проверяем, что X число ===
    lea edx, inputBufferX           ; Привязываем адрес буфера для значения X
    mov ecx, bytesReadX             ; Передаем число байт, прочитанных в X
    call validateInput              ; Вызываем процедуру проверки значения
    test eax, eax                   ; Проверяем результат (0 = ошибка, 1 = корректно)
    jz error                        ; Если ошибка, переходим к error

    ; === Конвертируем X в число ===
    lea ecx, inputBufferX           ; Привязываем адрес буфера для значения X
    call stringToInt                ; Вызываем процедуру конвертации значения
    mov xValue, eax                 ; Сохраняем значение X

    ; === Вывод сообщения для Y ===
    push 0
    push OFFSET bytesReadY
    push LENGTHOF promptY
    lea edx, promptY
    push edx
    push edi
    call WriteConsoleA

    ; === Ввод значения Y ===
    push 0
    push OFFSET bytesReadY
    push inputLength
    lea edx, inputBufferY
    push edx
    push esi
    call ReadConsoleA

    ; === Проверяем, что X число ===
    lea edx, inputBufferY           ; Привязываем адрес буфера для значения Y
    mov ecx, bytesReadY             ; Передаем число байт, прочитанных в Y
    call validateInput              ; Вызываем процедуру проверки значения
    test eax, eax                   ; Проверяем результат (0 = ошибка, 1 = корректно)
    jz error                        ; Если ошибка, переходим к error

    ; === Конвертируем Y в число ===
    lea ecx, inputBufferY               ; Привязываем адрес буфера для значения Y
    call stringToInt                    ; Вызываем процедуру конвертации значения
    mov yValue, eax                     ; Сохраняем значение Y

    ; === Вычисление ===
    ; xValue - значение X
    ; yValue - значение Y
    ; EDI - OutputHandle
    xor esi, esi

    ; EAX = XY
    imul eax, xValue

    ; === Конвертация результата в строку ===
    push edi
    ;mov eax, 0                          ; Целая часть числа
    mov ebx, 0                          ; Дробная часть числа
    mov ecx, 0                          ; Число нулей в начале дробной части
    mov esi, 0                          ; Флаг отрицательного числа (0/1)
    lea edi, resultBuffer               ; Привязываем буфер для результата
    call floatToString                  ; Вызываем процедуру для конвертации результата в строку
    pop edi

    ; === Вывод выражения ===
    push 0
    push OFFSET bytesResultMessage
    push LENGTHOF resultMessage
    lea edx, resultMessage
    push edx
    push edi
    call WriteConsoleA

    ; === Вывод результата ===
    push 0
    push OFFSET resultBytes
    push LENGTHOF resultBuffer
    lea edx, resultBuffer
    push edx
    push edi
    call WriteConsoleA

    ; === Успешное завершение программы ===
    push 0
    call ExitProcess

error:
    ; Вывод сообщения об ошибке
    push 0
    push LENGTHOF errorMessage
    lea edx, errorMessage
    push edx
    push edi                         
    call WriteConsoleA

    push 1
    call ExitProcess
main ENDP

validateInput PROC
    ; === Проверка значения ===
    ; Вход:
    ;   EDX - Адрес буфера со строкой
    ;   ECX - Длина строки
    ; Output:
    ;   EAX - 1 если строка корректна, 0 - если нет

    dec ecx                           ; Уменьшаем счетчик, прочитанных байт, чтобы исключить '\n'
    dec ecx                           ; Уменьшаем счетчик, прочитанных байт, чтобы исключить '\r'
    cmp byte ptr [edx + ecx], 13      ; Проверяем, если последний символ '\r'
    je trimCarriageReturn
continueValidation:
    mov eax, 1                        ; Предположим, что ввод действителен
validateLoop:
    mov al, byte ptr [edx]            ; Получим текущий символ
    cmp al, '0'                       ; Проверяем, если >= '0'
    jl invalid                        ; Если меньше, некорректно
    cmp al, '9'                       ; Проверяем, если <= '9'
    jg invalid                        ; Если больше, некорректно
    inc edx                           ; Переходим к следующему символу
    loop validateLoop                 ; Цикл по всем символам
    mov eax, 1                        ; Ввод корректный
    ret
invalid:
    mov eax, 0                        ; Ввод некорректный
    ret
trimCarriageReturn:
    mov byte ptr [edx + ecx], 0
    jmp continueValidation
validateInput ENDP

stringToInt PROC
    ; === Конвертация строки в число ===
    ; Вход:
    ;   ECX - адрес буфера со строкой
    ; Выход:
    ;   EAX - число
    ; Используется:
    ;   EDX - хранение остатка от деления
    xor eax, eax                      ; Очищаем EAX
    xor edx, edx                      ; Очищаем EDX
convertLoop:
    mov dl, byte ptr [ecx]            ; Сохраняем символ из строки в DL
    cmp dl, 0                         ; Проверияем на null-terminator
    je doneConversion
    sub dl, '0'                       ; Конвертируем ASCII в число
    imul eax, eax, 10                 ; Умножаем EAX на 10
    add eax, edx                      ; Добавляем число к результату
    inc ecx                           ; Переходим к следующему символу
    jmp convertLoop
doneConversion:
    ret
stringToInt ENDP

floatToString PROC
    ; === Конвертация дробного числа в строку
    ; Вход:
    ;   EAX = Целая часть
    ;   EBX = Дробная часть
    ;   ECX = Число нулей в начале дробной части
    ;   ESI = Флаг отрицательного числа (0/1)
    ;   EDI = Ссылка на буфер для строки
    ; Используется:
    ;   ECX = Счетчик символов
    ;   EDX = Хранение остатка

    push ebx                          ; Сохранить дробную часть
    push ecx

    xor ecx, ecx                      ; Счётчик символов

    ; === Обработка целой части числа ===
    test esi, esi                   ; Проверить, отрицательное ли число
    jz positiveNumber               ; Если положительное, перейти к обработке
    mov byte ptr [edi], '-'         ; Добавить знак "-"
    inc edi                         ; Сдвинуть указатель буфера

positiveNumber:
    mov ebx, 10                       ; Делитель для десятичной системы
convertIntegerLoop:
    xor edx, edx                      ; Очистить остаток
    div ebx                           ; Деление EAX на 10 (EAX = частное, EDX = остаток)
    add dl, '0'                       ; Преобразовать остаток в ASCII
    push edx                          ; Сохранить ASCII-символ в стеке
    inc ecx                           ; Увеличить счётчик символов
    test eax, eax                     ; Проверить, деление завершено
    jnz convertIntegerLoop            ; Продолжать, если частное не 0

; Запись целой части в буфер
writeIntegerChars:
    pop ebx                           ; Извлечь символ из стека
    mov byte ptr [edi], bl            ; Записать символ в буфер
    inc edi                           ; Сдвинуть указатель
    loop writeIntegerChars            ; Повторить для всех символов

    ; === Обработка дробной части числа ===
    pop esi
    pop eax                           ; Восстановить дробную часть из стека
    test eax, eax
    jz endFraction

    ; === Добавить десятичную точку ===
    mov byte ptr [edi], '.'           ; Добавить символ "."
    inc edi                           ; Сдвинуть указатель

performConvertFraction:
    xor edx, edx                      ; Очистить старшую часть
    mov ebx, 10                       ; Делитель для десятичной системы
convertFractionLoop:
    xor edx, edx
    div ebx                             ; Деление EAX на 10 (EAX = частное, EDX = остаток)
    add dl, '0'                         ; Преобразовать остаток в ASCII
    push edx                            ; Сохранить ASCII-символ в стеке
    inc ecx                             ; Увеличить счётчик символов
    test eax, eax                       ; Проверить, деление завершено
    jnz convertFractionLoop             ; Продолжать, если частное не 0

    test esi, esi
    jz writeFractionChars
    xor edx, edx
addZerosToFractionLoop:
    add dl, '0'
    push edx
    inc ecx
    dec esi
    test esi, esi
    jnz addZerosToFractionLoop

; Запись дробной части в буфер
writeFractionChars:
    pop edx                           ; Извлечь символ из стека
    mov byte ptr [edi], dl            ; Записать символ в буфер
    inc edi                           ; Сдвинуть указатель
    loop writeFractionChars            ; Повторить для всех символов

endFraction:
    ; === Завершение строки ===
    mov byte ptr [edi], 0             ; Добавить null-терминатор
    ret
floatToString ENDP

end main