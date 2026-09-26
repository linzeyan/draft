-- MySQL dump 10.13  Distrib 8.0.36, for macos14.2 (arm64)
--
-- Shaped like mysqldump output: backticks, version-gated /*! */ comments,
-- inline keys, and a foreign key to a table this file does not define.
--
/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET NAMES utf8mb4 */;

DROP TABLE IF EXISTS `customer`;
CREATE TABLE `customer` (
  `customer_id` smallint unsigned NOT NULL AUTO_INCREMENT,
  `store_id` tinyint unsigned NOT NULL,
  `first_name` varchar(45) NOT NULL,
  `last_name` varchar(45) NOT NULL,
  `email` varchar(50) DEFAULT NULL,
  `active` tinyint(1) NOT NULL DEFAULT '1',
  `notes` text COMMENT 'free text, may contain ; and -- and even ) characters',
  `create_date` datetime NOT NULL,
  PRIMARY KEY (`customer_id`),
  UNIQUE KEY `idx_email` (`email`),
  KEY `idx_fk_store_id` (`store_id`),
  FULLTEXT KEY `idx_names` (`first_name`,`last_name`),
  CONSTRAINT `fk_customer_store` FOREIGN KEY (`store_id`) REFERENCES `store` (`store_id`) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `payment`;
CREATE TABLE `payment` (
  `payment_id` smallint unsigned NOT NULL AUTO_INCREMENT,
  `customer_id` smallint unsigned NOT NULL,
  `amount` decimal(5, 2) NOT NULL,
  `payment_date` datetime NOT NULL,
  PRIMARY KEY (`payment_id`),
  CONSTRAINT `fk_payment_customer` FOREIGN KEY (`customer_id`) REFERENCES `customer` (`customer_id`)
) ENGINE=InnoDB;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
