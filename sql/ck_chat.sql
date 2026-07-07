CREATE TABLE IF NOT EXISTS `ck_chat_profiles` (
  `identifier` varchar(80) NOT NULL,
  `chat_frame_id` varchar(100) NOT NULL DEFAULT '',
  `chat_box_frame_id` varchar(100) NOT NULL DEFAULT '',
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
