clear; clc; close all;

% Parámetros antiguos
x_old = [3.9204 0.0078 23.3660];

% Parámetros nuevos
x_new = [4.9102 0.0087 34.7346];

% ==============================
% Cargar ensayos
% ==============================

D = {};
archivos = {
    'ensayos/ensayo_30_40.mat'
    'ensayos/ensayo_40_50.mat'
    'ensayos/ensayo_30_60.mat'
    'ensayos/ensayo_60_30.mat'
    'ensayos/ensayo_calibracion_actual.mat'
};

for i = 1:length(archivos)

    S = load(archivos{i});

    D{end+1}.t = S.t(:);
    D{end}.Q = S.u(:);
    D{end}.T = S.T(:);

    % Tamb constante aproximada
    D{end}.Tamb = S.T(1)*ones(size(S.T(:)));

end

fprintf('\n==============================\n');
fprintf('COMPARACIÓN AJUSTES\n');
fprintf('==============================\n');

RMSE_old_total = 0;
RMSE_new_total = 0;

for i = 1:length(D)

    t = D{i}.t;
    Q = D{i}.Q;
    Treal = D{i}.T;
    Tamb = D{i}.Tamb;

    % Modelo antiguo
    T_old = simular_balance_U_alpha_tau(x_old,t,Q,Treal(1),Tamb);

    % Modelo nuevo
    T_new = simular_balance_U_alpha_tau(x_new,t,Q,Treal(1),Tamb);

    % Errores
    e_old = Treal - T_old;
    e_new = Treal - T_new;

    RMSE_old = sqrt(mean(e_old.^2));
    RMSE_new = sqrt(mean(e_new.^2));

    RMSE_old_total = RMSE_old_total + RMSE_old;
    RMSE_new_total = RMSE_new_total + RMSE_new;

    fprintf('\nENSAYO %d\n',i);
    fprintf('RMSE antiguo = %.3f ºC\n',RMSE_old);
    fprintf('RMSE nuevo   = %.3f ºC\n',RMSE_new);

    % FIGURA
    figure;

    plot(t,Treal,'k','LineWidth',1.8); hold on;
    plot(t,T_old,'r--','LineWidth',1.5);
    plot(t,T_new,'b-.','LineWidth',1.5);

    grid on;

    xlabel('Tiempo [s]');
    ylabel('Temperatura [ºC]');

    legend('Real','Modelo antiguo','Modelo nuevo');

    title(['Comparación modelos - Ensayo ',num2str(i)]);
end

fprintf('\n==============================\n');
fprintf('RMSE TOTAL ACUMULADO\n');
fprintf('==============================\n');

fprintf('Modelo antiguo = %.3f ºC\n',RMSE_old_total);
fprintf('Modelo nuevo   = %.3f ºC\n',RMSE_new_total);

% ==============================
% Ajuste de parámetros [U alpha tau]
% ==============================
x0 = [4.9 0.0087 33];

x_est = fminsearch(@(x) error_total_modelo(x,D), x0);

U     = x_est(1)
alpha = x_est(2)
tau   = x_est(3)

% ==============================
% Validar ensayo por ensayo
% ==============================

for i = 1:length(D)

    t = D{i}.t;
    Q = D{i}.Q;
    Treal = D{i}.T;
    Tamb = D{i}.Tamb;

    Tmod = simular_balance_U_alpha_tau(x_est,t,Q,Treal(1),Tamb);

    error = Treal - Tmod;

    RMSE = sqrt(mean(error.^2));
    MAE  = mean(abs(error));
    MAXE = max(abs(error));

    fprintf('\nENSAYO %d\n', i);
    fprintf('RMSE = %.3f ºC\n', RMSE);
    fprintf('MAE  = %.3f ºC\n', MAE);
    fprintf('MAXE = %.3f ºC\n', MAXE);

    figure;
    plot(t,Treal,'b','LineWidth',1.5); hold on;
    plot(t,Tmod,'r--','LineWidth',1.5);
    grid on;
    xlabel('Tiempo [s]');
    ylabel('Temperatura [ºC]');
    legend('Real','Modelo');
    title(['Ajuste del modelo - Ensayo ', num2str(i)]);

end

U_model = U;
alpha_model = alpha;
tau_sensor = tau;

save('parametros_modelo_TCLab.mat','U_model', 'alpha_model', 'tau_sensor');

function J = error_total_modelo(x,D)

J = 0;

for i = 1:length(D)

    t = D{i}.t;
    Q = D{i}.Q;
    Treal = D{i}.T;
    Tamb = D{i}.Tamb;

    Tmod = simular_balance_U_alpha_tau(x,t,Q,Treal(1),Tamb);

    e = Treal - Tmod;

    J = J + sum(e.^2);

end

end


function TC = simular_balance_U_alpha_tau(x,t,Q,T0,Tamb)

U     = x(1);
alpha = x(2);
tau   = x(3);

% evitar valores no físicos
if U <= 0 || alpha <= 0 || tau <= 0
    TC = 1e6*ones(size(t));
    return
end

% Constantes físicas fijas
m = 0.004;
cp = 500;
A = 0.001;
epsilon = 0.9;
sigma = 5.67e-8;

N = length(t);

TH = zeros(N,1);   % temperatura calentador
TC = zeros(N,1);   % temperatura sensor

TH(1) = T0;
TC(1) = T0;

for k = 1:N-1

    Ts = t(k+1) - t(k);

    THK = TH(k) + 273.15;
    TambK = Tamb(k) + 273.15;

    % Balance energético del calentador
    dTHdt = ( ...
        U*A*(TambK - THK) + ...
        epsilon*sigma*A*(TambK^4 - THK^4) + ...
        alpha*Q(k) ...
        ) / (m*cp);

    % Dinámica del sensor
    dTCdt = (TH(k) - TC(k)) / tau;

    TH(k+1) = TH(k) + Ts*dTHdt;
    TC(k+1) = TC(k) + Ts*dTCdt;

end

end