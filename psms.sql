-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1
-- Generation Time: Feb 20, 2026 at 08:03 AM
-- Server version: 10.4.32-MariaDB
-- PHP Version: 8.0.30

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `psms`
--

DELIMITER $$
--
-- Procedures
--
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_get_system_stats` ()   BEGIN
    SELECT 
        (SELECT COUNT(*) FROM boxes) AS total_boxes,
        (SELECT COUNT(*) FROM boxes WHERE status = 'stored') AS boxes_stored,
        (SELECT COUNT(*) FROM boxes WHERE status = 'retrieved') AS boxes_retrieved,
        (SELECT COUNT(*) FROM boxes WHERE status = 'destroyed') AS boxes_destroyed,
        (SELECT COUNT(*) FROM boxes WHERE destruction_year <= YEAR(CURDATE()) AND status = 'stored') AS boxes_pending_destruction,
        (SELECT COUNT(*) FROM clients WHERE is_active = TRUE) AS total_clients,
        (SELECT COUNT(*) FROM users WHERE is_active = TRUE) AS total_users,
        (SELECT COUNT(*) FROM users WHERE role = 'admin' AND is_active = TRUE) AS admin_users,
        (SELECT COUNT(*) FROM users WHERE role = 'staff' AND is_active = TRUE) AS staff_users,
        (SELECT COUNT(*) FROM users WHERE role = 'client' AND is_active = TRUE) AS client_users,
        (SELECT COUNT(*) FROM requests WHERE status = 'pending') AS pending_requests,
        (SELECT COUNT(*) FROM collections WHERE DATE(created_at) = CURDATE()) AS today_collections,
        (SELECT COUNT(*) FROM retrievals WHERE DATE(created_at) = CURDATE()) AS today_retrievals,
        (SELECT COUNT(*) FROM deliveries WHERE DATE(created_at) = CURDATE()) AS today_deliveries;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_update_daily_stats` (IN `p_date` DATE)   BEGIN
    INSERT INTO daily_stats (
        stat_date,
        total_boxes,
        total_clients,
        boxes_stored,
        boxes_retrieved,
        boxes_destroyed,
        collections_count,
        retrievals_count,
        deliveries_count,
        active_users
    ) VALUES (
        p_date,
        (SELECT COUNT(*) FROM boxes WHERE DATE(created_at) <= p_date),
        (SELECT COUNT(*) FROM clients WHERE is_active = TRUE AND DATE(created_at) <= p_date),
        (SELECT COUNT(*) FROM boxes WHERE status = 'stored' AND DATE(created_at) <= p_date),
        (SELECT COUNT(*) FROM boxes WHERE status = 'retrieved' AND DATE(updated_at) <= p_date),
        (SELECT COUNT(*) FROM boxes WHERE status = 'destroyed' AND DATE(updated_at) <= p_date),
        (SELECT COUNT(*) FROM collections WHERE DATE(created_at) = p_date),
        (SELECT COUNT(*) FROM retrievals WHERE DATE(created_at) = p_date),
        (SELECT COUNT(*) FROM deliveries WHERE DATE(created_at) = p_date),
        (SELECT COUNT(*) FROM users WHERE is_active = TRUE AND DATE(created_at) <= p_date)
    )
    ON DUPLICATE KEY UPDATE
        total_boxes = VALUES(total_boxes),
        total_clients = VALUES(total_clients),
        boxes_stored = VALUES(boxes_stored),
        boxes_retrieved = VALUES(boxes_retrieved),
        boxes_destroyed = VALUES(boxes_destroyed),
        collections_count = VALUES(collections_count),
        retrievals_count = VALUES(retrievals_count),
        deliveries_count = VALUES(deliveries_count),
        active_users = VALUES(active_users);
END$$

DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `audit_logs`
--

