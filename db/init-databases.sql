-- Script de inicialización para crear todas las bases de datos necesarias
-- Este script se ejecuta automáticamente cuando el contenedor MySQL se inicia por primera vez

CREATE DATABASE IF NOT EXISTS fizzy_production;
CREATE DATABASE IF NOT EXISTS fizzy_production_cable;
CREATE DATABASE IF NOT EXISTS fizzy_production_queue;
CREATE DATABASE IF NOT EXISTS fizzy_production_cache;

GRANT ALL PRIVILEGES ON fizzy_production.* TO 'root'@'%';
GRANT ALL PRIVILEGES ON fizzy_production_cable.* TO 'root'@'%';
GRANT ALL PRIVILEGES ON fizzy_production_queue.* TO 'root'@'%';
GRANT ALL PRIVILEGES ON fizzy_production_cache.* TO 'root'@'%';

FLUSH PRIVILEGES;
