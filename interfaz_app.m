classdef interfaz_app < matlab.apps.AppBase
    % INTERFAZ_APP Aplicación principal del gemelo digital del TCLab.
    %
    % Esta aplicación permite conectar con la plataforma TCLab, leer la
    % temperatura del sensor T1, aplicar control manual o automático mediante
    % un controlador PI, ejecutar un modelo térmico virtual de dos estados,
    % realizar ensayos de calibración y detectar fallos simulados de sensor.
    %
    % Archivo exportado en formato .m para facilitar la consulta del código
    % en el repositorio de GitHub. La versión ejecutable principal del proyecto
    % se mantiene en el archivo interfaz_app.mlapp.

    % Componentes gráficos de la interfaz
    properties (Access = public)
        UIFigure                       matlab.ui.Figure
        Image5                         matlab.ui.control.Image
        Image4                         matlab.ui.control.Image
        INFORMACINPanel                matlab.ui.container.Panel
        TextArea                       matlab.ui.control.TextArea
        Image3                         matlab.ui.control.Image
        MODOOPERATIVOPanel             matlab.ui.container.Panel
        FallodesensorButton            matlab.ui.control.StateButton
        NormalButton                   matlab.ui.control.StateButton
        CALIBRACINPanel                matlab.ui.container.Panel
        RealizarensayoButton           matlab.ui.control.Button
        TEMPERATURAAMBIENTEPanel       matlab.ui.container.Panel
        TambValorLabel                 matlab.ui.control.Label
        TemperaturaambienteLabel       matlab.ui.control.Label
        GRFICASPanel                   matlab.ui.container.Panel
        UIAxes                         matlab.ui.control.UIAxes
        UIAxes_2                       matlab.ui.control.UIAxes
        CONTROLPanel                   matlab.ui.container.Panel
        TemperaturaobjetivoCEditField  matlab.ui.control.NumericEditField
        TemperaturaEditFieldLabel      matlab.ui.control.Label
        PotenciaSlider                 matlab.ui.control.Slider
        PotenciaLabel                  matlab.ui.control.Label
        Switch                         matlab.ui.control.Switch
        CONEXINPanel                   matlab.ui.container.Panel
        Image                          matlab.ui.control.Image
        Image2                         matlab.ui.control.Image
        PuertoLabel                    matlab.ui.control.Label
        conexionLabel                  matlab.ui.control.Label
        EstadoLamp                     matlab.ui.control.Lamp
        EstadoLampLabel                matlab.ui.control.Label
        DesconectarButton              matlab.ui.control.Button
        ConnectButton                  matlab.ui.control.Button
    end

    
    properties (Access = private)

        % Estado de conexión y datos de ejecución
        isConnected logical = false   % estado de conexión
        isDisconnecting logical = false
        tmr                           % timer
        t0
        timeData = []
        tempData = []
        inputData = []
        refData = []
        currentInput = 0

        % Ensayo y datos de calibración
        calibrando logical = false
        tCalib double = []
        TCalib double = []
        UCalib double = []
        TambCalib double = []
        tInicioCalib double = []

        % Detector y simulador de fallo de sensor
        sensorFault logical = false          % fallo simulado con el botón
        sensorFaultDetected logical = false  % fallo detectado automáticamente
        
        T_control = []
        
        umbralFalloSensor = 5                % diferencia máxima aceptable [ºC]
        contadorFalloSensor = 0              % tiempo acumulado con error grande
        tiempoConfirmacionFallo = 8          % segundos para confirmar fallo

        contadorRecuperacionSensor = 0       % tiempo acumulado con error pequeño
        tiempoConfirmacionRecuperacion = 5   % segundos para confirmar recuperación

        falloActivoPlot logical = false      % indica si hay una franja de fallo abierta
        tInicioFallo = NaN                   % instante en el que empieza el fallo detectado
        intervalosFallo = []                 % guarda los tramos [inicio, fin] de fallo

        % Controlador PI 
        Kp = 3.1861
        Ki = 0.0197
        integralError = 0

        % Modelo virtual del TCLab

        U_model = 4.9102
        alpha_model = 0.0087
        tau_sensor = 34.7346
        
        m_model = 0.004
        cp_model = 500
        A_model = 0.001
        epsilon_model = 0.9
        sigma_model = 5.67e-8
        
        Tamb_model = NaN
        Tamb_defecto = 24.33
        
        TH_virtual = []
        TC_virtual = []
        tempVirtualData = []
        lastTime = []
    end
    
    methods (Access = private)
        
        function actualizarEstadoConexion(app, estado)

            switch estado

                case "desconectado"
                    app.EstadoLamp.Color = [0.65 0.65 0.65];
                    app.isConnected = false;
                    app.conexionLabel.Text = 'Desconectado';

                case "conectando"
                    app.EstadoLamp.Color = [1 0.5 0];
                    app.isConnected = false;
                    app.conexionLabel.Text = 'Conectando...';

                case "conectado"
                    app.EstadoLamp.Color = [0 1 0];
                    app.isConnected = true;
                    app.conexionLabel.Text = 'Conectado';

                case "error"
                    app.EstadoLamp.Color = [1 0 0];
                    app.isConnected = false;
                    app.conexionLabel.Text = 'Error';
            end
        end

        function actualizarDatos(app)
           
             if ~app.isConnected || app.isDisconnecting
                return
             end

            try
                if ~evalin('base',"exist('T1C','var') || exist('T1C','file')")
                    return
                end

                T = evalin('base','T1C()');
                t = toc(app.t0);
    
                dt = t - app.lastTime;
                app.lastTime = t;

                if dt <= 0 || dt > 5
                    dt = 1;
                end

                % Ensayo de calibración

                if app.calibrando
                    app.ejecutarEnsayoCalibracion(t, T, dt);
                    return;
                end

                % Simulación de fallo del sensor
                if app.sensorFault
                    T_sensor = 0;     % simulamos que el sensor falla y lee 0 ºC
                else
                    T_sensor = T;     % lectura normal del sensor real
                end
                
                % Control automático mediante PI
                if strcmp(app.Switch.Value, 'AUTOMÁTICO')
                    Tref = app.TemperaturaobjetivoCEditField.Value;

                    if app.sensorFaultDetected
                        app.T_control = app.TC_virtual;
                    else
                        app.T_control = T_sensor;
                    end

                    error = Tref - app.T_control;

                    % Acción PI antes de aplicar saturación
                    u_unsat = app.Kp * error + app.Ki * app.integralError;
                    
                    % Saturación física del calentador: 0 % - 100 %
                    u = max(0, min(100, u_unsat));
                    
                    % Corrección anti-windup mediante back-calculation
                    Ti = app.Kp / app.Ki;
                    Tt = Ti;
                    
                    et = u - u_unsat;
                    
                    app.integralError = app.integralError + (error + et/(app.Ki*Tt)) * dt;
                    
                    % Enviar potencia al calentador
                    evalin('base', sprintf('h1(%f);', u));
                
                    % Guardar la entrada aplicada
                    app.currentInput = u;
               
                end
                
                % ===============================
                % MODELO VIRTUAL / GEMELO DIGITAL DE DOS ESTADOS
                % TH_virtual: temperatura del calentador
                % TC_virtual: temperatura del sensor
                % ===============================
                
                THK = app.TH_virtual + 273.15;
                TambK = app.Tamb_model + 273.15;
                
                dTHdt = ( ...
                    app.U_model * app.A_model * (TambK - THK) + ...
                    app.epsilon_model * app.sigma_model * app.A_model * (TambK^4 - THK^4) + ...
                    app.alpha_model * app.currentInput ...
                    ) / (app.m_model * app.cp_model);
                
                dTCdt = (app.TH_virtual - app.TC_virtual) / app.tau_sensor;
                
                app.TH_virtual = app.TH_virtual + dt * dTHdt;
                app.TC_virtual = app.TC_virtual + dt * dTCdt;
                
                T_virtual = app.TC_virtual;

                if ~app.calibrando

                    % ===============================
                    % DETECCIÓN AUTOMÁTICA DE FALLO DE SENSOR
                    % ===============================
                    
                    errorSensor = abs(T_sensor - T_virtual);
                    
                    if errorSensor > app.umbralFalloSensor
                    
                        app.contadorFalloSensor = app.contadorFalloSensor + dt;
                        app.contadorRecuperacionSensor = 0;
                    
                        if app.contadorFalloSensor >= app.tiempoConfirmacionFallo
                    
                            if ~app.sensorFaultDetected
                                app.sensorFaultDetected = true;
                    
                                app.tInicioFallo = t;
                                app.falloActivoPlot = true;
                    
                                agregarMensaje(app, sprintf( ...
                                    'Fallo de sensor detectado automáticamente. Error sensor-modelo = %.2f ºC', ...
                                    errorSensor));
                            end
                        end
                    
                    else
                    
                        app.contadorRecuperacionSensor = app.contadorRecuperacionSensor + dt;
                        app.contadorFalloSensor = 0;
                    
                        if app.sensorFaultDetected && ...
                                app.contadorRecuperacionSensor >= app.tiempoConfirmacionRecuperacion
                    
                            app.sensorFaultDetected = false;
                    
                            if app.falloActivoPlot
                                app.intervalosFallo(end+1,:) = [app.tInicioFallo, t];
                                app.falloActivoPlot = false;
                                app.tInicioFallo = NaN;
                            end
                    
                            agregarMensaje(app, ...
                                'Sensor recuperado automáticamente: el error sensor-modelo vuelve a ser aceptable.');
                        end
                    end
                end
                                
                % Guardar datos para representación gráfica
                app.timeData(end+1) = t;
                app.tempData(end+1) = T_sensor;
                app.tempVirtualData(end+1) = T_virtual;
                if strcmp(app.Switch.Value, 'AUTOMÁTICO')
                    app.refData(end+1) = app.TemperaturaobjetivoCEditField.Value;
                else
                    app.refData(end+1) = NaN;
                end
                app.inputData(end+1) = app.currentInput;
        
                % Representación de temperatura real, virtual y referencia

                cla(app.UIAxes);
                hold(app.UIAxes, 'on');
                
                % Primero dibujamos las curvas para calcular bien los límites del eje Y
                plot(app.UIAxes, app.timeData, app.tempData, 'b-', 'LineWidth', 1.5);
                plot(app.UIAxes, app.timeData, app.tempVirtualData, 'r--', 'LineWidth', 1.5);
                plot(app.UIAxes, app.timeData, app.refData, 'k:', 'LineWidth', 2);
                
                yl = ylim(app.UIAxes);
                
                % Franjas de fallos ya terminados
                for i = 1:size(app.intervalosFallo,1)
                
                    x1 = app.intervalosFallo(i,1);
                    x2 = app.intervalosFallo(i,2);
                
                    patch(app.UIAxes, ...
                        [x1 x2 x2 x1], ...
                        [yl(1) yl(1) yl(2) yl(2)], ...
                        [1 0.85 0.85], ...
                        'FaceAlpha', 0.45, ...
                        'EdgeColor', 'none');
                end
                
                % Franja del fallo actual, si todavía sigue activo
                if app.falloActivoPlot
                
                    x1 = app.tInicioFallo;
                    x2 = t;
                
                    patch(app.UIAxes, ...
                        [x1 x2 x2 x1], ...
                        [yl(1) yl(1) yl(2) yl(2)], ...
                        [1 0.85 0.85], ...
                        'FaceAlpha', 0.45, ...
                        'EdgeColor', 'none');
                end
                
                % Volvemos a dibujar las curvas encima de las franjas
                plot(app.UIAxes, app.timeData, app.tempData, 'b-', 'LineWidth', 1.5);
                plot(app.UIAxes, app.timeData, app.tempVirtualData, 'r--', 'LineWidth', 1.5);
                plot(app.UIAxes, app.timeData, app.refData, 'k:', 'LineWidth', 2);
                
                hold(app.UIAxes, 'off');

                grid(app.UIAxes, 'on');
                xlabel(app.UIAxes, 'Tiempo (s)');
                ylabel(app.UIAxes, 'Temperatura (°C)');
                title(app.UIAxes, 'Temperatura real vs modelo virtual');
                legend(app.UIAxes, 'T real', 'T virtual', 'Referencia','Location', 'best');
                % Representación de la potencia aplicada
                plot(app.UIAxes_2, app.timeData, app.inputData, 'r-', 'LineWidth', 1.5);
                grid(app.UIAxes_2, 'on');
                xlabel(app.UIAxes_2, 'Tiempo (s)');
                ylabel(app.UIAxes_2, 'Potencia (%)');
                title(app.UIAxes_2, 'Entrada h1');
        
                drawnow limitrate
        
            catch ME
                disp(ME.message)
            end
        end

        function puerto = obtenerPuertoArduino(app)
            puerto = 'Desconocido';

            try
                existeArduino = evalin('base','exist(''a'',''var'')');
        
                if existeArduino
                    puerto = evalin('base','a.Port');
                end
            catch
                puerto = 'Desconocido';
            end 
        end

        function agregarMensaje(app, mensaje)

            hora = datetime("now",'Format','HH:mm:ss');

            nuevoMensaje = sprintf('[%s] %s', hora, mensaje);

            if isempty(app.TextArea.Value)
                app.TextArea.Value = {nuevoMensaje};
            else
                app.TextArea.Value = [
                    {nuevoMensaje};
                    {''};
                    app.TextArea.Value
                    ];
            end

            drawnow;

        end

        function Tamb = calcularTemperaturaAmbiente(app)

             d = uiprogressdlg(app.UIFigure, ...
                'Title','Temperatura ambiente', ...
                'Message','Midiendo temperatura ambiente...', ...
                'Indeterminate','off', ...
                'Cancelable','off');
        
            evalin('base','h1(0);');
            app.currentInput = 0;
        
            Ts = 2;
            ventana = 60;
            umbral = 1.0;
            N = ventana/Ts;
        
            while true
        
                T_data = zeros(N,1);
        
                for k = 1:N
        
                    T_data(k) = evalin('base','T1C()');
        
                    progreso = k/N;
        
                    d.Value = progreso;
                    d.Message = sprintf('Midiendo... %.0f %%\nTemperatura actual: %.2f ºC', ...
                        100*progreso, T_data(k));
        
                    drawnow;
                    pause(Ts);
                end
        
                T_filtrada = T_data;
                medianaT = median(T_data);
                T_filtrada(abs(T_data - medianaT) > 1.0) = [];
        
                variacion = max(T_filtrada) - min(T_filtrada);
        
                if variacion <= umbral
        
                    Tamb = mean(T_filtrada);
                    app.Tamb_model = Tamb;

                    app.TambValorLabel.Text = sprintf('%.2f ºC', Tamb);

                    assignin('base','Tamb',Tamb);
                    save('temperatura_ambiente_TCLab.mat','Tamb');
                    writematrix(Tamb,'temperatura_ambiente_TCLab.csv');
        
                    d.Value = 1;
                    d.Message = sprintf('Temperatura ambiente calculada:\nTamb = %.2f ºC', Tamb);
        
                    drawnow;
                    pause(1);
        
                    close(d);
                    return
        
                else
        
                    d.Value = 0;
                    d.Message = sprintf('La temperatura no está estable.\nVariación = %.2f ºC.\nRepitiendo medición...', variacion);
        
                    drawnow;
                    pause(5);
                end
            end
        end

        function ejecutarEnsayoCalibracion(app, t, T, dt)

            if isempty(app.tInicioCalib)
                app.tInicioCalib = t;
            end
            
            tRel = t - app.tInicioCalib;
        
            % Perfil de potencia del ensayo de calibración
            if tRel < 60
                u = 0;
            elseif tRel < 720
                u = 50;
            elseif tRel < 1320
                u = 0;
            else
                evalin('base', 'h1(0);');
                app.currentInput = 0;
                app.calibrando = false;
                app.guardarEnsayoCalibracion();
                agregarMensaje(app,"Ensayo de calibración finalizado y guardado.");
                
                agregarMensaje(app,"Ajustando parámetros del modelo...");

                [U_model, alpha_model, tau_sensor] = ajustarParametrosModeloTCLab(app);

                app.U_model = U_model;
                app.alpha_model = alpha_model;
                app.tau_sensor = tau_sensor;

                agregarMensaje(app, sprintf( ...
                    'Nuevos parámetros cargados: U=%.4f, alpha=%.4f, tau=%.2f', ...
                    app.U_model, app.alpha_model, app.tau_sensor));
        
                app.UIAxes.Color = [1 1 1];
                app.UIAxes_2.Color = [1 1 1];
        
                return;
            end
        
            % Aplicar entrada al TCLab
            evalin('base', sprintf('h1(%f);', u));
            app.currentInput = u;
        
            % Actualizar modelo virtual también durante calibración
            THK = app.TH_virtual + 273.15;
            TambK = app.Tamb_model + 273.15;
            
            dTHdt = ( ...
                app.U_model * app.A_model * (TambK - THK) + ...
                app.epsilon_model * app.sigma_model * app.A_model * (TambK^4 - THK^4) + ...
                app.alpha_model * app.currentInput ...
                ) / (app.m_model * app.cp_model);
            
            dTCdt = (app.TH_virtual - app.TC_virtual) / app.tau_sensor;
            
            app.TH_virtual = app.TH_virtual + dt * dTHdt;
            app.TC_virtual = app.TC_virtual + dt * dTCdt;
            
            T_virtual = app.TC_virtual;
        
            % Guardar datos
            app.tCalib(end+1) = tRel;
            app.TCalib(end+1) = T;
            app.UCalib(end+1) = u;
            app.TambCalib(end+1) = app.Tamb_model;
        
            % Guardar también en los datos generales para pintar en la app
            app.timeData(end+1) = tRel;
            app.tempData(end+1) = T;
            app.tempVirtualData(end+1) = T_virtual;
            app.refData(end+1) = NaN;
            app.inputData(end+1) = u;
        
            % Pintar gráficas en modo ensayo
            cla(app.UIAxes);
            hold(app.UIAxes, 'on');
            plot(app.UIAxes, app.timeData, app.tempData, 'b-', 'LineWidth', 1.5);
            plot(app.UIAxes, app.timeData, app.tempVirtualData, 'r--', 'LineWidth', 1.5);
            hold(app.UIAxes, 'off');
        
            grid(app.UIAxes, 'on');
            xlabel(app.UIAxes, 'Tiempo ensayo (s)');
            ylabel(app.UIAxes, 'Temperatura (°C)');
            title(app.UIAxes, 'Ensayo de calibración - Temperatura real vs modelo');
            legend(app.UIAxes, 'T real', 'T virtual', 'Location', 'best');
        
            cla(app.UIAxes_2);
            plot(app.UIAxes_2, app.timeData, app.inputData, 'r-', 'LineWidth', 1.5);
            grid(app.UIAxes_2, 'on');
            xlabel(app.UIAxes_2, 'Tiempo ensayo (s)');
            ylabel(app.UIAxes_2, 'Potencia (%)');
            title(app.UIAxes_2, 'Ensayo de calibración - Entrada aplicada');
        
            drawnow limitrate
        end

        function guardarEnsayoCalibracion(app)

            t = app.tCalib(:);
            u = app.UCalib(:);
            T = app.TCalib(:);
            Tamb = app.TambCalib(:);
        
            save('ensayos/ensayo_calibracion_actual.mat','t','u','T','Tamb');

        end

        function cargarParametrosModelo(app)

            if exist('parametros_modelo_TCLab.mat','file')

                S = load('parametros_modelo_TCLab.mat');

                app.U_model = S.U_model;
                app.alpha_model = S.alpha_model;
                app.tau_sensor = S.tau_sensor;

                agregarMensaje(app, sprintf( ...
                    'Parámetros cargados: U=%.4f, alpha=%.4f, tau=%.2f', ...
                    app.U_model, app.alpha_model, app.tau_sensor));

            else
                agregarMensaje(app, ...
                    'No se encontró parametros_modelo_TCLab.mat. Se usan valores por defecto.');
            end

        end

        function [U_model, alpha_model, tau_sensor] = ajustarParametrosModeloTCLab(app)

            % Ensayos utilizados para el ajuste de parámetros
            archivos = {
                'ensayos/ensayo_30_40.mat'
                'ensayos/ensayo_40_50.mat'
                'ensayos/ensayo_30_60.mat'
                'ensayos/ensayo_60_30.mat'
                'ensayos/ensayo_calibracion_actual.mat'
            };
            
            D = {};
            
            for i = 1:length(archivos)
                S = load(archivos{i});
            
                D{end+1}.t = S.t(:);
                D{end}.Q = S.u(:);
                D{end}.T = S.T(:);
            
                if isfield(S,'Tamb')
                    D{end}.Tamb = S.Tamb(:);
                else
                    D{end}.Tamb = S.T(1)*ones(size(S.T(:)));
                end
            end
            
            % Valores iniciales de la optimización
            x0 = [4.9102 0.0087 34.7346];
            
            opciones = optimset( ...
                'Display','off', ...
                'MaxIter',300, ...
                'MaxFunEvals',1000);
            
            x_est = fminsearch(@(x) error_total_modelo(app,x,D), x0, opciones);
            
            U_model = x_est(1);
            alpha_model = x_est(2);
            tau_sensor = x_est(3);
            
            save('parametros_modelo_TCLab.mat', ...
                 'U_model', 'alpha_model', 'tau_sensor');
            
            end

            function J = error_total_modelo(app,x,D)
            
                J = 0;
                
                for i = 1:length(D)
                
                    t = D{i}.t;
                    Q = D{i}.Q;
                    Treal = D{i}.T;
                    Tamb = D{i}.Tamb;
                
                    Tmod = simular_balance_U_alpha_tau(app,x,t,Q,Treal(1),Tamb);
                
                    e = Treal - Tmod;
                
                    J = J + mean(e.^2);
                
                end
            
            end

            function TC = simular_balance_U_alpha_tau(app,x,t,Q,T0,Tamb)
            
                U     = x(1);
                alpha = x(2);
                tau   = x(3);
                
                if U <= 0 || alpha <= 0 || tau <= 0
                    TC = 1e6*ones(size(t));
                    return
                end
                
                m = 0.004;
                cp = 500;
                A = 0.001;
                epsilon = 0.9;
                sigma = 5.67e-8;
                
                N = length(t);
                
                TH = zeros(N,1);
                TC = zeros(N,1);
                
                TH(1) = T0;
                TC(1) = T0;
                
                for k = 1:N-1
                
                    Ts = t(k+1) - t(k);
                
                    if Ts <= 0 || Ts > 10
                        Ts = 1;
                    end
                
                    THK = TH(k) + 273.15;
                    TambK = Tamb(k) + 273.15;
                
                    dTHdt = ( ...
                        U*A*(TambK - THK) + ...
                        epsilon*sigma*A*(TambK^4 - THK^4) + ...
                        alpha*Q(k) ...
                        ) / (m*cp);
                
                    dTCdt = (TH(k) - TC(k)) / tau;
                
                    TH(k+1) = TH(k) + Ts*dTHdt;
                    TC(k+1) = TC(k) + Ts*dTCdt;
                
                end
                
            end

    end

    % Callbacks that handle component events
    methods (Access = private)

        % Código ejecutado al iniciar la aplicación
        function startupFcn(app)
            SwitchValueChanged(app, [])

            app.NormalButton.Value = true;
            app.FallodesensorButton.Value = false;
            app.sensorFault = false;

        end

        % Callback del botón Conectar
        function ConnectButtonPushed(app, event)
           try
                app.isDisconnecting = false;
                app.isConnected = false;

                % estado conectando (naranja)
                actualizarEstadoConexion(app, "conectando");
                drawnow
                % limpiar timer anterior
                if ~isempty(app.tmr)
                    if isvalid(app.tmr)
                        stop(app.tmr);
                        delete(app.tmr);
                    end
                end
        
                % Comprobar si el objeto de conexión ya existe
                existeArduino = evalin('base','exist(''a'',''var'')');    

                if ~existeArduino
                    % Ejecutar el script de conexión solo si es necesario
                    evalin('base','run(''tclab.m'')'); 
                end
        
                % Realizar una primera lectura para comprobar la comunicación
                Ttest = evalin('base','T1C()');

                opcionTamb = uiconfirm(app.UIFigure, ...
                    sprintf('¿Cómo quieres definir la temperatura ambiente del modelo virtual? (Por defecto es %.2f ºC)', app.Tamb_defecto), ...
                    'Temperatura ambiente', ...
                    'Options', {'Medir', 'Manual', 'Defecto'}, ...
                    'DefaultOption', 3, ...
                    'CancelOption', 3);
            switch opcionTamb
            
                case 'Medir'
                    Tamb = calcularTemperaturaAmbiente(app);
                    app.Tamb_model = Tamb;
            
                case 'Manual'
                    respuesta = inputdlg( ...
                        'Introduce la temperatura ambiente [ºC]:', ...
                        'Temperatura ambiente manual', ...
                        [1 40], ...
                        {num2str(Ttest,'%.2f')});
            
                    if isempty(respuesta)
                        app.Tamb_model = app.Tamb_defecto;
                    else
                        app.Tamb_model = str2double(respuesta{1});
                    end
            
                case 'Defecto'
                    app.Tamb_model = app.Tamb_defecto;
            end

                app.TambValorLabel.Text = sprintf('%.2f ºC', app.Tamb_model);

                if exist('parametros_modelo_TCLab.mat','file')

                    S = load('parametros_modelo_TCLab.mat');

                    app.U_model = S.U_model;
                    app.alpha_model = S.alpha_model;
                    app.tau_sensor = S.tau_sensor;

                    agregarMensaje(app, sprintf( ...
                        'Parámetros cargados: U=%.4f, alpha=%.4f, tau=%.2f', ...
                        app.U_model, app.alpha_model, app.tau_sensor));

                else

                    agregarMensaje(app, ...
                        'No se encontró parametros_modelo_TCLab.mat. Se usan valores por defecto.');

                end

                app.TH_virtual = Ttest;
                app.TC_virtual = Ttest;
                
                puerto = obtenerPuertoArduino(app);
                app.PuertoLabel.Text = ['Puerto: ' puerto];
                   
                % Inicializar vectores de datos
                app.timeData = [];
                app.tempData = [];
                app.tempVirtualData = [];
                app.inputData = [];
                app.refData = [];

                app.t0 = tic;
                app.lastTime = 0;
                app.currentInput = 0;
                app.integralError = 0;
        
                % Limpiar gráficas
                cla(app.UIAxes, 'reset');
                cla(app.UIAxes_2, 'reset');
                
                legend(app.UIAxes, 'off');
                legend(app.UIAxes_2, 'off');

                % Actualizar estado de conexión
                actualizarEstadoConexion(app, "conectado");
        
                % Crear temporizador de actualización periódica
                app.tmr = timer('ExecutionMode','fixedSpacing', 'Period',1.0,'TimerFcn', @(~,~) actualizarDatos(app));
        
                start(app.tmr);
        
            catch ME
                actualizarEstadoConexion(app, "error");
                uialert(app.UIFigure, ME.message, 'Error al conectar TCLab');
           end
        end

        % Callback del botón Desconectar
        function DesconectarButtonPushed(app, event)
            try
               app.isDisconnecting = true;
               app.isConnected = false;

                if ~isempty(app.tmr)
                    if isvalid(app.tmr)
                        stop(app.tmr);
                        delete(app.tmr);
                    end
                end
                
                app.tmr = [];

                evalin('base','h1(0);');
                pause(0.2);
        
                app.currentInput = 0;

                app.timeData = [];
                app.tempData = [];
                app.tempVirtualData = [];
                app.inputData = [];
                app.refData = [];

                cla(app.UIAxes, 'reset');
                cla(app.UIAxes_2, 'reset');
                
                legend(app.UIAxes, 'off');
                legend(app.UIAxes_2, 'off');

                actualizarEstadoConexion(app, "desconectado");
                
                app.PuertoLabel.Text = 'Puerto: ...';
                drawnow;
                pause(0.1);
                app.isDisconnecting = false;

            catch ME
                uialert(app.UIFigure, ME.message, 'Error al desconectar');
            end
        end

        % Callback del slider de potencia
        function PotenciaSliderValueChanged(app, event)
            % solo en modo manual y conectado
            if app.isConnected && strcmp(app.Switch.Value, 'MANUAL')
        
                valor = app.PotenciaSlider.Value;
        
                % seguridad
                valor = max(0, min(100, valor));
        
                % enviar al heater 1
                evalin('base', sprintf('h1(%f);', valor));
                app.currentInput = valor;
            end
        end

        % Callback del campo de temperatura objetivo
        function TemperaturaobjetivoCEditFieldValueChanged(app, event)
            Tref = app.TemperaturaobjetivoCEditField.Value;
            disp(Tref)
        end

        % Callback del selector Manual/Automático
        function SwitchValueChanged(app, event)
            
            if strcmp(app.Switch.Value, 'MANUAL')
                app.PotenciaSlider.Enable = 'on';
                app.TemperaturaobjetivoCEditField.Enable = 'off';
            else
                app.PotenciaSlider.Enable = 'off';
                app.TemperaturaobjetivoCEditField.Enable = 'on';
            end
            
        end

        % Callback del botón de calibración
        function RealizarensayoButtonPushed(app, event)
            if ~app.isConnected
                agregarMensaje(app,"Conecta primero el TCLab antes de iniciar el ensayo de calibración.");
                return;
            end

            if app.calibrando
                agregarMensaje(app,"Ya hay un ensayo de calibración en curso.");
                return;
            end

            app.UIAxes.Color = [1 0.98 0.90];
            app.UIAxes_2.Color = [1 0.98 0.90];

            app.calibrando = true;
            app.tCalib = [];
            app.TCalib = [];
            app.UCalib = [];
            app.TambCalib = [];

            app.tInicioCalib = [];

            app.timeData = [];
            app.tempData = [];
            app.tempVirtualData = [];
            app.inputData = [];
            app.refData = [];

            cla(app.UIAxes, 'reset');
            cla(app.UIAxes_2, 'reset');

            agregarMensaje(app, "Ensayo de calibración iniciado.");
        end

        % Callback del botón Modo normal
        function NormalButtonValueChanged(app, event)
            if app.NormalButton.Value
                app.sensorFault = false;
        
                app.FallodesensorButton.Value = false;
                app.NormalButton.Value = true;
        
                agregarMensaje(app, 'Modo normal activado: el sensor toma los valores reales.');
            end
        end

        % Callback del botón Fallo de sensor
        function FallodesensorButtonValueChanged(app, event)
            if app.FallodesensorButton.Value
                app.sensorFault = true;
        
                app.NormalButton.Value = false;
                app.FallodesensorButton.Value = true;
        
                agregarMensaje(app, 'Fallo de sensor simulado: el sensor pasa a entregar una lectura incorrecta.');
            end
        end
    end

    % Inicialización de componentes gráficos
    methods (Access = private)

        % Crear la ventana principal y los componentes
        function createComponents(app)

            % Ruta base para cargar imágenes
            pathToMLAPP = fileparts(mfilename('fullpath'));

            % Crear la ventana principal inicialmente oculta
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Color = [0.9412 0.9608 0.9804];
            app.UIFigure.Position = [100 100 808 653];
            app.UIFigure.Name = 'MATLAB App';
            app.UIFigure.Theme = 'light';

            % Create CONEXINPanel
            app.CONEXINPanel = uipanel(app.UIFigure);
            app.CONEXINPanel.ForegroundColor = [0 0 1];
            app.CONEXINPanel.Title = 'CONEXIÓN';
            app.CONEXINPanel.BackgroundColor = [1 1 1];
            app.CONEXINPanel.FontWeight = 'bold';
            app.CONEXINPanel.FontSize = 16;
            app.CONEXINPanel.Position = [16 482 284 157];

            % Create ConnectButton
            app.ConnectButton = uibutton(app.CONEXINPanel, 'push');
            app.ConnectButton.ButtonPushedFcn = createCallbackFcn(app, @ConnectButtonPushed, true);
            app.ConnectButton.BackgroundColor = [0 0 1];
            app.ConnectButton.FontColor = [1 1 1];
            app.ConnectButton.Position = [16 86 126 33];
            app.ConnectButton.Text = '     Conectar';

            % Create DesconectarButton
            app.DesconectarButton = uibutton(app.CONEXINPanel, 'push');
            app.DesconectarButton.ButtonPushedFcn = createCallbackFcn(app, @DesconectarButtonPushed, true);
            app.DesconectarButton.Position = [16 42 126 33];
            app.DesconectarButton.Text = '     Desconectar';

            % Create EstadoLampLabel
            app.EstadoLampLabel = uilabel(app.CONEXINPanel);
            app.EstadoLampLabel.HorizontalAlignment = 'right';
            app.EstadoLampLabel.Position = [184 98 42 22];
            app.EstadoLampLabel.Text = 'Estado';

            % Create EstadoLamp
            app.EstadoLamp = uilamp(app.CONEXINPanel);
            app.EstadoLamp.Position = [186 57 40 40];
            app.EstadoLamp.Color = [0.651 0.651 0.651];

            % Create conexionLabel
            app.conexionLabel = uilabel(app.CONEXINPanel);
            app.conexionLabel.HorizontalAlignment = 'center';
            app.conexionLabel.Position = [164 32 83 22];
            app.conexionLabel.Text = 'conexion';

            % Create PuertoLabel
            app.PuertoLabel = uilabel(app.CONEXINPanel);
            app.PuertoLabel.Position = [19 12 123 22];
            app.PuertoLabel.Text = 'Puerto:';

            % Create Image2
            app.Image2 = uiimage(app.CONEXINPanel);
            app.Image2.ScaleMethod = 'fill';
            app.Image2.ImageClickedFcn = createCallbackFcn(app, @DesconectarButtonPushed, true);
            app.Image2.Position = [19 43 29 32];
            app.Image2.ImageSource = fullfile(pathToMLAPP, 'Imagenes', 'enlace_rojo.png');

            % Create Image
            app.Image = uiimage(app.CONEXINPanel);
            app.Image.ScaleMethod = 'fill';
            app.Image.ImageClickedFcn = createCallbackFcn(app, @ConnectButtonPushed, true);
            app.Image.Position = [19 86 29 33];
            app.Image.ImageSource = fullfile(pathToMLAPP, 'Imagenes', 'enlace_blanco.png');

            % Create CONTROLPanel
            app.CONTROLPanel = uipanel(app.UIFigure);
            app.CONTROLPanel.ForegroundColor = [0.102 0.302 0.702];
            app.CONTROLPanel.Title = 'CONTROL';
            app.CONTROLPanel.BackgroundColor = [1 1 1];
            app.CONTROLPanel.FontWeight = 'bold';
            app.CONTROLPanel.FontSize = 16;
            app.CONTROLPanel.Position = [16 272 284 196];

            % Create Switch
            app.Switch = uiswitch(app.CONTROLPanel, 'slider');
            app.Switch.Items = {'AUTOMÁTICO', 'MANUAL'};
            app.Switch.ValueChangedFcn = createCallbackFcn(app, @SwitchValueChanged, true);
            app.Switch.Position = [112 125 61 27];
            app.Switch.Value = 'AUTOMÁTICO';

            % Create PotenciaLabel
            app.PotenciaLabel = uilabel(app.CONTROLPanel);
            app.PotenciaLabel.HorizontalAlignment = 'right';
            app.PotenciaLabel.FontSize = 11;
            app.PotenciaLabel.FontWeight = 'bold';
            app.PotenciaLabel.Position = [20 93 71 22];
            app.PotenciaLabel.Text = 'Potencia (%)';

            % Create PotenciaSlider
            app.PotenciaSlider = uislider(app.CONTROLPanel);
            app.PotenciaSlider.ValueChangedFcn = createCallbackFcn(app, @PotenciaSliderValueChanged, true);
            app.PotenciaSlider.FontSize = 10;
            app.PotenciaSlider.Position = [30 79 206 3];

            % Create TemperaturaEditFieldLabel
            app.TemperaturaEditFieldLabel = uilabel(app.CONTROLPanel);
            app.TemperaturaEditFieldLabel.HorizontalAlignment = 'right';
            app.TemperaturaEditFieldLabel.FontSize = 11;
            app.TemperaturaEditFieldLabel.FontWeight = 'bold';
            app.TemperaturaEditFieldLabel.Position = [22 14 138 22];
            app.TemperaturaEditFieldLabel.Text = 'Temperatura objetivo (ºC)';

            % Create TemperaturaobjetivoCEditField
            app.TemperaturaobjetivoCEditField = uieditfield(app.CONTROLPanel, 'numeric');
            app.TemperaturaobjetivoCEditField.ValueChangedFcn = createCallbackFcn(app, @TemperaturaobjetivoCEditFieldValueChanged, true);
            app.TemperaturaobjetivoCEditField.Position = [204 14 39 22];

            % Create GRFICASPanel
            app.GRFICASPanel = uipanel(app.UIFigure);
            app.GRFICASPanel.ForegroundColor = [0.102 0.302 0.702];
            app.GRFICASPanel.Title = 'GRÁFICAS';
            app.GRFICASPanel.BackgroundColor = [1 1 1];
            app.GRFICASPanel.FontWeight = 'bold';
            app.GRFICASPanel.FontSize = 16;
            app.GRFICASPanel.Position = [314 160 480 479];

            % Create UIAxes_2
            app.UIAxes_2 = uiaxes(app.GRFICASPanel);
            title(app.UIAxes_2, 'Title')
            xlabel(app.UIAxes_2, 'X')
            ylabel(app.UIAxes_2, 'Y')
            zlabel(app.UIAxes_2, 'Z')
            app.UIAxes_2.Position = [17 19 448 200];

            % Create UIAxes
            app.UIAxes = uiaxes(app.GRFICASPanel);
            title(app.UIAxes, 'Title')
            xlabel(app.UIAxes, 'X')
            ylabel(app.UIAxes, 'Y')
            zlabel(app.UIAxes, 'Z')
            app.UIAxes.Position = [17 237 453 200];

            % Create TEMPERATURAAMBIENTEPanel
            app.TEMPERATURAAMBIENTEPanel = uipanel(app.UIFigure);
            app.TEMPERATURAAMBIENTEPanel.ForegroundColor = [0.102 0.302 0.702];
            app.TEMPERATURAAMBIENTEPanel.Title = 'TEMPERATURA  AMBIENTE';
            app.TEMPERATURAAMBIENTEPanel.BackgroundColor = [1 1 1];
            app.TEMPERATURAAMBIENTEPanel.FontWeight = 'bold';
            app.TEMPERATURAAMBIENTEPanel.FontSize = 16;
            app.TEMPERATURAAMBIENTEPanel.Position = [16 160 284 98];

            % Create TemperaturaambienteLabel
            app.TemperaturaambienteLabel = uilabel(app.TEMPERATURAAMBIENTEPanel);
            app.TemperaturaambienteLabel.Position = [40 27 133 22];
            app.TemperaturaambienteLabel.Text = 'Temperatura ambiente :';

            % Create TambValorLabel
            app.TambValorLabel = uilabel(app.TEMPERATURAAMBIENTEPanel);
            app.TambValorLabel.FontSize = 14;
            app.TambValorLabel.FontColor = [0 0 0];
            app.TambValorLabel.Position = [199 27 62 22];
            app.TambValorLabel.Text = '... ºC';

            % Create CALIBRACINPanel
            app.CALIBRACINPanel = uipanel(app.UIFigure);
            app.CALIBRACINPanel.ForegroundColor = [0.102 0.302 0.702];
            app.CALIBRACINPanel.Title = 'CALIBRACIÓN';
            app.CALIBRACINPanel.BackgroundColor = [1 1 1];
            app.CALIBRACINPanel.FontWeight = 'bold';
            app.CALIBRACINPanel.FontSize = 16;
            app.CALIBRACINPanel.Position = [16 15 142 131];

            % Create RealizarensayoButton
            app.RealizarensayoButton = uibutton(app.CALIBRACINPanel, 'push');
            app.RealizarensayoButton.ButtonPushedFcn = createCallbackFcn(app, @RealizarensayoButtonPushed, true);
            app.RealizarensayoButton.BackgroundColor = [0.2706 0.2706 1];
            app.RealizarensayoButton.FontColor = [1 1 1];
            app.RealizarensayoButton.Position = [20 39 105 37];
            app.RealizarensayoButton.Text = 'Realizar ensayo';

            % Create MODOOPERATIVOPanel
            app.MODOOPERATIVOPanel = uipanel(app.UIFigure);
            app.MODOOPERATIVOPanel.ForegroundColor = [0.102 0.302 0.702];
            app.MODOOPERATIVOPanel.Title = 'MODO OPERATIVO';
            app.MODOOPERATIVOPanel.BackgroundColor = [1 1 1];
            app.MODOOPERATIVOPanel.FontWeight = 'bold';
            app.MODOOPERATIVOPanel.FontSize = 16;
            app.MODOOPERATIVOPanel.Position = [173 15 173 131];

            % Create NormalButton
            app.NormalButton = uibutton(app.MODOOPERATIVOPanel, 'state');
            app.NormalButton.ValueChangedFcn = createCallbackFcn(app, @NormalButtonValueChanged, true);
            app.NormalButton.Text = '✓  Normal';
            app.NormalButton.BackgroundColor = [0.8784 1 0.8];
            app.NormalButton.Position = [22 66 114 25];

            % Create FallodesensorButton
            app.FallodesensorButton = uibutton(app.MODOOPERATIVOPanel, 'state');
            app.FallodesensorButton.ValueChangedFcn = createCallbackFcn(app, @FallodesensorButtonValueChanged, true);
            app.FallodesensorButton.Text = '⚠  Fallo de sensor';
            app.FallodesensorButton.BackgroundColor = [1 0.8118 0.8118];
            app.FallodesensorButton.Position = [21 23 120 25];

            % Create Image3
            app.Image3 = uiimage(app.UIFigure);
            app.Image3.Position = [6 179 63 38];
            app.Image3.ImageSource = fullfile(pathToMLAPP, 'Imagenes', 'hoja_verde.png');

            % Create INFORMACINPanel
            app.INFORMACINPanel = uipanel(app.UIFigure);
            app.INFORMACINPanel.ForegroundColor = [0.102 0.302 0.702];
            app.INFORMACINPanel.Title = 'INFORMACIÓN';
            app.INFORMACINPanel.BackgroundColor = [1 1 1];
            app.INFORMACINPanel.FontWeight = 'bold';
            app.INFORMACINPanel.FontSize = 16;
            app.INFORMACINPanel.Position = [361 15 260 131];

            % Create TextArea
            app.TextArea = uitextarea(app.INFORMACINPanel);
            app.TextArea.BackgroundColor = [0.9294 0.9647 1];
            app.TextArea.Placeholder = 'Las salidas de texto del sistema se verán aquí.';
            app.TextArea.Position = [24 15 212 69];

            % Create Image4
            app.Image4 = uiimage(app.UIFigure);
            app.Image4.Position = [629 51 172 99];
            app.Image4.ImageSource = fullfile(pathToMLAPP, 'Imagenes', 'logouma3.png');

            % Create Image5
            app.Image5 = uiimage(app.UIFigure);
            app.Image5.Position = [647 10 151 80];
            app.Image5.ImageSource = fullfile(pathToMLAPP, 'Imagenes', 'logouma3eii.png');

            % Mostrar la interfaz una vez creados los componentes
            app.UIFigure.Visible = 'on';
        end
    end

    % Creación y eliminación de la aplicación
    methods (Access = public)

        % Constructor de la aplicación
        function app = interfaz_app

            % Crear la ventana principal y los componentes
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.UIFigure)

            % Execute the startup function
            runStartupFcn(app, @startupFcn)

            if nargout == 0
                clear app
            end
        end

        % Código ejecutado antes de cerrar la aplicación
        function delete(app)

            % Eliminar la ventana al cerrar la aplicación
            delete(app.UIFigure)
        end
    end
end