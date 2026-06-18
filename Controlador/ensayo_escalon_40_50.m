clear; clc;

% Cargar TCLab
run('tclab.m');

% Parámetros del ensayo
u0 = 40;      % potencia inicial
u1 = 50;      % escalón
Ts = 1;       % tiempo de muestreo [s]
t1 = 1200;    % tiempo a 40%
t2 = 1200;    % tiempo adicional a 50%

% Tiempo total
t_total = t1 + t2;
t = 0:Ts:t_total;
t_step = t1;

% Reservar memoria
T = zeros(size(t));
u = zeros(size(t));

disp('Comenzando ensayo...')

try
    for k = 1:length(t)

        if t(k) < t1
            u(k) = u0;
        else
            u(k) = u1;
        end

        h1(u(k));
        T(k) = T1C();

        fprintf('t = %.0f s | u = %.1f %% | T = %.2f C\n', t(k), u(k), T(k));

        pause(Ts);
    end

catch ME
    h1(0);
    rethrow(ME);
end

% Apagar heater al terminar
h1(0);

% Guardar datos
save('datos_ensayo_tclab.mat', 't', 'u', 'T', 't_step', 'u0', 'u1', 'Ts', 't1', 't2');

% Graficar entrada
figure;
plot(t, u, 'LineWidth', 1.5);
grid on;
xlabel('Tiempo (s)');
ylabel('Potencia (%)');
title('Entrada aplicada');

% Graficar salida
figure;
plot(t, T, 'LineWidth', 1.5);
grid on;
xlabel('Tiempo (s)');
ylabel('Temperatura (°C)');
title('Respuesta de temperatura');
