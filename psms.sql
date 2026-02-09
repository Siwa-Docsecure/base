-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1
-- Generation Time: Jan 13, 2026 at 12:18 PM
-- Server version: 10.4.32-MariaDB
-- PHP Version: 8.2.12

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
(22, 1, 'LOGIN', 'auth', NULL, NULL, '{\"username\":\"admin\",\"role\":\"admin\"}', '::ffff:127.0.0.1', 'Dart/3.7 (dart:io)', '2026-01-13 10:45:31');

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

INSERT INTO `boxes` (`box_id`, `box_number`, `client_id`, `racking_label_id`, `box_description`, `date_received`, `year_received`, `retention_years`, `destruction_year`, `status`, `created_at`, `updated_at`) VALUES
(1, 'BOX-001-2024', 1, 1, 'Financial Records 2024 - Q1 to Q4', '2024-01-15', 2024, 7, 2031, 'stored', '2025-11-18 11:11:04', '2025-11-18 11:11:04'),
(2, 'BOX-002-2024', 1, 2, 'HR Documents 2024 - Employee Files', '2024-02-20', 2024, 7, 2031, 'stored', '2025-11-18 11:11:04', '2025-11-18 11:11:04'),
(3, 'BOX-003-2024', 1, 3, 'Legal Contracts 2024', '2024-03-10', 2024, 10, 2034, 'stored', '2025-11-18 11:11:04', '2025-11-18 11:11:04'),
(4, 'BOX-004-2024', 2, 4, 'Project Documents 2024 - Phase 1', '2024-01-25', 2024, 5, 2029, 'stored', '2025-11-18 11:11:04', '2025-11-18 11:11:04'),
(5, 'BOX-005-2024', 2, 5, 'Client Correspondence 2024', '2024-02-15', 2024, 7, 2031, 'stored', '2025-11-18 11:11:04', '2025-11-18 11:11:04'),
(6, 'BOX-006-2023', 1, 6, 'Financial Records 2023', '2023-01-10', 2023, 7, 2030, 'stored', '2025-11-18 11:11:04', '2025-11-18 11:11:04'),
(7, 'BOX-007-2023', 3, 7, 'Technical Documentation 2023', '2023-03-15', 2023, 7, 2030, 'stored', '2025-11-18 11:11:04', '2025-11-18 11:11:04'),
(8, 'BOX-008-2023', 3, 8, 'Employee Records 2023', '2023-04-20', 2023, 7, 2030, 'stored', '2025-11-18 11:11:04', '2025-11-18 11:11:04'),
(9, 'BOX-009-2022', 2, 9, 'Archive Documents 2022', '2022-12-15', 2022, 7, 2029, 'stored', '2025-11-18 11:11:04', '2025-11-18 11:11:04'),
(10, 'BOX-010-2022', 4, 10, 'Legal Files 2022', '2022-11-10', 2022, 10, 2032, 'stored', '2025-11-18 11:11:04', '2025-11-18 11:11:04'),
(11, 'BOX-011-2018', 1, 11, 'Old Records 2018 - Pending Destruction', '2018-01-15', 2018, 7, 2025, 'stored', '2025-11-18 11:11:04', '2025-11-18 11:11:04'),
(12, 'BOX-012-2024', 5, 12, 'Sales Records 2024', '2024-05-10', 2024, 5, 2029, 'stored', '2025-11-18 11:11:04', '2025-11-18 11:11:04'),
(13, 'BOX-013-2024', 5, 13, 'Marketing Materials 2024', '2024-06-15', 2024, 3, 2027, 'stored', '2025-11-18 11:11:04', '2025-11-18 11:11:04'),
(14, 'BOX-014-2023', 4, 14, 'Annual Reports 2023', '2023-12-20', 2023, 10, 2033, 'stored', '2025-11-18 11:11:04', '2025-11-18 11:11:04'),
(15, 'BOX-015-2023', 3, 15, 'Compliance Documents 2023', '2023-11-25', 2023, 7, 2030, 'stored', '2025-11-18 11:11:04', '2025-11-18 11:11:04');

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
(1, 1, 5, 'Financial and HR records for 2024', 'John Smith', 'Staff Member', NULL, NULL, '2024-11-15', NULL, 2, '2025-11-18 11:11:04');

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
(15, 'RACK-C-05', 'Warehouse C - Section 3 - Level 1', 1, '2025-11-18 11:11:04', '2025-11-18 11:11:04');

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
(1, 1, 'retrieval', 2, 'Need HR documents for employee verification', 'pending', '2024-11-18', NULL, '2025-11-18 11:11:04', '2025-11-18 11:11:04');

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
(1, 1, 1, '2024-11-16', 'John Smith', 'Needed for audit purposes', NULL, NULL, NULL, 2, '2025-11-18 11:11:04');

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
(2, 'a27a02e76a7befcca09a39f81accd8ed5121dd6fbe49e88dba8e29223b770bad', 1, '2026-01-09 14:37:37', '2026-01-08 14:49:49');

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
  MODIFY `audit_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=23;

--
-- AUTO_INCREMENT for table `boxes`
--
ALTER TABLE `boxes`
  MODIFY `box_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=16;

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
  MODIFY `label_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=16;

--
-- AUTO_INCREMENT for table `requests`
--
ALTER TABLE `requests`
  MODIFY `request_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT for table `retrievals`
--
ALTER TABLE `retrievals`
  MODIFY `retrieval_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT for table `token_blacklist`
--
ALTER TABLE `token_blacklist`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

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
