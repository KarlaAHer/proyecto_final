%% =====================================================================
%  INTERFAZ MATLAB - SISTEMA BIDIRECCIONAL TEXTO <-> BRAILLE (DE10-Lite)
%
%  Comunicacion: UART 9600 8N1 via FT232RL (o HC-05 por Bluetooth: solo
%  cambia el puerto COM). Todas las lineas terminan en '\n'.
%
%  PC -> FPGA:  R<texto> | W | P<c> | H<c> | N | S | C
%  FPGA -> PC:  D<c> E | K<c> | T<c> O<c><hh><mm> X<c><hh><mm> N |
%               S<hh><mm> | M<m> | !L !U !T
%  (ver rtl/braille_controller.v para el detalle)
%  =====================================================================

clear; clc;

PORT     = "COM5";   % Cambiar por el puerto del FT232RL / HC-05
BAUD     = 9600;
MAX_LEN  = 16;       % Debe coincidir con MAX_LEN en la FPGA
USE_TTS  = true;     % Voz (solo Windows, System.Speech)

s = serialport(PORT, BAUD);
pause(2);
flush(s);

disp("Conexion UART iniciada.");

while true

    fprintf("\n========== MENU ==========\n");
    fprintf(" 1) Lectura   (PC -> celda Braille)\n");
    fprintf(" 2) Escritura (teclado Braille -> PC)\n");
    fprintf(" 3) Practica  (aciertos / errores)\n");
    fprintf(" 4) Ver marcador de la FPGA\n");
    fprintf(" 5) Borrar marcador\n");
    fprintf(" 0) Salir\n");
    op = input("Opcion: ");

    switch op
        case 1, modo_lectura(s, MAX_LEN, USE_TTS);
        case 2, modo_escritura(s, USE_TTS);
        case 3, modo_practica(s, USE_TTS);
        case 4
            fpga_send(s, "S");
            m = fpga_wait(s, 'S', 2);
            if ~isempty(m), mostrar_marcador(m); end
        case 5
            fpga_send(s, "C");
            fpga_wait(s, 'S', 2);
            disp("Marcador borrado.");
        case 0
            break;
    end

end

clear s;
disp("Fin.");


%% =====================================================================
%  MODO A: LECTURA
%  =====================================================================
function modo_lectura(s, MAX_LEN, USE_TTS)

    palabra = input("Palabra a mostrar: ", "s");
    if isempty(palabra), return; end
    if strlength(palabra) > MAX_LEN
        fprintf("Maximo %d caracteres.\n", MAX_LEN);
        return;
    end

    hablar(USE_TTS, palabra);
    fpga_send(s, "R" + palabra);
    disp("Presione NEXT en la tarjeta para avanzar.");

    n = 0;
    while true
        m = fpga_read(s, 120);
        if isempty(m)
            disp("Tiempo agotado.");
            return;
        end
        switch char(m(1))
            case 'D'
                n = n + 1;
                fprintf("Mostrando '%s'  (%d/%d)\n", char(m(2)), n, strlength(palabra));
            case 'E'
                disp("Fin de la palabra.");
                return;
            case '!'
                mostrar_error(m);
                return;
            otherwise
                mostrar_otro(m);
        end
    end

end


%% =====================================================================
%  MODO B: ESCRITURA
%  NEXT = espacio. Dos espacios seguidos terminan la sesion.
%  =====================================================================
function modo_escritura(s, USE_TTS)

    fpga_send(s, "W");
    fpga_wait(s, 'M', 2);

    disp("Escriba con el teclado Braille.");
    disp("NEXT = espacio; NEXT dos veces = terminar.");

    texto   = '';
    palabra = '';

    while true
        m = fpga_read(s, 120);
        if isempty(m)
            disp("Sin actividad, fin de la sesion.");
            break;
        end
        if char(m(1)) ~= 'K'
            mostrar_otro(m);
            continue;
        end

        c = char(m(2));

        if c == ' '
            if isempty(palabra)          % segundo espacio seguido
                break;
            end
            hablar(USE_TTS, palabra);
            texto   = [texto palabra ' ']; %#ok<AGROW>
            palabra = '';
        elseif c == '?'
            beep;
            disp("  (patron no reconocido)");
            continue;
        else
            palabra = [palabra c]; %#ok<AGROW>
        end

        fprintf("Texto: %s%s\n", texto, palabra);
    end

    texto = strtrim([texto palabra]);
    fprintf("\nTexto final: %s\n", texto);
    hablar(USE_TTS, texto);

end


