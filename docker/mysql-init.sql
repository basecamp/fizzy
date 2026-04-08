-- Fizzy production 所需数据库（Rails db:prepare 会执行迁移）
CREATE DATABASE IF NOT EXISTS fizzy_production;
CREATE DATABASE IF NOT EXISTS fizzy_production_cable;
CREATE DATABASE IF NOT EXISTS fizzy_production_queue;
CREATE DATABASE IF NOT EXISTS fizzy_production_cache;
GRANT ALL PRIVILEGES ON fizzy_production.* TO 'fizzy'@'%';
GRANT ALL PRIVILEGES ON fizzy_production_cable.* TO 'fizzy'@'%';
GRANT ALL PRIVILEGES ON fizzy_production_queue.* TO 'fizzy'@'%';
GRANT ALL PRIVILEGES ON fizzy_production_cache.* TO 'fizzy'@'%';
FLUSH PRIVILEGES;
