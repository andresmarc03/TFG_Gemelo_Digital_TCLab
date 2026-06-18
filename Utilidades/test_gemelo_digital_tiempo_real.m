clear; clc; close all;

% Asegurar TCLab cargado
if ~exist('a','var')
    run('tclab.m');
end

% Parámetros modelo físico identificado
U = 2.5171;
alpha = 0.0068;

% Constantes físicas
m = 0.004;
cp = 500;
A = 0.001;
epsilon = 0.9;
sigma = 5.67e-8;

% Configuración ensayo
Ts = 1;              % s
duracion = 900;      % 15 min

% Perfil de prueba
Q_profile = [0 30 50 20 0];
durations = [60 240 240 240 120];

N_total = sum(durations)/Ts;

t_data = zeros(N_total,1);
Treal_data = zeros(N_total,1);
Tvirt_data = zeros(N_total,1);
Q_data = zeros(N_total,1);
error_data = zeros(N_total,1);

% Condiciones iniciales
T0 = T1C();
Tamb = T0;
Tvirt = T0;

fprintf('Temperatura inicial/ambiente: %.2f ºC\n', Tamb);

k = 1;
tic;

figure;

for i = 1:length(Q_profile)

    Q = Q_profile(i);
    h1(Q);

    N = durations(i)/Ts;

    fprintf('Aplicando Q = %.1f %% durante %.0f s\n', Q, durations(i));

    for j = 1:N

        t = toc;
        Treal = T1C();

        % Modelo físico completo
        Tk = Tvirt + 273.15;
        TambK = Tamb + 273.15;

        dTdt = ( ...
            U*A*(TambK - Tk) + ...
            epsilon*sigma*A*(TambK^4 - Tk^4) + ...
            alpha*Q ...
            ) / (m*cp);

        Tvirt = Tvirt + Ts*dTdt;

        % Guardar datos
        t_data(k) = t;
        Treal_data(k) = Treal;
        Tvirt_data(k) = Tvirt;
        Q_data(k) = Q;
        error_data(k) = Treal - Tvirt;

        % Graficar en vivo
        subplot(2,1,1);
        plot(t_data(1:k), Treal_data(1:k), 'b', 'LineWidth', 1.5); hold on;
        plot(t_data(1:k), Tvirt_data(1:k), 'r--', 'LineWidth', 1.5); hold off;
        grid on;
        xlabel('Tiempo [s]');
        ylabel('Temperatura [ºC]');
        legend('Real','Gemelo digital','Location','best');
        title('TCLab real vs modelo físico');

        subplot(2,1,2);
        plot(t_data(1:k), Q_data(1:k), 'k', 'LineWidth', 1.5);
        grid on;
        xlabel('Tiempo [s]');
        ylabel('Potencia [%]');
        title('Entrada al calentador');

        drawnow limitrate;

        fprintf('t = %.1f s | Q = %.1f %% | Treal = %.2f | Tvirt = %.2f | error = %.2f\n', ...
            t, Q, Treal, Tvirt, Treal - Tvirt);

        k = k + 1;
        pause(Ts);
    end
end

% Apagar
h1(0);

% Recortar por si acaso
t_data = t_data(1:k-1);
Treal_data = Treal_data(1:k-1);
Tvirt_data = Tvirt_data(1:k-1);
Q_data = Q_data(1:k-1);
error_data = error_data(1:k-1);

RMSE = sqrt(mean(error_data.^2));
MAE = mean(abs(error_data));
MAXE = max(abs(error_data));

fprintf('\nRESULTADOS:\n');
fprintf('RMSE = %.3f ºC\n', RMSE);
fprintf('MAE  = %.3f ºC\n', MAE);
fprintf('MAXE = %.3f ºC\n', MAXE);

datos_test_gemelo = table(t_data,Treal_data,Tvirt_data,Q_data,error_data, ...
    'VariableNames', {'t','Treal','Tvirtual','Q','error'});

save('datos_test_gemelo_tiempo_real.mat','datos_test_gemelo');
writetable(datos_test_gemelo,'datos_test_gemelo_tiempo_real.csv');