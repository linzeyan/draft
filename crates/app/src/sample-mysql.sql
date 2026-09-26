-- A small blog, written the way MySQL writes: backticked names,
-- `AUTO_INCREMENT` keys, and the table options the server stores. Paste your
-- own schema over it, or drop a .sql file anywhere on this window.

CREATE TABLE `author` (
  `id`            int unsigned NOT NULL AUTO_INCREMENT,
  `handle`        varchar(32) NOT NULL,
  `display_name`  varchar(96) NOT NULL,
  `email`         varchar(190) NOT NULL,
  `joined_at`     datetime NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_author_handle` (`handle`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `category` (
  `id`         int unsigned NOT NULL AUTO_INCREMENT,
  `parent_id`  int unsigned DEFAULT NULL,  -- a table may point at itself
  `slug`       varchar(64) NOT NULL,
  `title`      varchar(120) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_category_slug` (`slug`),
  CONSTRAINT `fk_category_parent` FOREIGN KEY (`parent_id`) REFERENCES `category` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `post` (
  `id`            bigint unsigned NOT NULL AUTO_INCREMENT,
  `author_id`     int unsigned NOT NULL,
  `category_id`   int unsigned DEFAULT NULL,
  `slug`          varchar(160) NOT NULL,
  `title`         varchar(200) NOT NULL,
  `body`          mediumtext NOT NULL,
  `published`     tinyint(1) NOT NULL DEFAULT '0',
  `published_at`  datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_post_slug` (`slug`),
  KEY `idx_post_author` (`author_id`),
  FULLTEXT KEY `idx_post_search` (`title`,`body`),
  CONSTRAINT `fk_post_author` FOREIGN KEY (`author_id`) REFERENCES `author` (`id`),
  CONSTRAINT `fk_post_category` FOREIGN KEY (`category_id`) REFERENCES `category` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `revision` (
  `id`         bigint unsigned NOT NULL AUTO_INCREMENT,
  `post_id`    bigint unsigned NOT NULL,
  `editor_id`  int unsigned NOT NULL,
  `body`       mediumtext NOT NULL,
  `saved_at`   datetime NOT NULL,
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_revision_post` FOREIGN KEY (`post_id`) REFERENCES `post` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_revision_editor` FOREIGN KEY (`editor_id`) REFERENCES `author` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `comment` (
  `id`          bigint unsigned NOT NULL AUTO_INCREMENT,
  `post_id`     bigint unsigned NOT NULL,
  `author_id`   int unsigned DEFAULT NULL,
  `guest_name`  varchar(96) DEFAULT NULL,
  `body`        text NOT NULL,
  `approved`    tinyint(1) NOT NULL DEFAULT '0',
  `posted_at`   datetime NOT NULL,
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_comment_post` FOREIGN KEY (`post_id`) REFERENCES `post` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_comment_author` FOREIGN KEY (`author_id`) REFERENCES `author` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `tag` (
  `id`    int unsigned NOT NULL AUTO_INCREMENT,
  `slug`  varchar(48) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_tag_slug` (`slug`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `post_tag` (
  `post_id`  bigint unsigned NOT NULL,
  `tag_id`   int unsigned NOT NULL,
  PRIMARY KEY (`post_id`,`tag_id`),
  CONSTRAINT `fk_post_tag_post` FOREIGN KEY (`post_id`) REFERENCES `post` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_post_tag_tag` FOREIGN KEY (`tag_id`) REFERENCES `tag` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `media` (
  `id`       bigint unsigned NOT NULL AUTO_INCREMENT,
  `post_id`  bigint unsigned DEFAULT NULL,
  `path`     varchar(255) NOT NULL,
  `mime`     varchar(64) NOT NULL,
  `bytes`    int unsigned NOT NULL,
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_media_post` FOREIGN KEY (`post_id`) REFERENCES `post` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
