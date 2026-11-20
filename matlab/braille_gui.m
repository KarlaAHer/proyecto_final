function braille_gui()
%% =====================================================================
%  INTERFAZ GRAFICA - SISTEMA BIDIRECCIONAL TEXTO <-> BRAILLE (DE10-Lite)
%
%  Escucha el puerto serial en segundo plano (callback). Si cambias el
%  modo con SW1-SW0 en la tarjeta, la FPGA manda M<m> y esta ventana
%  cambia sola a la pestana de ese modo (practica arranca sola).
%  Si cambias de pestana aqui, se manda el modo a la FPGA.
%
%  Uso:  braille_gui     (MATLAB R2019b o mas nuevo, sin toolboxes)
%
%  Protocolo: ver rtl/braille_controller.v
%  =====================================================================

    BAUD    = 9600;
    MAX_LEN = 16;          % Debe coincidir con MAX_LEN en la FPGA
    PAUSA   = 1.5;         % s entre letras en practica (retroalimentacion)

    % ---------------- Estado ----------------
    s      = [];           % objeto serialport
    rxbuf  = uint8([]);    % bytes recibidos sin procesar
    modo   = ' ';          % 'R', 'W' o 'P'
    synth  = [];           % sintetizador de voz

    palabra = '';          % lectura
    idx     = 0;

    texto    = '';         % escritura
    palabraW = '';

    prac.activa = false;   % practica
    prac.k      = 0;
    prac.n      = 10;
    prac.res    = [];
    prac.obj    = ' ';

    tmr = timer('StartDelay', PAUSA, 'ExecutionMode', 'singleShot', ...
                'TimerFcn', @(~, ~) siguienteLetra());

    % ---------------- Ventana ----------------
    fig = uifigure('Name', 'Braille FPGA', 'Position', [100 80 920 660]);
    fig.CloseRequestFcn = @cerrar;

    g = uigridlayout(fig, [3 1]);
    g.RowHeight = {36, '1x', 120};

    % Fila 1: conexion
    g1 = uigridlayout(g, [1 7]);
    g1.ColumnWidth = {55, 110, 34, 100, '1x', 190, 60};
    g1.Padding = [0 0 0 0];
    uilabel(g1, 'Text', 'Puerto:');
    ddPort  = uidropdown(g1, 'Items', listaPuertos());
    uibutton(g1, 'Text', char(8635), 'Tooltip', 'Actualizar puertos', ...
             'ButtonPushedFcn', @(~, ~) set(ddPort, 'Items', listaPuertos()));
    btnCon  = uibutton(g1, 'Text', 'Conectar', 'ButtonPushedFcn', @conectar);
    lblEst  = uilabel(g1, 'Text', 'Desconectado', 'FontColor', [0.75 0 0]);
    lblModo = uilabel(g1, 'Text', 'Modo: -', 'FontSize', 18, 'FontWeight', 'bold');
    chkVoz  = uicheckbox(g1, 'Text', 'Voz', 'Value', true);

    % Fila 2: pestanas de modo
    tg   = uitabgroup(g, 'SelectionChangedFcn', @tabCambiada);
    tabR = uitab(tg, 'Title', '  Lectura  ');
    tabW = uitab(tg, 'Title', '  Escritura  ');
    tabP = uitab(tg, 'Title', '  Practica  ');

    % --- Lectura ---
    gR = uigridlayout(tabR, [3 3]);
    gR.RowHeight   = {34, '1x', 30};
    gR.ColumnWidth = {'1x', 130, 160};
    edPal = uieditfield(gR, 'text', 'Placeholder', 'Palabra (max 16)', ...
                        'FontSize', 16);
    uibutton(gR, 'Text', 'Enviar palabra', 'ButtonPushedFcn', @enviarPalabra);
    uibutton(gR, 'Text', 'Siguiente (NEXT)', 'ButtonPushedFcn', @(~, ~) enviar("N"));
    lblLetra = uilabel(gR, 'Text', '-', 'FontSize', 140, 'FontWeight', 'bold', ...
                       'HorizontalAlignment', 'center');
    lblLetra.Layout.Row = 2; lblLetra.Layout.Column = [1 3];
    lblProg = uilabel(gR, 'Text', 'Escribe una palabra y presiona Enviar', ...
                      'HorizontalAlignment', 'center', 'FontSize', 15);
    lblProg.Layout.Row = 3; lblProg.Layout.Column = [1 3];

    % --- Escritura ---
    gW = uigridlayout(tabW, [2 3]);
    gW.RowHeight   = {'1x', 34};
    gW.ColumnWidth = {'1x', 140, 140};
    taTexto = uitextarea(gW, 'Editable', 'off', 'FontSize', 34, 'Value', {''});
    taTexto.Layout.Row = 1; taTexto.Layout.Column = [1 3];
    lblUlt = uilabel(gW, 'Text', 'Escribe con el teclado Braille.  NEXT = espacio', ...
                     'FontSize', 15);
    uibutton(gW, 'Text', 'Leer en voz alta', 'ButtonPushedFcn', @(~, ~) hablar(texto));
    uibutton(gW, 'Text', 'Borrar', 'ButtonPushedFcn', @borrarTexto);

    % --- Practica ---
    gP = uigridlayout(tabP, [3 6]);
    gP.RowHeight   = {34, '1x', 30};
    gP.ColumnWidth = {55, 70, 170, 110, 110, '1.4x'};
    uilabel(gP, 'Text', 'Letras:');
    spnN    = uispinner(gP, 'Limits', [1 100], 'Value', 10, 'RoundFractionalValues', 'on');
    chkPista = uicheckbox(gP, 'Text', 'Mostrar pista en la celda');
    uibutton(gP, 'Text', 'Iniciar', 'ButtonPushedFcn', @(~, ~) pedirPractica());
    uibutton(gP, 'Text', 'Detener', 'ButtonPushedFcn', @(~, ~) detenerPractica());
    ax = uiaxes(gP);
    ax.Layout.Row = [1 3]; ax.Layout.Column = 6;
    title(ax, 'Precision acumulada'); ylabel(ax, '%'); xlabel(ax, 'Intento');
    ylim(ax, [0 100]); grid(ax, 'on');
    lblObj = uilabel(gP, 'Text', '-', 'FontSize', 140, 'FontWeight', 'bold', ...
                     'HorizontalAlignment', 'center');
    lblObj.Layout.Row = 2; lblObj.Layout.Column = [1 5];
    lblStats = uilabel(gP, 'Text', 'Aciertos: 0   Errores: 0   Precision: 0 %', ...
                       'FontSize', 16, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
    lblStats.Layout.Row = 3; lblStats.Layout.Column = [1 5];

    % Fila 3: registro
    taLog = uitextarea(g, 'Editable', 'off', 'FontName', 'Consolas', 'Value', {''});

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
        registrar(['Conectado a ' ddPort.Value '. Consultando modo...']);
        enviar("Q");                         % la FPGA responde M<m>
    end

    function enviar(txt)
        if isempty(s)
            registrar('No conectado.');
            return;
        end
        write(s, [uint8(char(txt)) 10], "uint8");
    end

    % Se ejecuta solo cuando llega un '\n' desde la FPGA
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
    %  MENSAJES DE LA FPGA
    %  =================================================================
    function procesar(m)
        c2 = ' ';
        if numel(m) >= 2, c2 = char(m(2)); end

        switch char(m(1))

            case 'M'                                 % cambio de modo
                registrar(['La tarjeta esta en modo ' nombreModo(c2)]);
                entrarModo(c2);

            case 'D'                                 % lectura: letra
                mostrarTab('R');
                idx = idx + 1;
                lblLetra.Text = upper(c2);
                lblProg.Text  = sprintf('Letra %d de %d   (NEXT = siguiente)', ...
                                        idx, max(idx, numel(palabra)));
                hablar(c2);

            case 'E'                                 % lectura: fin
                lblLetra.Text = '-';
                lblProg.Text  = 'Fin de la palabra. Escribe otra.';
                registrar('Fin de la palabra.');

            case 'K'                                 % escritura
                mostrarTab('W');
                letraEscrita(c2);

            case 'T'
                registrar(['Objetivo: ' c2]);

            case {'O', 'X'}                          % practica
                resultado(char(m(1)) == 'O', c2);

            case 'N'                                 % NEXT en practica
                if prac.activa
                    registrar('Letra saltada.');
                    siguienteLetra();
                end

            case 'S'
                if numel(m) >= 5
                    registrar(sprintf('Marcador FPGA: aciertos %d, errores %d', ...
                        hex2dec(char(m(2:3))), hex2dec(char(m(4:5)))));
                end

            case '!'
                switch c2
                    case 'L', registrar('Error: palabra demasiado larga.');
                    case 'U', registrar('Error: comando o caracter no soportado.');
                    case 'T', registrar('Sin letra objetivo (inicia la practica).');
                    otherwise, registrar(['Error: ' char(m)]);
                end

            otherwise
                registrar(['Mensaje: ' char(m)]);
        end
    end

    % Entra al modo m ('R', 'W', 'P'), venga de la FPGA o de la pestana
    function entrarModo(m)
        if m ~= 'P' && prac.activa
            detenerPractica();
        end
        modo = m;
        mostrarTab(m);
        switch m
            case 'R'
                lblLetra.Text = '-';
                lblProg.Text  = 'Escribe una palabra y presiona Enviar';
            case 'W'
                lblUlt.Text = 'Escribe con el teclado Braille.  NEXT = espacio';
            case 'P'
                if ~prac.activa
                    iniciarPractica();               % arranca sola
                end
        end
    end

    function mostrarTab(m)
        modo = m;
        lblModo.Text = ['Modo: ' nombreModo(m)];
        switch m
            case 'R', tg.SelectedTab = tabR;
            case 'W', tg.SelectedTab = tabW;
            case 'P', tg.SelectedTab = tabP;
        end
    end

    function n = nombreModo(m)
        switch m
            case 'R', n = 'LECTURA';
            case 'W', n = 'ESCRITURA';
            case 'P', n = 'PRACTICA';
            otherwise, n = '-';
        end
    end

    % El usuario cambio de pestana: avisar a la FPGA
    function tabCambiada(~, ev)
        if isempty(s), return; end
        if ev.NewValue == tabR
            enviar("R");
        elseif ev.NewValue == tabW
            enviar("W");
        else
            enviar("P");
        end
        % La FPGA responde M<m> y entrarModo() hace el resto
    end


    %% =================================================================
    %  LECTURA
    %  =================================================================
    function enviarPalabra(~, ~)
        w = strtrim(edPal.Value);
        if isempty(w), return; end
        if numel(w) > MAX_LEN
            uialert(fig, sprintf('Maximo %d caracteres.', MAX_LEN), 'Palabra muy larga');
            return;
        end
        if prac.activa, detenerPractica(); end
        palabra = w;
        idx = 0;
        mostrarTab('R');
        registrar(['Enviando palabra: ' w]);
        enviar("R" + string(w));
    end


    %% =================================================================
    %  ESCRITURA
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
    %  PRACTICA
    %  =================================================================

    % Boton Iniciar: si la FPGA ya esta en practica arranca; si no,
    % pide el modo y arrancara al llegar MP.
    function pedirPractica()
        if modo == 'P'
            iniciarPractica();
        else
            enviar("P");
        end
    end

    function iniciarPractica()
        stop(tmr);
        prac.activa = true;
        prac.n   = spnN.Value;
        prac.k   = 0;
        prac.res = [];
        actualizarStats();
        registrar(sprintf('Practica iniciada: %d letras.', prac.n));
        siguienteLetra();
    end

    function siguienteLetra()
        stop(tmr);
        if ~prac.activa, return; end
        if prac.k >= prac.n
            terminarPractica();
            return;
        end
        prac.k = prac.k + 1;
        letras = 'a':'z';
        prac.obj = letras(randi(numel(letras)));
        if chkPista.Value, cmd = "H"; else, cmd = "P"; end
        enviar(cmd + string(prac.obj));
        lblObj.Text = upper(prac.obj);
        lblObj.FontColor = [0 0 0];
        lblStats.Text = sprintf('Letra %d de %d  -  escribela en el teclado', prac.k, prac.n);
        hablar(['Letra ' prac.obj]);
    end

    function resultado(ok, tecleada)
        if ~prac.activa, return; end
        prac.res(end + 1) = ok;
        if ok
            lblObj.FontColor = [0 0.6 0];
            registrar(sprintf('Correcto: %s', upper(prac.obj)));
            hablar('Correcto');
        else
            lblObj.FontColor = [0.8 0 0];
            registrar(sprintf('Incorrecto: se pidio %s, escribio %s', ...
                              upper(prac.obj), upper(tecleada)));
            hablar('Incorrecto');
        end
        actualizarStats();
        start(tmr);                 % siguiente letra tras la pausa
    end

    function actualizarStats()
        h = sum(prac.res == 1);
        e = sum(prac.res == 0);
        acc = 100 * h / max(1, h + e);
        lblStats.Text = sprintf('Aciertos: %d   Errores: %d   Precision: %.0f %%', h, e, acc);
        cla(ax);
        if ~isempty(prac.res)
            v = prac.res;
            plot(ax, 1:numel(v), 100 * cumsum(v) ./ (1:numel(v)), '-o', 'LineWidth', 1.5);
        end
        ylim(ax, [0 100]);
    end

    function terminarPractica()
        prac.activa = false;
        h = sum(prac.res == 1);
        e = sum(prac.res == 0);
        acc = 100 * h / max(1, h + e);
        lblObj.Text = char(10003);
        lblObj.FontColor = [0 0.4 0.8];
        actualizarStats();
        registrar(sprintf('Practica terminada. Aciertos %d, errores %d, precision %.0f %%', h, e, acc));
        hablar(sprintf('Practica terminada. Precision %.0f por ciento', acc));
    end

    function detenerPractica()
        stop(tmr);
        if prac.activa
            prac.activa = false;
            registrar('Practica detenida.');
        end
        lblObj.Text = '-';
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
        try, stop(tmr); delete(tmr); catch, end
        if ~isempty(s)
            try, configureCallback(s, "off"); catch, end
            delete(s);
        end
        delete(fig);
    end

end