CREATE TABLE `audit_logs` (
  `audit_id` int(11) NOT NULL,
  `user_id` int(11) DEFAULT NULL COMMENT 'User who performed the action',
  `action` varchar(100) NOT NULL COMMENT 'Action performed (CREATE, UPDATE, DELETE, LOGIN, etc)',
  `entity_type` varchar(50) NOT NULL COMMENT 'Type of entity affected (box, user, collection, etc)',
  `entity_id` int(11) DEFAULT NULL COMMENT 'ID of affected entity',
  `old_value` text DEFAULT NULL COMMENT 'JSON of old values (for updates)',
  `new_value` text DEFAULT NULL COMMENT 'JSON of new values',
  `ip_address` varchar(50) DEFAULT NULL COMMENT 'IP address of user',
  `user_agent` varchar(500) DEFAULT NULL COMMENT 'Browser/device user agent',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci COMMENT='Comprehensive audit trail for all system actions';

--
-- Dumping data for table `audit_logs`
--

INSERT INTO `audit_logs` (`audit_id`, `user_id`, `action`, `entity_type`, `entity_id`, `old_value`, `new_value`, `ip_address`, `user_agent`, `created_at`) VALUES
(1, 1, 'LOGIN', 'auth', 1, NULL, '{\"username\":\"admin\",\"role\":\"admin\"}', '127.0.0.1', NULL, '2025-11-18 11:11:04'),
(2, 2, 'CREATE_BOX', 'box', 1, NULL, '{\"box_number\":\"BOX-001-2024\",\"client_id\":1}', '127.0.0.1', NULL, '2025-11-18 11:11:04'),
(3, 2, 'CREATE_COLLECTION', 'collection', 1, NULL, '{\"client_id\":1,\"total_boxes\":5}', '127.0.0.1', NULL, '2025-11-18 11:11:04'),
(4, 1, 'LOGIN', 'auth', NULL, NULL, '{\"username\":\"admin\",\"role\":\"admin\"}', '::1', 'PostmanRuntime/7.49.0', '2025-11-19 01:54:09'),
(5, 1, 'LOGIN', 'auth', NULL, NULL, '{\"username\":\"admin\",\"role\":\"admin\"}', '::ffff:127.0.0.1', 'Dart/3.7 (dart:io)', '2025-11-19 20:18:45'),
(6, 1, 'LOGIN', 'auth', NULL, NULL, '{\"username\":\"admin\",\"role\":\"admin\"}', '::ffff:127.0.0.1', 'Dart/3.7 (dart:io)', '2025-11-19 20:19:03'),
(7, 1, 'LOGIN', 'auth', NULL, NULL, '{\"username\":\"admin\",\"role\":\"admin\"}', '::ffff:127.0.0.1', 'Dart/3.7 (dart:io)', '2025-11-19 20:20:43'),
(8, 1, 'LOGIN', 'auth', NULL, NULL, '{\"username\":\"admin\",\"role\":\"admin\"}', '::ffff:127.0.0.1', 'Dart/3.7 (dart:io)', '2025-11-19 20:22:18'),
(9, 1, 'LOGIN', 'auth', NULL, NULL, '{\"username\":\"admin\",\"role\":\"admin\"}', '::ffff:127.0.0.1', 'Dart/3.7 (dart:io)', '2025-11-19 20:24:12'),
(10, 1, 'LOGIN', 'auth', NULL, NULL, '{\"username\":\"admin\",\"role\":\"admin\"}', '::ffff:127.0.0.1', 'Dart/3.7 (dart:io)', '2025-11-19 20:25:22'),
(11, 1, 'LOGIN', 'auth', NULL, NULL, '{\"username\":\"admin\",\"role\":\"admin\"}', '::ffff:127.0.0.1', 'Dart/3.7 (dart:io)', '2025-11-19 20:50:14'),
(12, 1, 'LOGIN', 'auth', NULL, NULL, '{\"username\":\"admin\",\"role\":\"admin\"}', '::ffff:127.0.0.1', 'Dart/3.7 (dart:io)', '2025-11-19 21:21:34'),
(13, 1, 'LOGIN', 'auth', NULL, NULL, '{\"username\":\"admin\",\"role\":\"admin\"}', '::ffff:127.0.0.1', 'Dart/3.7 (dart:io)', '2025-11-19 21:22:30'),
(14, 1, 'UPDATE', 'user', 3, '{\"user_id\":3,\"username\":\"client1\",\"email\":\"client@acme.com\",\"password_hash\":\"$2b$10$YQ98PzLpzz5zZZ5zZZ5zZO8RQXkK1b3eMJ9Zg7yZZ5zZZ5zZZ5zZZ\",\"role\":\"client\",\"client_id\":1,\"is_active\":1,\"created_at\":\"2025-11-18T11:11:04.000Z\",\"updated_at\":\"2025-11-18T11:11:04.000Z\"}', '{\"username\":\"client1\",\"email\":\"client@acme.com\",\"role\":\"client\",\"client_id\":1}', '::ffff:127.0.0.1', NULL, '2025-11-19 21:28:12'),
(15, 1, 'UPDATE', 'user', 3, '{\"user_id\":3,\"username\":\"client1\",\"email\":\"client@acme.com\",\"password_hash\":\"$2b$10$YQ98PzLpzz5zZZ5zZZ5zZO8RQXkK1b3eMJ9Zg7yZZ5zZZ5zZZ5zZZ\",\"role\":\"client\",\"client_id\":1,\"is_active\":1,\"created_at\":\"2025-11-18T11:11:04.000Z\",\"updated_at\":\"2025-11-19T21:28:12.000Z\"}', '{\"username\":\"client1\",\"email\":\"client@acme.com\",\"role\":\"client\",\"client_id\":1}', '::ffff:127.0.0.1', NULL, '2025-11-19 21:28:59'),
(16, 1, 'UPDATE', 'user', 3, '{\"user_id\":3,\"username\":\"client1\",\"email\":\"client@acme.com\",\"password_hash\":\"$2b$10$YQ98PzLpzz5zZZ5zZZ5zZO8RQXkK1b3eMJ9Zg7yZZ5zZZ5zZZ5zZZ\",\"role\":\"client\",\"client_id\":1,\"is_active\":1,\"created_at\":\"2025-11-18T11:11:04.000Z\",\"updated_at\":\"2025-11-19T21:28:59.000Z\"}', '{\"username\":\"client1\",\"email\":\"client@acme.com\",\"role\":\"client\",\"client_id\":1}', '::ffff:127.0.0.1', NULL, '2025-11-19 21:29:15'),
(17, 1, 'UPDATE', 'user', 3, '{\"user_id\":3,\"username\":\"client1\",\"email\":\"client@acme.com\",\"password_hash\":\"$2b$10$YQ98PzLpzz5zZZ5zZZ5zZO8RQXkK1b3eMJ9Zg7yZZ5zZZ5zZZ5zZZ\",\"role\":\"client\",\"client_id\":1,\"is_active\":1,\"created_at\":\"2025-11-18T11:11:04.000Z\",\"updated_at\":\"2025-11-19T21:29:15.000Z\"}', '{\"username\":\"client1\",\"email\":\"client@acme.com\",\"role\":\"client\",\"client_id\":1}', '::ffff:127.0.0.1', NULL, '2025-11-19 21:29:32'),
(18, 1, 'LOGOUT', 'auth', NULL, NULL, NULL, '::ffff:127.0.0.1', NULL, '2025-11-19 21:31:13'),
(19, 1, 'LOGIN', 'auth', NULL, NULL, '{\"username\":\"admin\",\"role\":\"admin\"}', '::ffff:127.0.0.1', 'Dart/3.7 (dart:io)', '2025-11-20 07:45:42'),
(20, 1, 'LOGIN', 'auth', NULL, NULL, '{\"username\":\"admin\",\"role\":\"admin\"}', '::ffff:127.0.0.1', 'Dart/3.7 (dart:io)', '2026-01-08 14:37:37'),
(21, 1, 'LOGOUT', 'auth', NULL, NULL, NULL, '::ffff:127.0.0.1', NULL, '2026-01-08 14:49:49'),
(22, 1, 'LOGIN', 'auth', NULL, NULL, '{\"username\":\"admin\",\"role\":\"admin\"}', '::ffff:127.0.0.1', 'Dart/3.7 (dart:io)', '2026-01-13 10:45:31'),
(23, 1, 'LOGIN', 'auth', NULL, NULL, '{\"username\":\"admin\",\"role\":\"admin\"}', '::ffff:127.0.0.1', 'Dart/3.6 (dart:io)', '2026-02-11 00:16:29'),
(24, 1, 'UPDATE_COLLECTION', 'collection', 1, '{\"collection_id\":1,\"client_id\":1,\"total_boxes\":5,\"box_description\":\"Financial and HR records for 2024\",\"dispatcher_name\":\"John Smith\",\"collector_name\":\"Staff Member\",\"dispatcher_signature\":null,\"collector_signature\":null,\"collection_date\":\"2024-11-14T22:00:00.000Z\",\"pdf_path\":null,\"created_by\":2,\"created_at\":\"2025-11-18T11:11:04.000Z\"}', '{\"totalBoxes\":5,\"boxDescription\":\"Financial and HR records for 2024\",\"dispatcherName\":\"admin\",\"collectorName\":\"client1\",\"collectionDate\":\"2024-11-15\"}', '::ffff:127.0.0.1', 'Dart/3.6 (dart:io)', '2026-02-11 00:17:01'),
(25, 1, 'LOGIN', 'auth', NULL, NULL, '{\"username\":\"admin\",\"role\":\"admin\"}', '::1', 'PostmanRuntime/7.51.1', '2026-02-11 10:53:28'),
(26, 1, 'CREATE_RETRIEVAL', 'retrieval', 2, NULL, '{\"clientId\":1,\"boxId\":2,\"retrievalDate\":\"2025-02-15\",\"boxNumber\":\"BOX-002-2024\",\"status\":\"pending_signature\"}', '::1', 'PostmanRuntime/7.51.1', '2026-02-11 19:20:21'),
(27, 1, 'LOGIN', 'auth', NULL, NULL, '{\"username\":\"admin\",\"role\":\"admin\"}', '::ffff:127.0.0.1', 'Dart/3.6 (dart:io)', '2026-02-11 19:29:42'),
(28, 1, 'BOX_STATUS_CHANGE_ON_RETRIEVAL', 'box', 2, '{\"status\":\"stored\"}', '{\"status\":\"retrieved\",\"triggeredBy\":\"client_signature\",\"retrievalId\":\"2\"}', '::1', 'PostmanRuntime/7.51.1', '2026-02-11 19:34:36'),
(29, 1, 'UPDATE_RETRIEVAL_SIGNATURES', 'retrieval', 2, '{\"hadClientSignature\":false,\"hadStaffSignature\":true}', '{\"hasClientSignature\":true,\"hasStaffSignature\":true,\"boxStatusChanged\":true,\"newBoxStatus\":\"retrieved\"}', '::1', 'PostmanRuntime/7.51.1', '2026-02-11 19:34:36'),
(30, 1, 'LOGIN', 'auth', NULL, NULL, '{\"username\":\"admin\",\"role\":\"admin\"}', '::1', 'PostmanRuntime/7.51.1', '2026-02-11 19:39:59'),
(31, 1, 'UPDATE_REQUEST_STATUS', 'request', 1, '{\"status\":\"pending\"}', '{\"status\":\"approved\"}', '::1', 'PostmanRuntime/7.51.1', '2026-02-11 19:41:11'),
(32, 1, 'UPDATE_RETRIEVAL_SIGNATURES', 'retrieval', 1, '{\"hadClientSignature\":false,\"hadStaffSignature\":false}', '{\"hasClientSignature\":false,\"hasStaffSignature\":true,\"boxStatusChanged\":false,\"newBoxStatus\":\"stored\"}', '::ffff:127.0.0.1', 'Dart/3.6 (dart:io)', '2026-02-11 22:09:23'),
(33, 1, 'UPDATE_RETRIEVAL_SIGNATURES', 'retrieval', 2, '{\"hadClientSignature\":true,\"hadStaffSignature\":true}', '{\"hasClientSignature\":true,\"hasStaffSignature\":true,\"boxStatusChanged\":false,\"newBoxStatus\":\"retrieved\"}', '::ffff:127.0.0.1', 'Dart/3.6 (dart:io)', '2026-02-12 22:48:59'),
(34, 1, 'UPDATE_RETRIEVAL_SIGNATURES', 'retrieval', 2, '{\"hadClientSignature\":true,\"hadStaffSignature\":true}', '{\"hasClientSignature\":true,\"hasStaffSignature\":true,\"boxStatusChanged\":false,\"newBoxStatus\":\"retrieved\"}', '::ffff:127.0.0.1', 'Dart/3.6 (dart:io)', '2026-02-12 22:49:15'),
(35, 1, 'CREATE_BOX', 'box', 16, NULL, '{\"boxNumber\":\"BOX-CLI-002-GLOBAL8822\",\"clientId\":2,\"boxIndex\":\"GLOBAL8822\",\"rackingLabelId\":1,\"retentionYears\":4}', '::ffff:127.0.0.1', 'Dart/3.6 (dart:io)', '2026-02-18 11:17:32'),
(36, 1, 'UPDATE_RETRIEVAL_SIGNATURES', 'retrieval', 2, '{\"hadClientSignature\":true,\"hadStaffSignature\":true}', '{\"hasClientSignature\":true,\"hasStaffSignature\":true,\"boxStatusChanged\":false,\"newBoxStatus\":\"retrieved\"}', '::ffff:127.0.0.1', 'Dart/3.6 (dart:io)', '2026-02-18 11:38:07'),
(37, 1, 'CREATE_BOX', 'box', 17, NULL, '{\"boxNumber\":\"BOX-CLI-004-PREMIUM6820\",\"clientId\":4,\"boxIndex\":\"PREMIUM6820\",\"rackingLabelId\":15,\"retentionYears\":6}', '::ffff:127.0.0.1', 'Dart/3.6 (dart:io)', '2026-02-18 11:45:56'),
(38, 1, 'CREATE', 'storage_location', 16, 'null', '{\"label_id\":16,\"label_code\":\"RACK-A23\",\"location_description\":\"Matsapha Warehouse - section1\",\"is_available\":1,\"created_at\":\"2026-02-18T11:47:04.000Z\",\"updated_at\":\"2026-02-18T11:47:04.000Z\"}', '::ffff:127.0.0.1', 'Dart/3.6 (dart:io)', '2026-02-18 11:47:04'),
(39, 1, 'CREATE', 'storage_location', 17, 'null', '{\"label_id\":17,\"label_code\":\"RACK-A27\",\"location_description\":\"Matsapha Warehouse - section1\",\"is_available\":1,\"created_at\":\"2026-02-18T11:47:13.000Z\",\"updated_at\":\"2026-02-18T11:47:13.000Z\"}', '::ffff:127.0.0.1', 'Dart/3.6 (dart:io)', '2026-02-18 11:47:13'),
(40, 1, 'UPDATE_BOX', 'box', 17, '{\"box_description\":\"Statements for years: 2023 - 2025\",\"racking_label_id\":15,\"retention_years\":6}', '{\"boxDescription\":\"Statements for years: 2023 - 2025\",\"rackingLabelId\":16,\"retentionYears\":6}', '::ffff:127.0.0.1', 'Dart/3.6 (dart:io)', '2026-02-18 11:47:54'),
(41, 1, 'DELETE_BOX', 'box', 17, '{\"box_number\":\"BOX-CLI-004-PREMIUM6820\"}', NULL, '::ffff:127.0.0.1', 'Dart/3.6 (dart:io)', '2026-02-18 20:45:15'),
(42, 1, 'CREATE_BOX', 'box', 18, NULL, '{\"boxNumber\":\"CLI-004-PREMIUM6822\",\"clientId\":4,\"boxIndex\":\"PREMIUM6822\",\"rackingLabelId\":16,\"retentionYears\":7}', '::ffff:127.0.0.1', 'Dart/3.6 (dart:io)', '2026-02-18 20:46:05'),
(43, 1, 'LOGIN', 'auth', NULL, NULL, '{\"username\":\"admin\",\"role\":\"admin\"}', '::1', 'PostmanRuntime/7.51.1', '2026-02-18 22:30:27'),
(44, 1, 'GENERATE_BULK_BOX_REPORT', 'report', NULL, NULL, '{\"clientIds\":\"all\",\"count\":17}', '::1', 'PostmanRuntime/7.51.1', '2026-02-18 22:31:38'),
(45, 1, 'GENERATE_BOX_REPORT', 'report', NULL, NULL, '{\"clientId\":\"2\",\"count\":4}', '::1', 'PostmanRuntime/7.51.1', '2026-02-18 22:53:51'),
(46, 1, 'GENERATE_BOX_REPORT', 'report', NULL, NULL, '{\"clientId\":\"all\",\"count\":17}', '::1', 'PostmanRuntime/7.51.1', '2026-02-18 22:54:51'),
(47, 1, 'GENERATE_BOX_REPORT', 'report', NULL, NULL, '{\"clientId\":\"2\",\"count\":4}', '::1', 'PostmanRuntime/7.51.1', '2026-02-18 22:55:19'),
(48, 1, 'GENERATE_BOX_REPORT', 'report', NULL, NULL, '{\"clientId\":\"2\",\"count\":4}', '::1', 'PostmanRuntime/7.51.1', '2026-02-18 22:55:55'),
(49, 1, 'LOGIN', 'auth', NULL, NULL, '{\"username\":\"admin\",\"role\":\"admin\"}', '::ffff:127.0.0.1', 'Dart/3.6 (dart:io)', '2026-02-19 15:37:13'),
(50, 1, 'GENERATE_BOX_REPORT', 'report', NULL, NULL, '{\"clientId\":\"1\",\"count\":5}', '::ffff:127.0.0.1', 'Dart/3.6 (dart:io)', '2026-02-19 15:45:28'),
(51, 1, 'GENERATE_BOX_REPORT', 'report', NULL, NULL, '{\"clientId\":\"all\",\"count\":17}', '::ffff:127.0.0.1', 'Dart/3.6 (dart:io)', '2026-02-19 15:48:25'),
(52, 1, 'GENERATE_BOX_REPORT', 'report', NULL, NULL, '{\"clientId\":\"all\",\"count\":17}', '::ffff:127.0.0.1', 'Dart/3.6 (dart:io)', '2026-02-19 16:00:26'),
(53, 1, 'GENERATE_BOX_REPORT', 'report', NULL, NULL, '{\"clientId\":\"1\",\"count\":5}', '::ffff:127.0.0.1', 'Dart/3.6 (dart:io)', '2026-02-19 16:05:19'),
(54, 1, 'GENERATE_BOX_REPORT', 'report', NULL, NULL, '{\"clientId\":\"1\",\"count\":5}', '::ffff:127.0.0.1', 'Dart/3.6 (dart:io)', '2026-02-19 16:16:33'),
(55, 1, 'GENERATE_BOX_REPORT', 'report', NULL, NULL, '{\"clientId\":\"1\",\"count\":5}', '::ffff:127.0.0.1', 'Dart/3.6 (dart:io)', '2026-02-19 16:18:08'),
(56, 1, 'GENERATE_BOX_REPORT', 'report', NULL, NULL, '{\"clientId\":\"1\",\"count\":5}', '::ffff:127.0.0.1', 'Dart/3.6 (dart:io)', '2026-02-19 16:18:37'),
(57, 1, 'GENERATE_BOX_REPORT', 'report', NULL, NULL, '{\"clientId\":\"2\",\"count\":4}', '::ffff:127.0.0.1', 'Dart/3.6 (dart:io)', '2026-02-19 16:30:59'),
(58, 1, 'GENERATE_BOX_REPORT', 'report', NULL, NULL, '{\"clientId\":\"1\",\"count\":5}', '::ffff:127.0.0.1', 'Dart/3.6 (dart:io)', '2026-02-19 16:43:23'),
(59, 1, 'GENERATE_BOX_REPORT', 'report', NULL, NULL, '{\"clientId\":\"all\",\"count\":17}', '::ffff:127.0.0.1', 'Dart/3.6 (dart:io)', '2026-02-19 16:45:01'),
(60, 1, 'GENERATE_BOX_REPORT', 'report', NULL, NULL, '{\"clientId\":\"all\",\"count\":17}', '::ffff:127.0.0.1', 'Dart/3.6 (dart:io)', '2026-02-19 16:46:17'),
(61, 1, 'GENERATE_BOX_REPORT', 'report', NULL, NULL, '{\"clientId\":\"all\",\"count\":17}', '::ffff:127.0.0.1', 'Dart/3.6 (dart:io)', '2026-02-19 16:47:13'),
(62, 1, 'GENERATE_BOX_REPORT', 'report', NULL, NULL, '{\"clientId\":\"all\",\"count\":17}', '::ffff:127.0.0.1', 'Dart/3.6 (dart:io)', '2026-02-19 16:47:32'),
(63, 1, 'GENERATE_BOX_REPORT', 'report', NULL, NULL, '{\"clientId\":\"1\",\"count\":5}', '::ffff:127.0.0.1', 'Dart/3.6 (dart:io)', '2026-02-19 17:01:34'),
(64, 1, 'GENERATE_BOX_REPORT', 'report', NULL, NULL, '{\"clientId\":\"all\",\"count\":17}', '::ffff:127.0.0.1', 'Dart/3.6 (dart:io)', '2026-02-19 17:02:24'),
(65, 1, 'GENERATE_BOX_REPORT', 'report', NULL, NULL, '{\"clientId\":\"1\",\"count\":5}', '::ffff:127.0.0.1', 'Dart/3.6 (dart:io)', '2026-02-19 17:18:10'),
(66, 1, 'LOGOUT', 'auth', NULL, NULL, 'null', '::ffff:127.0.0.1', 'Dart/3.6 (dart:io)', '2026-02-19 17:21:10'),
(67, 1, 'LOGIN', 'auth', NULL, NULL, '{\"username\":\"admin\",\"role\":\"admin\"}', '::ffff:127.0.0.1', 'Dart/3.6 (dart:io)', '2026-02-19 17:21:22'),
(68, 1, 'GENERATE_BOX_REPORT', 'report', NULL, NULL, '{\"clientId\":\"all\",\"count\":17}', '::ffff:127.0.0.1', 'Dart/3.6 (dart:io)', '2026-02-19 22:26:30'),
(69, 1, 'GENERATE_BOX_REPORT', 'report', NULL, NULL, '{\"clientId\":\"all\",\"count\":17}', '::ffff:127.0.0.1', 'Dart/3.6 (dart:io)', '2026-02-19 22:45:37'),
(70, 1, 'GENERATE_BOX_REPORT', 'report', NULL, NULL, '{\"clientId\":\"all\",\"count\":17}', '::ffff:127.0.0.1', 'Dart/3.6 (dart:io)', '2026-02-19 22:45:50'),
(71, 1, 'GENERATE_BOX_REPORT', 'report', NULL, NULL, '{\"clientId\":\"all\",\"count\":17}', '::ffff:127.0.0.1', 'Dart/3.6 (dart:io)', '2026-02-19 22:54:57'),
(72, 1, 'GENERATE_BOX_REPORT', 'report', NULL, NULL, '{\"clientId\":\"all\",\"count\":17}', '::ffff:127.0.0.1', 'Dart/3.6 (dart:io)', '2026-02-19 22:55:12'),
(73, 1, 'GENERATE_BOX_REPORT', 'report', NULL, NULL, '{\"clientId\":\"all\",\"count\":17}', '::ffff:127.0.0.1', 'Dart/3.6 (dart:io)', '2026-02-19 23:02:05'),
(74, 1, 'GENERATE_BOX_REPORT', 'report', NULL, NULL, '{\"clientId\":\"all\",\"count\":17}', '::ffff:127.0.0.1', 'Dart/3.6 (dart:io)', '2026-02-19 23:02:28'),
(75, 1, 'GENERATE_BOX_REPORT', 'report', NULL, NULL, '{\"clientId\":\"1\",\"count\":5}', '::ffff:127.0.0.1', 'Dart/3.6 (dart:io)', '2026-02-19 23:15:49'),
(76, 1, 'GENERATE_BOX_REPORT', 'report', NULL, NULL, '{\"clientId\":\"all\",\"count\":17}', '::ffff:127.0.0.1', 'Dart/3.6 (dart:io)', '2026-02-19 23:17:08'),
(77, 1, 'GENERATE_BOX_REPORT', 'report', NULL, NULL, '{\"clientId\":\"1\",\"count\":5}', '::ffff:127.0.0.1', 'Dart/3.6 (dart:io)', '2026-02-19 23:20:26'),
(78, 1, 'GENERATE_BOX_REPORT', 'report', NULL, NULL, '{\"clientId\":\"all\",\"count\":17}', '::ffff:127.0.0.1', 'Dart/3.6 (dart:io)', '2026-02-19 23:21:16'),
(79, 1, 'GENERATE_BOX_REPORT', 'report', NULL, NULL, '{\"clientId\":\"all\",\"count\":17}', '::ffff:127.0.0.1', 'Dart/3.6 (dart:io)', '2026-02-19 23:21:59'),
(80, 1, 'GENERATE_BOX_REPORT', 'report', NULL, NULL, '{\"filters\":{},\"count\":17}', '::ffff:127.0.0.1', 'Dart/3.6 (dart:io)', '2026-02-19 23:55:21'),
(81, 1, 'GENERATE_BOX_REPORT', 'report', NULL, NULL, '{\"filters\":{},\"count\":17}', '::ffff:127.0.0.1', 'Dart/3.6 (dart:io)', '2026-02-20 00:02:53'),
(82, 1, 'GENERATE_BOX_REPORT', 'report', NULL, NULL, '{\"filters\":{},\"count\":17}', '::ffff:127.0.0.1', 'Dart/3.6 (dart:io)', '2026-02-20 00:07:17'),
(83, 1, 'CREATE_BOX', 'box', 19, NULL, '{\"boxNumber\":\"CLI-001-ACME2230\",\"clientId\":1,\"boxIndex\":\"ACME2230\",\"rackingLabelId\":17,\"retentionYears\":2,\"boxSize\":\"A1\",\"dataYears\":\"2019,2020\",\"dateRange\":\"1 March 2019 - 30 October @020\"}', '::ffff:127.0.0.1', 'Dart/3.6 (dart:io)', '2026-02-20 00:15:09'),
(84, 1, 'UPDATE_BOX', 'box', 19, '{\"box_description\":\"Account Registrations\",\"racking_label_id\":17,\"retention_years\":2,\"box_size\":\"A1\",\"data_years\":\"2019,2020\",\"date_range\":\"1 March 2019 - 30 October @020\",\"box_image\":null}', '{\"boxDescription\":\"Account Registrations\",\"rackingLabelId\":17,\"retentionYears\":2,\"boxSize\":\"A1\",\"dataYears\":\"2019,2020\",\"dateRange\":\"1 March 2019 - 30 October 2020\"}', '::ffff:127.0.0.1', 'Dart/3.6 (dart:io)', '2026-02-20 00:16:39'),
(85, 1, 'LOGIN', 'auth', NULL, NULL, '{\"username\":\"admin\",\"role\":\"admin\"}', '::1', 'PostmanRuntime/7.51.1', '2026-02-20 00:18:21'),
(86, 1, 'CHANGE_BOX_STATUS', 'box', 5, '{\"status\":\"stored\"}', '{\"status\":\"retrieved\"}', '::ffff:127.0.0.1', 'Dart/3.6 (dart:io)', '2026-02-20 00:22:47'),
(87, 1, 'CHANGE_BOX_STATUS', 'box', 5, '{\"status\":\"retrieved\"}', '{\"status\":\"stored\"}', '::ffff:127.0.0.1', 'Dart/3.6 (dart:io)', '2026-02-20 00:22:53'),
(88, 1, 'GENERATE_BOX_REPORT', 'report', NULL, NULL, '{\"filters\":{\"clientId\":\"1\",\"status\":\"retrieved\"},\"count\":1}', '::ffff:127.0.0.1', 'Dart/3.6 (dart:io)', '2026-02-20 00:24:24'),
(89, 1, 'GENERATE_BOX_REPORT', 'report', NULL, NULL, '{\"filters\":{\"status\":\"stored\"},\"count\":17}', '::ffff:127.0.0.1', 'Dart/3.6 (dart:io)', '2026-02-20 00:25:16'),
(90, 1, 'GENERATE_BOX_REPORT', 'report', NULL, NULL, '{\"filters\":{},\"count\":18}', '::ffff:127.0.0.1', 'Dart/3.6 (dart:io)', '2026-02-20 00:29:08'),
(91, 1, 'GENERATE_BOX_REPORT', 'report', NULL, NULL, '{\"filters\":{},\"count\":18}', '::ffff:127.0.0.1', 'Dart/3.6 (dart:io)', '2026-02-20 00:37:10'),
(92, 1, 'GENERATE_BOX_REPORT', 'report', NULL, NULL, '{\"filters\":{\"retentionYears\":\"2\"},\"count\":1}', '::ffff:127.0.0.1', 'Dart/3.6 (dart:io)', '2026-02-20 00:42:19'),
(93, 1, 'GENERATE_BOX_REPORT', 'report', NULL, NULL, '{\"filters\":{\"retentionYears\":\"2\"},\"count\":1}', '::ffff:127.0.0.1', 'Dart/3.6 (dart:io)', '2026-02-20 00:42:40'),
(94, 1, 'GENERATE_BOX_REPORT', 'report', NULL, NULL, '{\"filters\":{\"clientId\":\"1\",\"status\":\"retrieved\"},\"count\":1}', '::ffff:127.0.0.1', 'Dart/3.6 (dart:io)', '2026-02-20 00:44:34'),
(95, 1, 'GENERATE_BOX_REPORT', 'report', NULL, NULL, '{\"filters\":{\"rackingLabelId\":\"17\"},\"count\":1}', '::ffff:127.0.0.1', 'Dart/3.6 (dart:io)', '2026-02-20 00:45:18'),
(96, 1, 'GENERATE_BOX_REPORT', 'report', NULL, NULL, '{\"filters\":{},\"count\":18}', '::ffff:127.0.0.1', 'Dart/3.6 (dart:io)', '2026-02-20 00:45:42'),
(97, 1, 'GENERATE_BOX_REPORT', 'report', NULL, NULL, '{\"filters\":{},\"count\":18}', '::ffff:127.0.0.1', 'Dart/3.6 (dart:io)', '2026-02-20 00:55:19'),
(98, 1, 'GENERATE_BOX_REPORT', 'report', NULL, NULL, '{\"filters\":{},\"count\":18}', '::ffff:127.0.0.1', 'Dart/3.6 (dart:io)', '2026-02-20 00:57:29'),
(99, 1, 'GENERATE_BOX_REPORT', 'report', NULL, NULL, '{\"filters\":{},\"count\":18}', '::ffff:127.0.0.1', 'Dart/3.6 (dart:io)', '2026-02-20 00:58:03'),
(100, 1, 'GENERATE_BOX_REPORT', 'report', NULL, NULL, '{\"filters\":{},\"count\":18}', '::ffff:127.0.0.1', 'Dart/3.6 (dart:io)', '2026-02-20 00:59:22'),
(101, 1, 'GENERATE_BOX_REPORT', 'report', NULL, NULL, '{\"filters\":{},\"count\":18}', '::ffff:127.0.0.1', 'Dart/3.6 (dart:io)', '2026-02-20 01:00:05'),
(102, 1, 'GENERATE_BOX_REPORT', 'report', NULL, NULL, '{\"filters\":{\"clientId\":\"1\"},\"count\":6}', '::ffff:127.0.0.1', 'Dart/3.6 (dart:io)', '2026-02-20 01:01:10');

-- --------------------------------------------------------

--
-- Table structure for table `boxes`
--

CREATE TABLE `boxes` (
  `box_id` int(11) NOT NULL,
  `box_number` varchar(100) NOT NULL COMMENT 'Unique box identifier',
  `client_id` int(11) NOT NULL,
  `racking_label_id` int(11) DEFAULT NULL COMMENT 'Physical storage location',
  `box_description` text DEFAULT NULL COMMENT 'Contents description',
  `box_size` enum('A0','A1','A2','A3','A4','A5','A6','Custom') DEFAULT NULL COMMENT 'Document size the box holds (A3, A4, A5, etc.)',
  `data_years` varchar(255) DEFAULT NULL COMMENT 'Comma-separated years of data contained e.g. 2019,2020,2021,2022',
  `date_range` varchar(255) DEFAULT NULL COMMENT 'Descriptive date range of documents e.g. 08-15 Aug 2022, 20-25 March 2023',
  `box_image` varchar(255) DEFAULT NULL COMMENT 'Relative path to box image e.g. uploads/boxes/BOX-001-2024.jpg',
  `date_received` date DEFAULT NULL COMMENT 'Date box was received',
  `year_received` int(11) DEFAULT NULL COMMENT 'Year box was received',
  `retention_years` int(11) DEFAULT 7 COMMENT 'Number of years to retain',
  `destruction_year` int(11) DEFAULT NULL COMMENT 'Calculated year for destruction',
  `status` enum('stored','retrieved','destroyed') DEFAULT 'stored',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci COMMENT='Physical document storage boxes';

--
-- Dumping data for table `boxes`
--

INSERT INTO `boxes` (`box_id`, `box_number`, `client_id`, `racking_label_id`, `box_description`, `box_size`, `data_years`, `date_range`, `box_image`, `date_received`, `year_received`, `retention_years`, `destruction_year`, `status`, `created_at`, `updated_at`) VALUES
(1, 'BOX-001-2024', 1, 1, 'Financial Records 2024 - Q1 to Q4', NULL, NULL, NULL, NULL, '2024-01-15', 2024, 7, 2031, 'stored', '2025-11-18 11:11:04', '2025-11-18 11:11:04'),
(2, 'BOX-002-2024', 1, 2, 'HR Documents 2024 - Employee Files', NULL, NULL, NULL, NULL, '2024-02-20', 2024, 7, 2031, 'retrieved', '2025-11-18 11:11:04', '2026-02-11 19:34:36'),
(3, 'BOX-003-2024', 1, 3, 'Legal Contracts 2024', NULL, NULL, NULL, NULL, '2024-03-10', 2024, 10, 2034, 'stored', '2025-11-18 11:11:04', '2025-11-18 11:11:04'),
(4, 'BOX-004-2024', 2, 4, 'Project Documents 2024 - Phase 1', NULL, NULL, NULL, NULL, '2024-01-25', 2024, 5, 2029, 'stored', '2025-11-18 11:11:04', '2025-11-18 11:11:04'),
(5, 'BOX-005-2024', 2, 5, 'Client Correspondence 2024', NULL, NULL, NULL, NULL, '2024-02-15', 2024, 7, 2031, 'stored', '2025-11-18 11:11:04', '2026-02-20 00:22:53'),
(6, 'BOX-006-2023', 1, 6, 'Financial Records 2023', NULL, NULL, NULL, NULL, '2023-01-10', 2023, 7, 2030, 'stored', '2025-11-18 11:11:04', '2025-11-18 11:11:04'),
(7, 'BOX-007-2023', 3, 7, 'Technical Documentation 2023', NULL, NULL, NULL, NULL, '2023-03-15', 2023, 7, 2030, 'stored', '2025-11-18 11:11:04', '2025-11-18 11:11:04'),
(8, 'BOX-008-2023', 3, 8, 'Employee Records 2023', NULL, NULL, NULL, NULL, '2023-04-20', 2023, 7, 2030, 'stored', '2025-11-18 11:11:04', '2025-11-18 11:11:04'),
(9, 'BOX-009-2022', 2, 9, 'Archive Documents 2022', NULL, NULL, NULL, NULL, '2022-12-15', 2022, 7, 2029, 'stored', '2025-11-18 11:11:04', '2025-11-18 11:11:04'),
(10, 'BOX-010-2022', 4, 10, 'Legal Files 2022', NULL, NULL, NULL, NULL, '2022-11-10', 2022, 10, 2032, 'stored', '2025-11-18 11:11:04', '2025-11-18 11:11:04'),
(11, 'BOX-011-2018', 1, 11, 'Old Records 2018 - Pending Destruction', NULL, NULL, NULL, NULL, '2018-01-15', 2018, 7, 2025, 'stored', '2025-11-18 11:11:04', '2025-11-18 11:11:04'),
(12, 'BOX-012-2024', 5, 12, 'Sales Records 2024', NULL, NULL, NULL, NULL, '2024-05-10', 2024, 5, 2029, 'stored', '2025-11-18 11:11:04', '2025-11-18 11:11:04'),
(13, 'BOX-013-2024', 5, 13, 'Marketing Materials 2024', NULL, NULL, NULL, NULL, '2024-06-15', 2024, 3, 2027, 'stored', '2025-11-18 11:11:04', '2025-11-18 11:11:04'),
(14, 'BOX-014-2023', 4, 14, 'Annual Reports 2023', NULL, NULL, NULL, NULL, '2023-12-20', 2023, 10, 2033, 'stored', '2025-11-18 11:11:04', '2025-11-18 11:11:04'),
(15, 'BOX-015-2023', 3, 15, 'Compliance Documents 2023', NULL, NULL, NULL, NULL, '2023-11-25', 2023, 7, 2030, 'stored', '2025-11-18 11:11:04', '2025-11-18 11:11:04'),
(16, 'BOX-CLI-002-GLOBAL8822', 2, 1, 'financial documents, 2022', NULL, NULL, NULL, NULL, '2026-02-18', 2026, 4, 2030, 'stored', '2026-02-18 11:17:32', '2026-02-18 11:17:32'),
(18, 'CLI-004-PREMIUM6822', 4, 16, 'Statements for years 2020 - 2024', NULL, NULL, NULL, NULL, '2026-02-18', 2026, 7, 2033, 'stored', '2026-02-18 20:46:05', '2026-02-18 20:46:05'),
(19, 'CLI-001-ACME2230', 1, 17, 'Account Registrations', 'A1', '2019,2020', '1 March 2019 - 30 October 2020', NULL, '2026-02-20', 2026, 2, 2028, 'stored', '2026-02-20 00:15:09', '2026-02-20 00:16:39');

--
-- Triggers `boxes`
--
DELIMITER $$
CREATE TRIGGER `trg_boxes_before_insert` BEFORE INSERT ON `boxes` FOR EACH ROW BEGIN
    IF NEW.year_received IS NOT NULL AND NEW.retention_years IS NOT NULL THEN
        SET NEW.destruction_year = NEW.year_received + NEW.retention_years;
    END IF;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `trg_boxes_before_update` BEFORE UPDATE ON `boxes` FOR EACH ROW BEGIN
    IF NEW.year_received IS NOT NULL AND NEW.retention_years IS NOT NULL THEN
        SET NEW.destruction_year = NEW.year_received + NEW.retention_years;
    END IF;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `clients`
--

CREATE TABLE `clients` (
  `client_id` int(11) NOT NULL,
  `client_name` varchar(255) NOT NULL,
  `client_code` varchar(50) NOT NULL COMMENT 'Unique client identifier code',
  `contact_person` varchar(255) DEFAULT NULL,
  `email` varchar(255) DEFAULT NULL,
  `phone` varchar(50) DEFAULT NULL,
  `address` text DEFAULT NULL,
  `is_active` tinyint(1) DEFAULT 1,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci COMMENT='Client companies storing documents';

--
-- Dumping data for table `clients`
--

INSERT INTO `clients` (`client_id`, `client_name`, `client_code`, `contact_person`, `email`, `phone`, `address`, `is_active`, `created_at`, `updated_at`) VALUES
(1, 'Acme Corporation', 'CLI-001', 'John Smith', 'john@acme.com', '+268-7612-3456', NULL, 1, '2025-11-18 11:11:04', '2025-11-18 11:11:04'),
(2, 'Global Industries', 'CLI-002', 'Sarah Johnson', 'sarah@global.com', '+268-7698-7654', NULL, 1, '2025-11-18 11:11:04', '2025-11-18 11:11:04'),
(3, 'Tech Solutions Ltd', 'CLI-003', 'Michael Brown', 'michael@techsol.com', '+268-7623-4567', NULL, 1, '2025-11-18 11:11:04', '2025-11-18 11:11:04'),
(4, 'Premium Services', 'CLI-004', 'Emily Davis', 'emily@premium.com', '+268-7634-5678', NULL, 1, '2025-11-18 11:11:04', '2025-11-18 11:11:04'),
(5, 'Mega Enterprises', 'CLI-005', 'David Wilson', 'david@mega.com', '+268-7645-6789', NULL, 1, '2025-11-18 11:11:04', '2025-11-18 11:11:04');

-- --------------------------------------------------------

--
-- Table structure for table `collections`
--

CREATE TABLE `collections` (
  `collection_id` int(11) NOT NULL,
  `client_id` int(11) NOT NULL,
  `total_boxes` int(11) NOT NULL COMMENT 'Number of boxes collected',
  `box_description` text DEFAULT NULL COMMENT 'Description of collected boxes',
  `dispatcher_name` varchar(255) NOT NULL COMMENT 'Name of person dispatching boxes',
  `collector_name` varchar(255) NOT NULL COMMENT 'Name of person collecting boxes',
  `dispatcher_signature` text DEFAULT NULL COMMENT 'Base64 encoded signature image',
  `collector_signature` text DEFAULT NULL COMMENT 'Base64 encoded signature image',
  `collection_date` date NOT NULL,
  `pdf_path` varchar(500) DEFAULT NULL COMMENT 'Path to generated PDF receipt',
  `created_by` int(11) DEFAULT NULL COMMENT 'User who created this record',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci COMMENT='Box collection records with signatures';

--
-- Dumping data for table `collections`
--

INSERT INTO `collections` (`collection_id`, `client_id`, `total_boxes`, `box_description`, `dispatcher_name`, `collector_name`, `dispatcher_signature`, `collector_signature`, `collection_date`, `pdf_path`, `created_by`, `created_at`) VALUES
(1, 1, 5, 'Financial and HR records for 2024', 'admin', 'client1', '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', '2024-11-15', NULL, 2, '2025-11-18 11:11:04');

-- --------------------------------------------------------

--
-- Table structure for table `daily_stats`
--

CREATE TABLE `daily_stats` (
  `stat_id` int(11) NOT NULL,
  `stat_date` date NOT NULL,
  `total_boxes` int(11) DEFAULT 0 COMMENT 'Total boxes in system',
  `total_clients` int(11) DEFAULT 0 COMMENT 'Total active clients',
  `boxes_stored` int(11) DEFAULT 0 COMMENT 'Boxes with stored status',
  `boxes_retrieved` int(11) DEFAULT 0 COMMENT 'Boxes with retrieved status',
  `boxes_destroyed` int(11) DEFAULT 0 COMMENT 'Boxes with destroyed status',
  `collections_count` int(11) DEFAULT 0 COMMENT 'Collections made today',
  `retrievals_count` int(11) DEFAULT 0 COMMENT 'Retrievals made today',
  `deliveries_count` int(11) DEFAULT 0 COMMENT 'Deliveries made today',
  `active_users` int(11) DEFAULT 0 COMMENT 'Active users in system',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci COMMENT='Daily aggregated system statistics';

--
-- Dumping data for table `daily_stats`
--

INSERT INTO `daily_stats` (`stat_id`, `stat_date`, `total_boxes`, `total_clients`, `boxes_stored`, `boxes_retrieved`, `boxes_destroyed`, `collections_count`, `retrievals_count`, `deliveries_count`, `active_users`, `created_at`) VALUES
(1, '2025-11-18', 15, 5, 15, 0, 0, 0, 0, 0, 3, '2025-11-18 11:11:04');

-- --------------------------------------------------------

--
-- Table structure for table `deliveries`
--

CREATE TABLE `deliveries` (
  `delivery_id` int(11) NOT NULL,
  `client_id` int(11) NOT NULL,
  `item_name` varchar(255) NOT NULL COMMENT 'Name of delivered item',
  `quantity` int(11) NOT NULL COMMENT 'Quantity delivered',
  `delivery_date` date NOT NULL,
  `receiver_name` varchar(255) NOT NULL COMMENT 'Name of person receiving',
  `receiver_signature` text DEFAULT NULL COMMENT 'Base64 encoded receiver signature',
  `acknowledgement_statement` text DEFAULT NULL COMMENT 'Acknowledgement text',
  `pdf_path` varchar(500) DEFAULT NULL COMMENT 'Path to generated PDF receipt',
  `created_by` int(11) DEFAULT NULL COMMENT 'User who created this record',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci COMMENT='Item delivery records with signatures';

--
-- Dumping data for table `deliveries`
--

INSERT INTO `deliveries` (`delivery_id`, `client_id`, `item_name`, `quantity`, `delivery_date`, `receiver_name`, `receiver_signature`, `acknowledgement_statement`, `pdf_path`, `created_by`, `created_at`) VALUES
(1, 1, 'Empty Storage Boxes', 50, '2024-11-17', 'John Smith', NULL, NULL, NULL, 2, '2025-11-18 11:11:04');

-- --------------------------------------------------------

--
-- Table structure for table `permissions`
--

CREATE TABLE `permissions` (
  `permission_id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `can_create_boxes` tinyint(1) DEFAULT 0,
  `can_edit_boxes` tinyint(1) DEFAULT 0,
  `can_delete_boxes` tinyint(1) DEFAULT 0,
  `can_create_collections` tinyint(1) DEFAULT 0,
  `can_create_retrievals` tinyint(1) DEFAULT 0,
  `can_create_deliveries` tinyint(1) DEFAULT 0,
  `can_view_reports` tinyint(1) DEFAULT 0,
  `can_manage_users` tinyint(1) DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci COMMENT='User permissions for access control';

--
-- Dumping data for table `permissions`
--

INSERT INTO `permissions` (`permission_id`, `user_id`, `can_create_boxes`, `can_edit_boxes`, `can_delete_boxes`, `can_create_collections`, `can_create_retrievals`, `can_create_deliveries`, `can_view_reports`, `can_manage_users`, `created_at`, `updated_at`) VALUES
(1, 1, 1, 1, 1, 1, 1, 1, 1, 1, '2025-11-18 11:11:04', '2025-11-18 11:11:04'),
(2, 2, 1, 1, 0, 1, 1, 1, 1, 0, '2025-11-18 11:11:04', '2025-11-18 11:11:04'),
(3, 3, 0, 0, 0, 0, 0, 0, 1, 0, '2025-11-18 11:11:04', '2025-11-18 11:11:04');

-- --------------------------------------------------------

--
-- Table structure for table `racking_labels`
--

CREATE TABLE `racking_labels` (
  `label_id` int(11) NOT NULL,
  `label_code` varchar(50) NOT NULL COMMENT 'Unique rack location code',
  `location_description` varchar(255) DEFAULT NULL COMMENT 'Descriptive location details',
  `is_available` tinyint(1) DEFAULT 1 COMMENT 'Whether location is available for new boxes',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci COMMENT='Physical storage rack locations';

--
-- Dumping data for table `racking_labels`
--

INSERT INTO `racking_labels` (`label_id`, `label_code`, `location_description`, `is_available`, `created_at`, `updated_at`) VALUES
(1, 'RACK-A-01', 'Warehouse A - Section 1 - Level 1', 1, '2025-11-18 11:11:04', '2025-11-18 11:11:04'),
(2, 'RACK-A-02', 'Warehouse A - Section 1 - Level 2', 1, '2025-11-18 11:11:04', '2025-11-18 11:11:04'),
(3, 'RACK-A-03', 'Warehouse A - Section 1 - Level 3', 1, '2025-11-18 11:11:04', '2025-11-18 11:11:04'),
(4, 'RACK-A-04', 'Warehouse A - Section 2 - Level 1', 1, '2025-11-18 11:11:04', '2025-11-18 11:11:04'),
(5, 'RACK-A-05', 'Warehouse A - Section 2 - Level 2', 1, '2025-11-18 11:11:04', '2025-11-18 11:11:04'),
(6, 'RACK-B-01', 'Warehouse B - Section 1 - Level 1', 1, '2025-11-18 11:11:04', '2025-11-18 11:11:04'),
(7, 'RACK-B-02', 'Warehouse B - Section 1 - Level 2', 1, '2025-11-18 11:11:04', '2025-11-18 11:11:04'),
(8, 'RACK-B-03', 'Warehouse B - Section 2 - Level 1', 1, '2025-11-18 11:11:04', '2025-11-18 11:11:04'),
(9, 'RACK-B-04', 'Warehouse B - Section 2 - Level 2', 1, '2025-11-18 11:11:04', '2025-11-18 11:11:04'),
(10, 'RACK-B-05', 'Warehouse B - Section 3 - Level 1', 1, '2025-11-18 11:11:04', '2025-11-18 11:11:04'),
(11, 'RACK-C-01', 'Warehouse C - Section 1 - Level 1', 1, '2025-11-18 11:11:04', '2025-11-18 11:11:04'),
(12, 'RACK-C-02', 'Warehouse C - Section 1 - Level 2', 1, '2025-11-18 11:11:04', '2025-11-18 11:11:04'),
(13, 'RACK-C-03', 'Warehouse C - Section 2 - Level 1', 1, '2025-11-18 11:11:04', '2025-11-18 11:11:04'),
(14, 'RACK-C-04', 'Warehouse C - Section 2 - Level 2', 1, '2025-11-18 11:11:04', '2025-11-18 11:11:04'),
(15, 'RACK-C-05', 'Warehouse C - Section 3 - Level 1', 1, '2025-11-18 11:11:04', '2025-11-18 11:11:04'),
(16, 'RACK-A23', 'Matsapha Warehouse - section1', 1, '2026-02-18 11:47:04', '2026-02-18 11:47:04'),
(17, 'RACK-A27', 'Matsapha Warehouse - section1', 1, '2026-02-18 11:47:13', '2026-02-18 11:47:13');

-- --------------------------------------------------------

--
-- Table structure for table `requests`
--

CREATE TABLE `requests` (
  `request_id` int(11) NOT NULL,
  `client_id` int(11) NOT NULL,
  `request_type` enum('retrieval','destruction','collection') NOT NULL,
  `box_id` int(11) DEFAULT NULL COMMENT 'Box ID for retrieval/destruction requests',
  `details` text DEFAULT NULL COMMENT 'Additional request details',
  `status` enum('pending','approved','completed','cancelled') DEFAULT 'pending',
  `requested_date` date NOT NULL,
  `completed_date` date DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci COMMENT='Client service requests';

--
-- Dumping data for table `requests`
--

INSERT INTO `requests` (`request_id`, `client_id`, `request_type`, `box_id`, `details`, `status`, `requested_date`, `completed_date`, `created_at`, `updated_at`) VALUES
(1, 1, 'retrieval', 2, 'Need HR documents for employee verification', 'approved', '2024-11-18', NULL, '2025-11-18 11:11:04', '2026-02-11 19:41:11');

-- --------------------------------------------------------

--
-- Table structure for table `retrievals`
--

CREATE TABLE `retrievals` (
  `retrieval_id` int(11) NOT NULL,
  `client_id` int(11) NOT NULL,
  `box_id` int(11) NOT NULL,
  `retrieval_date` date NOT NULL,
  `retrieved_by` varchar(255) DEFAULT NULL COMMENT 'Name of person retrieving',
  `reason` text DEFAULT NULL COMMENT 'Reason for retrieval',
  `client_signature` text DEFAULT NULL COMMENT 'Base64 encoded client signature',
  `staff_signature` text DEFAULT NULL COMMENT 'Base64 encoded staff signature',
  `pdf_path` varchar(500) DEFAULT NULL COMMENT 'Path to generated PDF receipt',
  `created_by` int(11) DEFAULT NULL COMMENT 'User who created this record',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci COMMENT='Box retrieval records with signatures';

--
-- Dumping data for table `retrievals`
--

INSERT INTO `retrievals` (`retrieval_id`, `client_id`, `box_id`, `retrieval_date`, `retrieved_by`, `reason`, `client_signature`, `staff_signature`, `pdf_path`, `created_by`, `created_at`) VALUES
(1, 1, 1, '2024-11-16', 'John Smith', 'Needed for audit purposes', NULL, 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAA...', NULL, 2, '2025-11-18 11:11:04'),
(2, 1, 2, '2025-02-15', 'Jane Smith', 'Workflow test', 'data:image/png;base64,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', 'data:image/png;base64,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', NULL, 1, '2026-02-11 19:20:21');

-- --------------------------------------------------------

--
-- Table structure for table `token_blacklist`
--

CREATE TABLE `token_blacklist` (
  `id` int(11) NOT NULL,
  `token_hash` varchar(255) NOT NULL COMMENT 'SHA-256 hash of JWT token',
  `user_id` int(11) NOT NULL,
  `expires_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp() COMMENT 'Token expiry time',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci COMMENT='Blacklisted tokens for logout invalidation';

--
-- Dumping data for table `token_blacklist`
--

INSERT INTO `token_blacklist` (`id`, `token_hash`, `user_id`, `expires_at`, `created_at`) VALUES
(1, 'e548768d63b101bc9a4fde08bc3e929976a69daa869dfa95a5c039187e1d8c2d', 1, '2025-11-20 21:22:30', '2025-11-19 21:31:13'),
(2, 'a27a02e76a7befcca09a39f81accd8ed5121dd6fbe49e88dba8e29223b770bad', 1, '2026-01-09 14:37:37', '2026-01-08 14:49:49'),
(3, '72e36ec7d20f021e84afeb043736737fe2a33bd241fef6b83863ebdfd202e317', 1, '2026-02-20 15:37:14', '2026-02-19 17:21:10');

-- --------------------------------------------------------

--
-- Table structure for table `users`
--

CREATE TABLE `users` (
  `user_id` int(11) NOT NULL,
  `username` varchar(100) NOT NULL,
  `email` varchar(255) NOT NULL,
  `password_hash` varchar(255) NOT NULL COMMENT 'Bcrypt hashed password',
  `role` enum('admin','staff','client') NOT NULL DEFAULT 'client',
  `client_id` int(11) DEFAULT NULL COMMENT 'Foreign key to clients table, only for client role',
  `is_active` tinyint(1) DEFAULT 1,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci COMMENT='System users with role-based access';

--
-- Dumping data for table `users`
--

INSERT INTO `users` (`user_id`, `username`, `email`, `password_hash`, `role`, `client_id`, `is_active`, `created_at`, `updated_at`) VALUES
(1, 'admin', 'admin@docsecure.com', '$2a$12$Vc.GY27ju8SDqBEJUHON7OQ/B.MbiqgmDGUe5ZEdwrTEpXCawUKLK', 'admin', NULL, 1, '2025-11-18 11:11:04', '2025-11-19 01:54:02'),
(2, 'staff1', 'staff@docsecure.com', '$2b$10$YQ98PzLpzz5zZZ5zZZ5zZO8RQXkK1b3eMJ9Zg7yZZ5zZZ5zZZ5zZZ', 'staff', NULL, 1, '2025-11-18 11:11:04', '2025-11-18 11:11:04'),
(3, 'client1', 'client@acme.com', '$2b$10$YQ98PzLpzz5zZZ5zZZ5zZO8RQXkK1b3eMJ9Zg7yZZ5zZZ5zZZ5zZZ', 'client', 1, 1, '2025-11-18 11:11:04', '2025-11-19 21:29:32');

-- --------------------------------------------------------

--
-- Stand-in structure for view `vw_boxes_full`
-- (See below for the actual view)
--
CREATE TABLE `vw_boxes_full` (
`box_id` int(11)
,`box_number` varchar(100)
,`client_id` int(11)
,`client_name` varchar(255)
,`client_code` varchar(50)
,`racking_label_id` int(11)
,`racking_label_code` varchar(50)
,`racking_location` varchar(255)
,`box_description` text
,`date_received` date
,`year_received` int(11)
,`retention_years` int(11)
,`destruction_year` int(11)
,`status` enum('stored','retrieved','destroyed')
,`created_at` timestamp
,`updated_at` timestamp
,`is_pending_destruction` int(1)
);

-- --------------------------------------------------------

--
-- Stand-in structure for view `vw_collections_full`
-- (See below for the actual view)
--
CREATE TABLE `vw_collections_full` (
`collection_id` int(11)
,`client_id` int(11)
,`client_name` varchar(255)
,`client_code` varchar(50)
,`total_boxes` int(11)
,`box_description` text
,`dispatcher_name` varchar(255)
,`collector_name` varchar(255)
,`collection_date` date
,`pdf_path` varchar(500)
,`created_by` int(11)
,`created_by_username` varchar(100)
,`created_at` timestamp
);

-- --------------------------------------------------------

--
-- Stand-in structure for view `vw_retrievals_full`
-- (See below for the actual view)
--
CREATE TABLE `vw_retrievals_full` (
`retrieval_id` int(11)
,`client_id` int(11)
,`client_name` varchar(255)
,`client_code` varchar(50)
,`box_id` int(11)
,`box_number` varchar(100)
,`retrieval_date` date
,`retrieved_by` varchar(255)
,`reason` text
,`pdf_path` varchar(500)
,`created_by` int(11)
,`created_by_username` varchar(100)
,`created_at` timestamp
);

-- --------------------------------------------------------

--
-- Stand-in structure for view `vw_users_full`
-- (See below for the actual view)
--
CREATE TABLE `vw_users_full` (
`user_id` int(11)
,`username` varchar(100)
,`email` varchar(255)
,`role` enum('admin','staff','client')
,`client_id` int(11)
,`client_name` varchar(255)
,`client_code` varchar(50)
,`is_active` tinyint(1)
,`can_create_boxes` tinyint(1)
,`can_edit_boxes` tinyint(1)
,`can_delete_boxes` tinyint(1)
,`can_create_collections` tinyint(1)
,`can_create_retrievals` tinyint(1)
,`can_create_deliveries` tinyint(1)
,`can_view_reports` tinyint(1)
,`can_manage_users` tinyint(1)
,`created_at` timestamp
,`updated_at` timestamp
);

-- --------------------------------------------------------

--
-- Structure for view `vw_boxes_full`
--
DROP TABLE IF EXISTS `vw_boxes_full`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `vw_boxes_full`  AS SELECT `b`.`box_id` AS `box_id`, `b`.`box_number` AS `box_number`, `b`.`client_id` AS `client_id`, `c`.`client_name` AS `client_name`, `c`.`client_code` AS `client_code`, `b`.`racking_label_id` AS `racking_label_id`, `r`.`label_code` AS `racking_label_code`, `r`.`location_description` AS `racking_location`, `b`.`box_description` AS `box_description`, `b`.`date_received` AS `date_received`, `b`.`year_received` AS `year_received`, `b`.`retention_years` AS `retention_years`, `b`.`destruction_year` AS `destruction_year`, `b`.`status` AS `status`, `b`.`created_at` AS `created_at`, `b`.`updated_at` AS `updated_at`, CASE WHEN `b`.`destruction_year` is not null AND `b`.`destruction_year` <= year(curdate()) THEN 1 ELSE 0 END AS `is_pending_destruction` FROM ((`boxes` `b` left join `clients` `c` on(`b`.`client_id` = `c`.`client_id`)) left join `racking_labels` `r` on(`b`.`racking_label_id` = `r`.`label_id`)) ;

-- --------------------------------------------------------

--
-- Structure for view `vw_collections_full`
--
DROP TABLE IF EXISTS `vw_collections_full`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `vw_collections_full`  AS SELECT `col`.`collection_id` AS `collection_id`, `col`.`client_id` AS `client_id`, `c`.`client_name` AS `client_name`, `c`.`client_code` AS `client_code`, `col`.`total_boxes` AS `total_boxes`, `col`.`box_description` AS `box_description`, `col`.`dispatcher_name` AS `dispatcher_name`, `col`.`collector_name` AS `collector_name`, `col`.`collection_date` AS `collection_date`, `col`.`pdf_path` AS `pdf_path`, `col`.`created_by` AS `created_by`, `u`.`username` AS `created_by_username`, `col`.`created_at` AS `created_at` FROM ((`collections` `col` left join `clients` `c` on(`col`.`client_id` = `c`.`client_id`)) left join `users` `u` on(`col`.`created_by` = `u`.`user_id`)) ;

-- --------------------------------------------------------

--
-- Structure for view `vw_retrievals_full`
--
DROP TABLE IF EXISTS `vw_retrievals_full`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `vw_retrievals_full`  AS SELECT `ret`.`retrieval_id` AS `retrieval_id`, `ret`.`client_id` AS `client_id`, `c`.`client_name` AS `client_name`, `c`.`client_code` AS `client_code`, `ret`.`box_id` AS `box_id`, `b`.`box_number` AS `box_number`, `ret`.`retrieval_date` AS `retrieval_date`, `ret`.`retrieved_by` AS `retrieved_by`, `ret`.`reason` AS `reason`, `ret`.`pdf_path` AS `pdf_path`, `ret`.`created_by` AS `created_by`, `u`.`username` AS `created_by_username`, `ret`.`created_at` AS `created_at` FROM (((`retrievals` `ret` left join `clients` `c` on(`ret`.`client_id` = `c`.`client_id`)) left join `boxes` `b` on(`ret`.`box_id` = `b`.`box_id`)) left join `users` `u` on(`ret`.`created_by` = `u`.`user_id`)) ;

-- --------------------------------------------------------

--
-- Structure for view `vw_users_full`
--
DROP TABLE IF EXISTS `vw_users_full`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `vw_users_full`  AS SELECT `u`.`user_id` AS `user_id`, `u`.`username` AS `username`, `u`.`email` AS `email`, `u`.`role` AS `role`, `u`.`client_id` AS `client_id`, `c`.`client_name` AS `client_name`, `c`.`client_code` AS `client_code`, `u`.`is_active` AS `is_active`, `p`.`can_create_boxes` AS `can_create_boxes`, `p`.`can_edit_boxes` AS `can_edit_boxes`, `p`.`can_delete_boxes` AS `can_delete_boxes`, `p`.`can_create_collections` AS `can_create_collections`, `p`.`can_create_retrievals` AS `can_create_retrievals`, `p`.`can_create_deliveries` AS `can_create_deliveries`, `p`.`can_view_reports` AS `can_view_reports`, `p`.`can_manage_users` AS `can_manage_users`, `u`.`created_at` AS `created_at`, `u`.`updated_at` AS `updated_at` FROM ((`users` `u` left join `clients` `c` on(`u`.`client_id` = `c`.`client_id`)) left join `permissions` `p` on(`u`.`user_id` = `p`.`user_id`)) ;

--
-- Indexes for dumped tables
--

--
-- Indexes for table `audit_logs`
--
ALTER TABLE `audit_logs`
  ADD PRIMARY KEY (`audit_id`),
  ADD KEY `idx_user_id` (`user_id`),
  ADD KEY `idx_action` (`action`),
  ADD KEY `idx_entity_type` (`entity_type`),
  ADD KEY `idx_entity_id` (`entity_id`),
  ADD KEY `idx_created_at` (`created_at`),
  ADD KEY `idx_user_action` (`user_id`,`action`),
  ADD KEY `idx_entity` (`entity_type`,`entity_id`);

--
-- Indexes for table `boxes`
--
ALTER TABLE `boxes`
  ADD PRIMARY KEY (`box_id`),
  ADD UNIQUE KEY `box_number` (`box_number`),
  ADD KEY `idx_box_number` (`box_number`),
  ADD KEY `idx_client_id` (`client_id`),
  ADD KEY `idx_racking_label` (`racking_label_id`),
  ADD KEY `idx_destruction_year` (`destruction_year`),
  ADD KEY `idx_status` (`status`),
  ADD KEY `idx_client_status` (`client_id`,`status`),
  ADD KEY `idx_client_destruction` (`client_id`,`destruction_year`);

--
-- Indexes for table `clients`
--
ALTER TABLE `clients`
  ADD PRIMARY KEY (`client_id`),
  ADD UNIQUE KEY `client_code` (`client_code`),
  ADD KEY `idx_client_code` (`client_code`),
  ADD KEY `idx_client_name` (`client_name`),
  ADD KEY `idx_is_active` (`is_active`);

--
-- Indexes for table `collections`
--
ALTER TABLE `collections`
  ADD PRIMARY KEY (`collection_id`),
  ADD KEY `idx_client_id` (`client_id`),
  ADD KEY `idx_collection_date` (`collection_date`),
  ADD KEY `idx_client_date` (`client_id`,`collection_date`),
  ADD KEY `idx_created_by` (`created_by`);

--
-- Indexes for table `daily_stats`
--
ALTER TABLE `daily_stats`
  ADD PRIMARY KEY (`stat_id`),
  ADD UNIQUE KEY `stat_date` (`stat_date`),
  ADD KEY `idx_stat_date` (`stat_date`);

--
-- Indexes for table `deliveries`
--
ALTER TABLE `deliveries`
  ADD PRIMARY KEY (`delivery_id`),
  ADD KEY `idx_client_id` (`client_id`),
  ADD KEY `idx_delivery_date` (`delivery_date`),
  ADD KEY `idx_client_date` (`client_id`,`delivery_date`),
  ADD KEY `idx_created_by` (`created_by`);

--
-- Indexes for table `permissions`
--
ALTER TABLE `permissions`
  ADD PRIMARY KEY (`permission_id`),
  ADD UNIQUE KEY `idx_user_permission` (`user_id`);

--
-- Indexes for table `racking_labels`
--
ALTER TABLE `racking_labels`
  ADD PRIMARY KEY (`label_id`),
  ADD UNIQUE KEY `label_code` (`label_code`),
  ADD KEY `idx_label_code` (`label_code`),
  ADD KEY `idx_is_available` (`is_available`);

--
-- Indexes for table `requests`
--
ALTER TABLE `requests`
  ADD PRIMARY KEY (`request_id`),
  ADD KEY `idx_client_id` (`client_id`),
  ADD KEY `idx_request_type` (`request_type`),
  ADD KEY `idx_status` (`status`),
  ADD KEY `idx_client_status` (`client_id`,`status`),
  ADD KEY `idx_requested_date` (`requested_date`),
  ADD KEY `box_id` (`box_id`);

--
-- Indexes for table `retrievals`
--
ALTER TABLE `retrievals`
  ADD PRIMARY KEY (`retrieval_id`),
  ADD KEY `idx_client_id` (`client_id`),
  ADD KEY `idx_box_id` (`box_id`),
  ADD KEY `idx_retrieval_date` (`retrieval_date`),
  ADD KEY `idx_client_date` (`client_id`,`retrieval_date`),
  ADD KEY `idx_created_by` (`created_by`);

--
-- Indexes for table `token_blacklist`
--
ALTER TABLE `token_blacklist`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `idx_token_hash` (`token_hash`),
  ADD KEY `idx_expires` (`expires_at`),
  ADD KEY `idx_user_id` (`user_id`);

--
-- Indexes for table `users`
--
ALTER TABLE `users`
  ADD PRIMARY KEY (`user_id`),
  ADD UNIQUE KEY `username` (`username`),
  ADD UNIQUE KEY `email` (`email`),
  ADD KEY `idx_username` (`username`),
  ADD KEY `idx_email` (`email`),
  ADD KEY `idx_role` (`role`),
  ADD KEY `idx_client_id` (`client_id`),
  ADD KEY `idx_is_active` (`is_active`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `audit_logs`
--
ALTER TABLE `audit_logs`
  MODIFY `audit_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=103;

--
-- AUTO_INCREMENT for table `boxes`
--
ALTER TABLE `boxes`
  MODIFY `box_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=20;

--
-- AUTO_INCREMENT for table `clients`
--
ALTER TABLE `clients`
  MODIFY `client_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6;

--
-- AUTO_INCREMENT for table `collections`
--
ALTER TABLE `collections`
  MODIFY `collection_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT for table `daily_stats`
--
ALTER TABLE `daily_stats`
  MODIFY `stat_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT for table `deliveries`
--
ALTER TABLE `deliveries`
  MODIFY `delivery_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT for table `permissions`
--
ALTER TABLE `permissions`
  MODIFY `permission_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT for table `racking_labels`
--
ALTER TABLE `racking_labels`
  MODIFY `label_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=18;

--
-- AUTO_INCREMENT for table `requests`
--
ALTER TABLE `requests`
  MODIFY `request_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT for table `retrievals`
--
ALTER TABLE `retrievals`
  MODIFY `retrieval_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT for table `token_blacklist`
--
ALTER TABLE `token_blacklist`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT for table `users`
--
ALTER TABLE `users`
  MODIFY `user_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- Constraints for dumped tables
--

--
-- Constraints for table `audit_logs`
--
ALTER TABLE `audit_logs`
  ADD CONSTRAINT `audit_logs_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE SET NULL;

--
-- Constraints for table `boxes`
--
ALTER TABLE `boxes`
  ADD CONSTRAINT `boxes_ibfk_1` FOREIGN KEY (`client_id`) REFERENCES `clients` (`client_id`),
  ADD CONSTRAINT `boxes_ibfk_2` FOREIGN KEY (`racking_label_id`) REFERENCES `racking_labels` (`label_id`) ON DELETE SET NULL;

--
-- Constraints for table `collections`
--
ALTER TABLE `collections`
  ADD CONSTRAINT `collections_ibfk_1` FOREIGN KEY (`client_id`) REFERENCES `clients` (`client_id`),
  ADD CONSTRAINT `collections_ibfk_2` FOREIGN KEY (`created_by`) REFERENCES `users` (`user_id`) ON DELETE SET NULL;

--
-- Constraints for table `deliveries`
--
ALTER TABLE `deliveries`
  ADD CONSTRAINT `deliveries_ibfk_1` FOREIGN KEY (`client_id`) REFERENCES `clients` (`client_id`),
  ADD CONSTRAINT `deliveries_ibfk_2` FOREIGN KEY (`created_by`) REFERENCES `users` (`user_id`) ON DELETE SET NULL;

--
-- Constraints for table `permissions`
--
ALTER TABLE `permissions`
  ADD CONSTRAINT `permissions_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE;

--
-- Constraints for table `requests`
--
ALTER TABLE `requests`
  ADD CONSTRAINT `requests_ibfk_1` FOREIGN KEY (`client_id`) REFERENCES `clients` (`client_id`),
  ADD CONSTRAINT `requests_ibfk_2` FOREIGN KEY (`box_id`) REFERENCES `boxes` (`box_id`) ON DELETE SET NULL;

--
-- Constraints for table `retrievals`
--
ALTER TABLE `retrievals`
  ADD CONSTRAINT `retrievals_ibfk_1` FOREIGN KEY (`client_id`) REFERENCES `clients` (`client_id`),
  ADD CONSTRAINT `retrievals_ibfk_2` FOREIGN KEY (`box_id`) REFERENCES `boxes` (`box_id`),
  ADD CONSTRAINT `retrievals_ibfk_3` FOREIGN KEY (`created_by`) REFERENCES `users` (`user_id`) ON DELETE SET NULL;

--
-- Constraints for table `token_blacklist`
--
ALTER TABLE `token_blacklist`
  ADD CONSTRAINT `token_blacklist_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE;

--
-- Constraints for table `users`
--
ALTER TABLE `users`
  ADD CONSTRAINT `fk_users_client` FOREIGN KEY (`client_id`) REFERENCES `clients` (`client_id`) ON DELETE SET NULL;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
