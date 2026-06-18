clear; clc;
load('datos_ensayo_tclab.mat');

idx_step = find(diff(u) ~= 0, 1) + 1;
t_step = t(idx_step);

figure;
plot(t,T,'LineWidth',1.5);
grid on;
xlabel('Tiempo (s)');
ylabel('Temperatura (°C)');
title('Respuesta del sistema');
hold on;
xline(t_step,'--r','Escalón');

T0 = mean(T(idx_step-50:idx_step-1));
Tf = mean(T(end-50:end));

u0 = u(idx_step-1);
u1 = u(idx_step);

du = u1 - u0;
dT = Tf - T0;

K = dT/du;

T63 = T0 + 0.632*dT;
idx_tau = find(T(idx_step:end) >= T63,1) + idx_step - 1;
tau = t(idx_tau) - t_step;

G = tf(K,[tau 1])
