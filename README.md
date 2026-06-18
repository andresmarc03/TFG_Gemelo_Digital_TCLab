# TFG Gemelo Digital TCLab

Este repositorio contiene el código desarrollado para el Trabajo Fin de Grado titulado **Gemelo Digital de una plataforma de ensayos TCLab**.

El proyecto incluye una aplicación desarrollada en MATLAB App Designer para la conexión con la plataforma TCLab, la ejecución de un modelo térmico virtual, la implementación de un controlador PI, la calibración experimental del modelo y la detección de fallos simulados de sensor.

## Estructura del repositorio

- `interfaz_app.mlapp`: aplicación principal desarrollada en MATLAB App Designer.
- `tclab.m`: script necesario para establecer la comunicación con la plataforma TCLab.
- `parametros_modelo_TCLab.mat`: parámetros ajustados del modelo térmico.
- `temperatura_ambiente_TCLab.mat`: temperatura ambiente utilizada por el modelo.
- `Controlador/`: scripts y datos utilizados para la identificación de la planta y el cálculo del controlador PI.
- `ensayos/`: ensayos experimentales empleados para la calibración y validación del modelo térmico.
- `Imagenes/`: recursos gráficos utilizados por la interfaz.
- `Utilidades/`: scripts auxiliares para pruebas básicas del TCLab.

## Requisitos

- MATLAB.
- MATLAB App Designer.
- MATLAB Support Package for Arduino Hardware.
- Plataforma TCLab conectada por USB.

## Ejecución

1. Abrir MATLAB.
2. Situarse en la carpeta principal del repositorio.
3. Abrir el archivo `interfaz_app.mlapp`.
4. Ejecutar la aplicación.
5. Pulsar el botón **Conectar** para establecer la comunicación con el TCLab.
