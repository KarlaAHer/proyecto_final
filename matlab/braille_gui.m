function braille_gui()
%% =====================================================================
%  PANTALLA MATLAB - SISTEMA BIDIRECCIONAL TEXTO <-> BRAILLE (DE10-Lite)
%
%  Toda la logica esta en la FPGA. El modo se elige SOLO con los
%  switches de la tarjeta:
%     SW1 SW0 = 00 reposo, 01 lectura, 10 escritura, 11 practica
%     SW2     = pista en practica (letra visible en los servos)
%
%  Esta ventana solo:
%     - escucha el puerto serial y muestra lo que reporta la FPGA,
%     - lo dice en voz alta (Windows),
%     - en modo lectura, envia la palabra que escribes.
%
%  Uso:  braille_gui     (MATLAB R2019b o mas nuevo, sin toolboxes)
%  Protocolo: ver rtl/braille_controller.v
%  =====================================================================

    BAUD    = 9600;
    MAX_LEN = 16;          % Debe coincidir con MAX_LEN en la FPGA

    s      = [];           % serialport
    rxbuf  = uint8([]);    % bytes recibidos sin procesar
    synth  = [];           % voz
    texto  = '';           % escritura
    palabraW = '';
    histAcc   = [];           % precision tras cada intento (practica)

    % ---------------- Ventana ----------------
    fig = uifigure('Name', 'Braille FPGA', 'Position', [100 80 900 640]);
    fig.CloseRequestFcn = @cerrar;

    g = uigridlayout(fig, [4 1]);
    g.RowHeight = {34, 50, '1x', 110};

    % Fila 1: conexion
    g1 = uigridlayout(g, [1 6]);
    g1.ColumnWidth = {55, 110, 34, 100, '1x', 60};
    g1.Padding = [0 0 0 0];
    uilabel(g1, 'Text', 'Puerto:');
    ddPort = uidropdown(g1, 'Items', listaPuertos());
    uibutton(g1, 'Text', char(8635), 'Tooltip', 'Actualizar puertos', ...
             'ButtonPushedFcn', @(~, ~) set(ddPort, 'Items', listaPuertos()));
    btnCon = uibutton(g1, 'Text', 'Conectar', 'ButtonPushedFcn', @conectar);
    lblEst = uilabel(g1, 'Text', 'Desconectado', 'FontColor', [0.75 0 0]);
    chkVoz = uicheckbox(g1, 'Text', 'Voz', 'Value', true);

    % Fila 2: modo actual (lo decide la tarjeta)
    lblModo = uilabel(g, 'Text', 'MODO: -   (se elige con SW1-SW0 en la tarjeta)', ...
                      'FontSize', 24, 'FontWeight', 'bold', ...
                      'HorizontalAlignment', 'center');

    % Fila 3: un panel por modo, en la misma celda
    area = uigridlayout(g, [1 1]);
    area.Padding = [0 0 0 0];

    % --- Reposo ---
    pI = uipanel(area, 'BorderType', 'none');
    gI = uigridlayout(pI, [1 1]);
    uilabel(gI, 'Text', sprintf(['Mueve los switches de la tarjeta:\n\n' ...
        'SW1 SW0 = 01  ->  Lectura\nSW1 SW0 = 10  ->  Escritura\n' ...
        'SW1 SW0 = 11  ->  Practica   (SW2 = pista)']), ...
        'FontSize', 20, 'HorizontalAlignment', 'center');

    % --- Lectura ---
    pR = uipanel(area, 'BorderType', 'none');
    pR.Layout.Row = 1; pR.Layout.Column = 1;
    gR = uigridlayout(pR, [3 2]);
    gR.RowHeight   = {34, '1x', 30};
    gR.ColumnWidth = {'1x', 150};
    edPal = uieditfield(gR, 'text', 'Placeholder', 'Palabra a mostrar (max 16)', ...
                        'FontSize', 16);
    uibutton(gR, 'Text', 'Enviar palabra', 'ButtonPushedFcn', @enviarPalabra);
    lblLetra = uilabel(gR, 'Text', '-', 'FontSize', 150, 'FontWeight', 'bold', ...
                       'HorizontalAlignment', 'center');
    lblLetra.Layout.Row = 2; lblLetra.Layout.Column = [1 2];
    lblProg = uilabel(gR, 'Text', 'Escribe una palabra. Avanza con KEY1 (NEXT) en la tarjeta.', ...
                      'FontSize', 15, 'HorizontalAlignment', 'center');
    lblProg.Layout.Row = 3; lblProg.Layout.Column = [1 2];

    % --- Escritura ---
    pW = uipanel(area, 'BorderType', 'none');
    pW.Layout.Row = 1; pW.Layout.Column = 1;
    gW = uigridlayout(pW, [2 3]);
    gW.RowHeight   = {'1x', 34};
    gW.ColumnWidth = {'1x', 140, 110};
    taTexto = uitextarea(gW, 'Editable', 'off', 'FontSize', 34, 'Value', {''});
    taTexto.Layout.Row = 1; taTexto.Layout.Column = [1 3];
    lblUlt = uilabel(gW, 'Text', 'Escribe en el teclado Braille. KEY1 (NEXT) = espacio', ...
                     'FontSize', 15);
    uibutton(gW, 'Text', 'Leer en voz alta', 'ButtonPushedFcn', @(~, ~) hablar(texto));
    uibutton(gW, 'Text', 'Borrar', 'ButtonPushedFcn', @borrarTexto);

    % --- Practica ---
    pP = uipanel(area, 'BorderType', 'none');
    pP.Layout.Row = 1; pP.Layout.Column = 1;
    gP = uigridlayout(pP, [3 2]);
    gP.RowHeight   = {30, '1x', 34};
    gP.ColumnWidth = {'1x', '1x'};
    lblRes = uilabel(gP, 'Text', 'La FPGA elige la letra. KEY1 (NEXT) = saltar. SW2 = pista', ...
                     'FontSize', 15, 'HorizontalAlignment', 'center');
    lblRes.Layout.Column = 1;
    ax = uiaxes(gP);
    ax.Layout.Row = [1 3]; ax.Layout.Column = 2;
    title(ax, 'Precision acumulada'); ylabel(ax, '%'); xlabel(ax, 'Intento');
    ylim(ax, [0 100]); grid(ax, 'on');
    lblObj = uilabel(gP, 'Text', '-', 'FontSize', 150, 'FontWeight', 'bold', ...
                     'HorizontalAlignment', 'center');
    lblObj.Layout.Row = 2; lblObj.Layout.Column = 1;
    lblStats = uilabel(gP, 'Text', 'Aciertos: 0   Errores: 0   Precision: 0 %', ...
                       'FontSize', 17, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
    lblStats.Layout.Row = 3; lblStats.Layout.Column = 1;

    % Fila 4: registro
    taLog = uitextarea(g, 'Editable', 'off', 'FontName', 'Consolas', 'Value', {''});

    mostrarModo('I');
    registrar('Selecciona el puerto y presiona Conectar.');


    %% =================================================================
    %  CONEXION Y RECEPCION
    %  =================================================================
    function lst = listaPuertos()
        lst = cellstr(serialportlist("available"));
        if isempty(lst), lst = {'COM5'}; end
    end

    function conectar(~, ~)
        if ~isempty(s)                       % desconectar
            configureCallback(s, "off");
            delete(s); s = [];
            btnCon.Text = 'Conectar';
            lblEst.Text = 'Desconectado'; lblEst.FontColor = [0.75 0 0];
            registrar('Desconectado.');
            return;
        end
        try
            s = serialport(ddPort.Value, BAUD);
        catch err
            s = [];
            uialert(fig, err.message, 'No se pudo abrir el puerto');
            return;
        end
        configureTerminator(s, "LF");
        flush(s);
        rxbuf = uint8([]);
        configureCallback(s, "terminator", @alRecibir);
        btnCon.Text = 'Desconectar';
        lblEst.Text = ['Conectado ' ddPort.Value]; lblEst.FontColor = [0 0.5 0];
        registrar(['Conectado a ' ddPort.Value '.']);
        enviar("Q");                         % la FPGA responde con su modo
    end

    function enviar(txt)
        if isempty(s)
            registrar('No conectado.');
            return;
        end
        write(s, [uint8(char(txt)) 10], "uint8");
    end

    % Se ejecuta cuando llega un '\n' desde la FPGA
    function alRecibir(src, ~)
        n = src.NumBytesAvailable;
        if n == 0, return; end
        rxbuf = [rxbuf reshape(read(src, n, "uint8"), 1, [])];
        while true
            k = find(rxbuf == 10, 1);
            if isempty(k), break; end
            linea = rxbuf(1:k-1);
            rxbuf(1:k) = [];
            if ~isempty(linea), procesar(linea); end
        end
    end


    %% =================================================================
    %  MENSAJES DE LA FPGA (solo se muestran)
    %  =================================================================
    function procesar(m)
        c2 = ' ';
        if numel(m) >= 2, c2 = char(m(2)); end

        switch char(m(1))

            case 'M'                                     % modo (switches)
                mostrarModo(c2);
                registrar(['La tarjeta cambio a modo ' nombreModo(c2)]);
                hablar(['Modo ' lower(nombreModo(c2))]);

            case 'D'                                     % lectura
                lblLetra.Text = upper(c2);
                lblProg.Text  = 'Avanza con KEY1 (NEXT) en la tarjeta.';
                hablar(c2);

            case 'E'
                lblLetra.Text = '-';
                lblProg.Text  = 'Fin de la palabra. Escribe otra.';
                registrar('Fin de la palabra.');

            case 'K'                                     % escritura
                letraEscrita(c2);

            case 'T'                                     % practica: letra nueva
                lblObj.Text = upper(c2);
                lblObj.FontColor = [0 0 0];
                lblRes.Text = 'Escribe esta letra en el teclado Braille';
                hablar(['Letra ' c2]);

            case {'O', 'X'}                              % practica: resultado
                ok = (m(1) == 'O');
                h  = hex2dec(char(m(3:4)));
                e  = hex2dec(char(m(5:6)));
                acc = 100 * h / max(1, h + e);
                histAcc(end + 1) = acc;
                if ok
                    lblObj.FontColor = [0 0.6 0];
                    lblRes.Text = 'Correcto!';
                    hablar('Correcto');
                else
                    lblObj.FontColor = [0.8 0 0];
                    lblRes.Text = sprintf('Incorrecto: escribiste %s', upper(c2));
                    hablar('Incorrecto');
                end
                lblStats.Text = sprintf('Aciertos: %d   Errores: %d   Precision: %.0f %%', h, e, acc);
                plot(ax, 1:numel(histAcc), histAcc, '-o', 'LineWidth', 1.5);
                ylim(ax, [0 100]); grid(ax, 'on');
                registrar(sprintf('%s  (aciertos %d, errores %d)', lblRes.Text, h, e));

            case 'S'
                if numel(m) >= 5
                    registrar(sprintf('Marcador FPGA: aciertos %d, errores %d', ...
                        hex2dec(char(m(2:3))), hex2dec(char(m(4:5)))));
                end

            case '!'
                switch c2
                    case 'L', registrar('Error: palabra demasiado larga.');
                    case 'M', registrar('Pon la tarjeta en modo lectura (SW1 SW0 = 01).');
                    otherwise, registrar(['Error: ' char(m)]);
                end

            otherwise
                registrar(['Mensaje: ' char(m)]);
        end
    end

    % Muestra el panel del modo que reporto la FPGA
    function mostrarModo(m)
        pI.Visible = (m == 'I');
        pR.Visible = (m == 'R');
        pW.Visible = (m == 'W');
        pP.Visible = (m == 'P');
        lblModo.Text = ['MODO: ' nombreModo(m)];
        switch m
            case 'R'
                lblLetra.Text = '-';
            case 'P'                                    % la FPGA borra el marcador
                histAcc = [];
                cla(ax); ylim(ax, [0 100]); grid(ax, 'on');
                lblObj.Text = '-';
                lblStats.Text = 'Aciertos: 0   Errores: 0   Precision: 0 %';
        end
    end

    function n = nombreModo(m)
        switch m
            case 'R', n = 'LECTURA';
            case 'W', n = 'ESCRITURA';
            case 'P', n = 'PRACTICA';
            otherwise, n = 'REPOSO';
        end
    end


    %% =================================================================
    %  LECTURA: lo unico que MATLAB envia es la palabra
    %  =================================================================
    function enviarPalabra(~, ~)
        w = strtrim(edPal.Value);
        if isempty(w), return; end
        if numel(w) > MAX_LEN
            uialert(fig, sprintf('Maximo %d caracteres.', MAX_LEN), 'Palabra muy larga');
            return;
        end
        registrar(['Enviando palabra: ' w]);
        hablar(w);
        enviar("R" + string(w));
    end


    %% =================================================================
    %  ESCRITURA: solo se muestra lo que decodifico la FPGA
    %  =================================================================
    function letraEscrita(c)
        if c == '?'
            beep;
            lblUlt.Text = 'Patron no reconocido';
            return;
        end
        if c == ' '
            if ~isempty(palabraW), hablar(palabraW); end
            palabraW = '';
            lblUlt.Text = 'Espacio';
        else
            palabraW = [palabraW c];
            lblUlt.Text = ['Ultima letra: ' upper(c)];
            hablar(c);
        end
        texto = [texto c];
        taTexto.Value = {texto};
    end

    function borrarTexto(~, ~)
        texto = ''; palabraW = '';
        taTexto.Value = {''};
    end


    %% =================================================================
    %  UTILIDADES
    %  =================================================================
    function registrar(txt)
        linea = sprintf('[%s] %s', char(datetime('now', 'Format', 'HH:mm:ss')), txt);
        v = [{linea}; taLog.Value(:)];
        taLog.Value = v(1:min(end, 200));
    end

    % Voz con .NET (Windows); asincrona para no congelar la ventana
    function hablar(txt)
        if ~chkVoz.Value || isempty(txt), return; end
        try
            if isempty(synth)
                NET.addAssembly('System.Speech');
                synth = System.Speech.Synthesis.SpeechSynthesizer;
            end
            synth.SpeakAsyncCancelAll();
            synth.SpeakAsync(char(txt));
        catch
            % Sin voz disponible
        end
    end

    function cerrar(~, ~)
        if ~isempty(s)
            try, configureCallback(s, "off"); catch, end
            delete(s);
        end
        delete(fig);
    end

end