%% =====================================================================
%  MODO C: PRACTICA
%  =====================================================================
function modo_practica(s, USE_TTS)

    rondas = input("Numero de letras: ");
    pista  = input("Mostrar la letra en la celda como pista? (s/n): ", "s");
    cmd    = "P";
    if lower(pista) == "s", cmd = "H"; end

    letras    = 'a':'z';
    objetivo  = blanks(rondas);
    tecleado  = blanks(rondas);
    resultado = nan(1, rondas);      % 1 acierto, 0 error, NaN saltada

    for k = 1:rondas

        c = letras(randi(numel(letras)));
        objetivo(k) = c;

        fpga_send(s, cmd + string(c));
        if isempty(fpga_wait(s, 'T', 2))
            disp("La FPGA no acepto el objetivo.");
            return;
        end

        fprintf("\n[%d/%d] Escriba la letra '%s'\n", k, rondas, upper(c));
        hablar(USE_TTS, "Letra " + c);

        while true
            m = fpga_read(s, 120);
            if isempty(m)
                disp("Tiempo agotado.");
                break;
            end
            tipo = char(m(1));
            if tipo == 'O' || tipo == 'X'
                tecleado(k)  = char(m(2));
                resultado(k) = (tipo == 'O');
                if resultado(k)
                    disp("  Correcto!");
                    hablar(USE_TTS, "Correcto");
                else
                    fprintf("  Incorrecto: escribio '%s'\n", tecleado(k));
                    hablar(USE_TTS, "Incorrecto");
                end
                mostrar_marcador(m(2:end));
                break;
            elseif tipo == 'N'
                disp("  Letra saltada.");
                break;
            else
                mostrar_otro(m);
            end
        end

    end

    % ---- Resumen ----
    validas = ~isnan(resultado);
    aciertos = sum(resultado(validas));
    errores  = sum(validas) - aciertos;
    precision = 100 * aciertos / max(1, sum(validas));

    fprintf("\nAciertos: %d   Errores: %d   Precision: %.1f %%\n", ...
            aciertos, errores, precision);
    hablar(USE_TTS, sprintf("Precision %.0f por ciento", precision));

    figure("Name", "Practica Braille");
    subplot(1, 2, 1);
    bar([aciertos errores]);
    set(gca, "XTickLabel", {"Aciertos", "Errores"});
    title("Resultado de la sesion");

    subplot(1, 2, 2);
    r = resultado;
    r(isnan(r)) = 0;
    plot(1:rondas, 100 * cumsum(r) ./ (1:rondas), "-o");
    ylim([0 100]); grid on;
    xlabel("Intento"); ylabel("Precision acumulada (%)");
    title("Progreso");

end


%% =====================================================================
%  COMUNICACION
%  =====================================================================

% Envia un comando terminado en '\n' (bytes crudos, admite la n con tilde)
function fpga_send(s, txt)
    write(s, [uint8(char(txt)) 10], "uint8");
end

% Lee una linea (sin el '\n') como vector uint8. [] si hay timeout.
function m = fpga_read(s, timeout)
    m = uint8([]);
    t0 = tic;
    while toc(t0) < timeout
        if s.NumBytesAvailable > 0
            b = read(s, 1, "uint8");
            if b == 10
                if ~isempty(m), return; end
            else
                m(end + 1) = b; %#ok<AGROW>
            end
        else
            pause(0.005);
        end
    end
    m = uint8([]);
end

% Espera una respuesta que empiece con 'tipo'. Muestra las demas.
function m = fpga_wait(s, tipo, timeout)
    t0 = tic;
    while toc(t0) < timeout
        m = fpga_read(s, timeout - toc(t0));
        if isempty(m), break; end
        if char(m(1)) == tipo, return; end
        mostrar_otro(m);
    end
    m = uint8([]);
end

function mostrar_marcador(m)
    % m = 'S' u otro encabezado + 4 digitos hex al final
    h = hex2dec(char(m(end-3:end-2)));
    e = hex2dec(char(m(end-1:end)));
    fprintf("  Marcador FPGA -> aciertos: %d  errores: %d\n", h, e);
end

function mostrar_error(m)
    switch char(m(2))
        case 'L', disp("Error: palabra demasiado larga.");
        case 'U', disp("Error: comando o caracter no soportado.");
        case 'T', disp("Error: no hay letra objetivo.");
        otherwise, fprintf("Error: %s\n", char(m));
    end
end

function mostrar_otro(m)
    switch char(m(1))
        case 'M'
            fprintf("(La tarjeta cambio a modo %s)\n", char(m(2)));
        case '!'
            mostrar_error(m);
        otherwise
            fprintf("(Mensaje: %s)\n", char(m));
    end
end

% Texto a voz con .NET (Windows). En otros sistemas solo imprime.
function hablar(usar, txt)
    persistent sintetizador
    if ~usar, return; end
    try
        if isempty(sintetizador)
            NET.addAssembly("System.Speech");
            sintetizador = System.Speech.Synthesis.SpeechSynthesizer;
        end
        Speak(sintetizador, char(txt));
    catch
        % Sin voz disponible: no hacer nada
    end
end
