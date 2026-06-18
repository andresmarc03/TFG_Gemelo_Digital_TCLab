clear all;
clc;

%% CONEXIÓN TCLAB
if ~exist('a','var')
    run('tclab.m');
end

   

%% PARÁMETROS
pot1 = 30;     % potencia inicial
pot2 = 40;     % potencia final

t_est1 = 900;  % tiempo estabilización
t_est2 = 900;  % tiempo segundo escalón

Ts = 2;        % tiempo muestreo

%% VECTORES
t = [];
T = [];
u = [];

disp('Inicio ensayo...');

tic;

%% FASE 1 -> 30%
h1(pot1);

while toc < t_est1
    
    tiempo = toc;
    temp = T1C();

    t(end+1) = tiempo;
    T(end+1) = temp;
    u(end+1) = pot1;

    fprintf('t = %.1f s | T = %.2f ºC\n', tiempo, temp);

    pause(Ts);
end

%% FASE 2 -> 40%
disp('Cambiando a 40%...');

h1(pot2);

while toc < (t_est1 + t_est2)
    
    tiempo = toc;
    temp = T1C();

    t(end+1) = tiempo;
    T(end+1) = temp;
    u(end+1) = pot2;

    fprintf('t = %.1f s | T = %.2f ºC\n', tiempo, temp);

    pause(Ts);
end

%% APAGAR
h1(0);

disp('Ensayo terminado');

%% GUARDAR
save('ensayos/ensayo_30_40.mat','t','T','u');

%% GRÁFICA
figure;

subplot(2,1,1)
plot(t,T,'LineWidth',2)
grid on
ylabel('Temperatura (ºC)')
title('Ensayo 30% -> 40%')

subplot(2,1,2)
plot(t,u,'LineWidth',2)
grid on
ylabel('Potencia (%)')
xlabel('Tiempo (s)')