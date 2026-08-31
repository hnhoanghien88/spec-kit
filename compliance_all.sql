-- MySQL dump 10.13  Distrib 8.0.46, for Win64 (x86_64)
--
-- Host: 10.123.10.222    Database: compliance_sys_db
-- ------------------------------------------------------
-- Server version	8.0.44

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `compl_code_sequences`
--

DROP TABLE IF EXISTS `compl_code_sequences`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `compl_code_sequences` (
  `Id` bigint NOT NULL AUTO_INCREMENT,
  `Prefix` varchar(20) NOT NULL,
  `Separator` char(1) DEFAULT '-',
  `Number` int NOT NULL DEFAULT '0',
  `PaddingLength` int DEFAULT '5',
  `CreatedDate` datetime DEFAULT CURRENT_TIMESTAMP,
  `UpdatedDate` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`Id`),
  UNIQUE KEY `Prefix` (`Prefix`)
) ENGINE=InnoDB AUTO_INCREMENT=13 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `compl_compliance_group_email`
--

DROP TABLE IF EXISTS `compl_compliance_group_email`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `compl_compliance_group_email` (
  `Id` bigint NOT NULL AUTO_INCREMENT,
  `ComplianceId` bigint NOT NULL,
  `GroupEmailId` bigint NOT NULL,
  `GroupType` tinyint NOT NULL,
  `CreatedDate` datetime DEFAULT CURRENT_TIMESTAMP,
  `CreatedBy` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`Id`),
  UNIQUE KEY `UK_Compliance_Group_Type` (`ComplianceId`,`GroupEmailId`,`GroupType`),
  KEY `FK_GroupEmail` (`GroupEmailId`),
  CONSTRAINT `FK_Compliance` FOREIGN KEY (`ComplianceId`) REFERENCES `compl_compliances` (`Id`) ON DELETE CASCADE,
  CONSTRAINT `FK_GroupEmail` FOREIGN KEY (`GroupEmailId`) REFERENCES `compl_group_email` (`Id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=4747 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `compl_compliances`
--

DROP TABLE IF EXISTS `compl_compliances`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `compl_compliances` (
  `Id` bigint NOT NULL AUTO_INCREMENT,
  `Code` varchar(100) NOT NULL,
  `Name` varchar(255) NOT NULL,
  `ValidFrom` datetime NOT NULL,
  `ValidTo` datetime DEFAULT NULL,
  `FileId` varchar(255) DEFAULT NULL,
  `Description` varchar(1000) DEFAULT NULL,
  `NumDayAlert` int DEFAULT NULL,
  `DocumentTypeId` bigint DEFAULT NULL,
  `DocumentValue` text,
  `IsDelete` tinyint(1) DEFAULT '0',
  `VersionNo` int DEFAULT '1',
  `ReplacedById` bigint DEFAULT NULL,
  `CreatedDate` datetime DEFAULT CURRENT_TIMESTAMP,
  `CreatedBy` varchar(50) DEFAULT NULL,
  `UpdatedDate` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `UpdatedBy` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`Id`),
  KEY `fk_compliance_document_type` (`DocumentTypeId`),
  KEY `idx_compl_compliances_validity` (`ValidFrom`,`ValidTo`),
  KEY `idx_code_version` (`Code`,`VersionNo`),
  FULLTEXT KEY `ft_search_compliances_idx` (`Name`,`Code`,`Description`),
  CONSTRAINT `fk_compliance_document_type` FOREIGN KEY (`DocumentTypeId`) REFERENCES `compl_document_type` (`Id`) ON DELETE RESTRICT
) ENGINE=InnoDB AUTO_INCREMENT=2321 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `compl_config`
--

DROP TABLE IF EXISTS `compl_config`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `compl_config` (
  `ConfigKey` varchar(100) NOT NULL,
  `ConfigValue` varchar(500) DEFAULT NULL,
  `Description` varchar(255) DEFAULT NULL,
  `CreatedDate` datetime DEFAULT CURRENT_TIMESTAMP,
  `CreatedBy` varchar(50) DEFAULT NULL,
  `UpdatedDate` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `UpdatedBy` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`ConfigKey`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `compl_country_group_members`
--

DROP TABLE IF EXISTS `compl_country_group_members`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `compl_country_group_members` (
  `Id` bigint NOT NULL AUTO_INCREMENT,
  `GroupId` bigint NOT NULL,
  `CountryCode` varchar(10) NOT NULL COMMENT 'ISO 3-letter: DEU, FRA, ...',
  PRIMARY KEY (`Id`),
  UNIQUE KEY `uq_group_country` (`GroupId`,`CountryCode`),
  KEY `idx_country_code` (`CountryCode`),
  CONSTRAINT `fk_cgm_group` FOREIGN KEY (`GroupId`) REFERENCES `compl_country_groups` (`Id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=28 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `compl_country_groups`
--

DROP TABLE IF EXISTS `compl_country_groups`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `compl_country_groups` (
  `Id` bigint NOT NULL AUTO_INCREMENT,
  `Code` varchar(20) NOT NULL COMMENT 'VD: EU, ASEAN, G7',
  `Name` varchar(100) NOT NULL,
  `Description` varchar(255) DEFAULT NULL,
  `IsActive` tinyint(1) DEFAULT '1',
  `CreatedDate` datetime DEFAULT CURRENT_TIMESTAMP,
  `CreatedBy` varchar(50) DEFAULT NULL,
  `UpdatedDate` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `UpdatedBy` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`Id`),
  UNIQUE KEY `uq_country_group_code` (`Code`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `compl_document_type`
--

DROP TABLE IF EXISTS `compl_document_type`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `compl_document_type` (
  `Id` bigint NOT NULL AUTO_INCREMENT,
  `Name` varchar(255) DEFAULT NULL,
  `Location` varchar(255) DEFAULT NULL,
  `CreatedDate` datetime DEFAULT CURRENT_TIMESTAMP,
  `CreatedBy` varchar(50) DEFAULT NULL,
  `UpdatedDate` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `UpdatedBy` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`Id`)
) ENGINE=InnoDB AUTO_INCREMENT=8 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `compl_group_email`
--

DROP TABLE IF EXISTS `compl_group_email`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `compl_group_email` (
  `Id` bigint NOT NULL AUTO_INCREMENT,
  `Name` varchar(255) DEFAULT NULL,
  `GroupType` tinyint DEFAULT NULL,
  `IsDefault` tinyint(1) DEFAULT NULL,
  `IsAddition` tinyint(1) DEFAULT '0',
  `CreatedDate` datetime DEFAULT CURRENT_TIMESTAMP,
  `CreatedBy` varchar(50) DEFAULT NULL,
  `UpdatedDate` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `UpdatedBy` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`Id`)
) ENGINE=InnoDB AUTO_INCREMENT=24 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `compl_group_email_detail`
--

DROP TABLE IF EXISTS `compl_group_email_detail`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `compl_group_email_detail` (
  `Id` bigint NOT NULL AUTO_INCREMENT,
  `GroupEmailId` bigint NOT NULL,
  `Name` varchar(255) DEFAULT NULL,
  `ResponseEmail` varchar(100) DEFAULT NULL,
  `ExternalEmail` varchar(100) DEFAULT NULL,
  `IsActive` tinyint(1) DEFAULT '1',
  `CreatedDate` datetime DEFAULT CURRENT_TIMESTAMP,
  `CreatedBy` varchar(50) DEFAULT NULL,
  `UpdatedDate` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `UpdatedBy` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`Id`),
  KEY `compl_group_email_detail_ibfk_1` (`GroupEmailId`),
  KEY `idx_group_email_detail_active` (`GroupEmailId`,`IsActive`,`ResponseEmail`),
  CONSTRAINT `compl_group_email_detail_ibfk_1` FOREIGN KEY (`GroupEmailId`) REFERENCES `compl_group_email` (`Id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=62 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `compl_history`
--

DROP TABLE IF EXISTS `compl_history`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `compl_history` (
  `Id` bigint NOT NULL AUTO_INCREMENT,
  `TableName` varchar(100) NOT NULL,
  `RecordId` bigint NOT NULL,
  `RecordCode` varchar(45) DEFAULT NULL,
  `Action` varchar(50) NOT NULL,
  `ActionDetail` text,
  `OldValue` json DEFAULT NULL,
  `NewValue` json DEFAULT NULL,
  `ActionDate` datetime DEFAULT CURRENT_TIMESTAMP,
  `ActionBy` varchar(100) NOT NULL,
  `IsVersionChange` tinyint(1) DEFAULT '0',
  PRIMARY KEY (`Id`)
) ENGINE=InnoDB AUTO_INCREMENT=3650 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `compl_job_schedule_configs`
--

DROP TABLE IF EXISTS `compl_job_schedule_configs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `compl_job_schedule_configs` (
  `Id` int NOT NULL AUTO_INCREMENT,
  `JobId` varchar(100) NOT NULL COMMENT 'Hangfire job key, e.g. sent_alert_compliance',
  `JobName` varchar(200) NOT NULL COMMENT 'Tên hiển thị',
  `Description` text COMMENT 'Mô tả chức năng',
  `ServiceType` varchar(500) NOT NULL COMMENT 'Full interface name, e.g. IComplNotificationService',
  `MethodName` varchar(200) NOT NULL COMMENT 'Tên method được gọi',
  `CronExpression` varchar(100) NOT NULL COMMENT 'VD: 0 3 * * *',
  `Timezone` varchar(100) NOT NULL DEFAULT 'SE Asia Standard Time',
  `Queue` varchar(50) NOT NULL DEFAULT 'default',
  `IsEnabled` tinyint(1) NOT NULL DEFAULT '1',
  `CreatedAt` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `UpdatedAt` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `CreatedBy` varchar(200) DEFAULT NULL,
  `UpdatedBy` varchar(200) DEFAULT NULL,
  PRIMARY KEY (`Id`),
  UNIQUE KEY `JobId` (`JobId`),
  UNIQUE KEY `UQ_compl_job_schedule_configs_JobId` (`JobId`)
) ENGINE=InnoDB AUTO_INCREMENT=8 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='Cấu hình lịch chạy Hangfire recurring jobs';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `compl_master_condition_values`
--

DROP TABLE IF EXISTS `compl_master_condition_values`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `compl_master_condition_values` (
  `Id` bigint NOT NULL AUTO_INCREMENT,
  `ConditionId` bigint NOT NULL,
  `RefTypeValue` varchar(255) NOT NULL,
  PRIMARY KEY (`Id`),
  KEY `idx_value` (`RefTypeValue`),
  KEY `idx_master_condition_values` (`ConditionId`),
  CONSTRAINT `compl_master_condition_values_ibfk_1` FOREIGN KEY (`ConditionId`) REFERENCES `compl_master_conditions` (`Id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=2114 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `compl_master_conditions`
--

DROP TABLE IF EXISTS `compl_master_conditions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `compl_master_conditions` (
  `Id` bigint NOT NULL AUTO_INCREMENT,
  `MasterId` bigint NOT NULL,
  `RefTypeId` bigint NOT NULL,
  `Operator` varchar(10) NOT NULL DEFAULT '=',
  `Logical` int DEFAULT '1',
  `ComplType` tinyint NOT NULL DEFAULT '0',
  `DisplayType` int DEFAULT '0',
  PRIMARY KEY (`Id`),
  KEY `fk_compl_master_conditions_reference_type` (`RefTypeId`),
  KEY `idx_master_conditions_masterid` (`MasterId`,`ComplType`),
  CONSTRAINT `fk_compl_master_conditions_reference_type` FOREIGN KEY (`RefTypeId`) REFERENCES `compl_reference_types` (`Id`) ON DELETE RESTRICT,
  CONSTRAINT `fk_compl_masters_condition` FOREIGN KEY (`MasterId`) REFERENCES `compl_masters` (`Id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=1601 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `compl_master_default_configs`
--

DROP TABLE IF EXISTS `compl_master_default_configs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `compl_master_default_configs` (
  `Id` bigint NOT NULL AUTO_INCREMENT,
  `Code` varchar(50) NOT NULL,
  `Name` varchar(255) NOT NULL,
  `Note` varchar(500) DEFAULT NULL,
  `TriggerId` bigint NOT NULL COMMENT 'FK compl_ref_trigger',
  `TriggerRefTypeId` bigint NOT NULL,
  `IsActive` tinyint(1) NOT NULL DEFAULT '1',
  `CreatedDate` datetime DEFAULT CURRENT_TIMESTAMP,
  `CreatedBy` varchar(50) DEFAULT NULL,
  `UpdatedDate` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `UpdatedBy` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`Id`),
  UNIQUE KEY `uq_mdc_code` (`Code`),
  KEY `fk_mdc_trigger_ref` (`TriggerRefTypeId`),
  KEY `fk_mdc_trigger` (`TriggerId`),
  CONSTRAINT `fk_mdc_trigger` FOREIGN KEY (`TriggerId`) REFERENCES `compl_ref_trigger` (`Id`) ON DELETE RESTRICT,
  CONSTRAINT `fk_mdc_trigger_ref` FOREIGN KEY (`TriggerRefTypeId`) REFERENCES `compl_reference_types` (`Id`) ON DELETE RESTRICT
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `compl_master_default_logs`
--

DROP TABLE IF EXISTS `compl_master_default_logs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `compl_master_default_logs` (
  `Id` bigint NOT NULL AUTO_INCREMENT,
  `ConfigId` bigint NOT NULL,
  `TemplateId` bigint DEFAULT NULL,
  `TrackedObjectId` bigint NOT NULL,
  `CreatedMasterId` bigint DEFAULT NULL,
  `Status` enum('SUCCESS','FAILED','SKIPPED') NOT NULL DEFAULT 'SUCCESS',
  `ErrorMessage` text,
  `ProcessedAt` datetime DEFAULT CURRENT_TIMESTAMP,
  `IsSendMail` tinyint(1) NOT NULL DEFAULT '0' COMMENT 'Flag indicating whether a mail has been sent for this log entry',
  PRIMARY KEY (`Id`),
  KEY `idx_log_config` (`ConfigId`),
  KEY `idx_log_tracked` (`TrackedObjectId`),
  KEY `idx_log_status` (`Status`,`ProcessedAt`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `compl_master_default_template_condition_values`
--

DROP TABLE IF EXISTS `compl_master_default_template_condition_values`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `compl_master_default_template_condition_values` (
  `Id` bigint NOT NULL AUTO_INCREMENT,
  `ConditionId` bigint NOT NULL,
  `RefTypeValue` varchar(255) NOT NULL,
  `SortOrder` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`Id`),
  KEY `fk_tcv_condition` (`ConditionId`),
  CONSTRAINT `fk_tcv_condition` FOREIGN KEY (`ConditionId`) REFERENCES `compl_master_default_template_conditions` (`Id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `compl_master_default_template_conditions`
--

DROP TABLE IF EXISTS `compl_master_default_template_conditions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `compl_master_default_template_conditions` (
  `Id` bigint NOT NULL AUTO_INCREMENT,
  `TemplateId` bigint NOT NULL,
  `RefTypeId` bigint NOT NULL,
  `ValueSource` enum('NEW_VALUE','FIXED','NOT_IN') NOT NULL,
  `Operator` varchar(10) NOT NULL DEFAULT 'IN',
  `Logical` int NOT NULL DEFAULT '1',
  `ComplType` tinyint NOT NULL DEFAULT '0',
  `DisplayType` int DEFAULT '0',
  `SortOrder` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`Id`),
  KEY `fk_tc_template` (`TemplateId`),
  KEY `fk_tc_ref_type` (`RefTypeId`),
  CONSTRAINT `fk_tc_ref_type` FOREIGN KEY (`RefTypeId`) REFERENCES `compl_reference_types` (`Id`) ON DELETE RESTRICT,
  CONSTRAINT `fk_tc_template` FOREIGN KEY (`TemplateId`) REFERENCES `compl_master_default_templates` (`Id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=33 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `compl_master_default_template_group_email`
--

DROP TABLE IF EXISTS `compl_master_default_template_group_email`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `compl_master_default_template_group_email` (
  `Id` bigint NOT NULL AUTO_INCREMENT,
  `TemplateId` bigint NOT NULL,
  `GroupEmailId` bigint NOT NULL,
  `GroupType` tinyint NOT NULL,
  `CreatedDate` datetime DEFAULT CURRENT_TIMESTAMP,
  `CreatedBy` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`Id`),
  UNIQUE KEY `UK_Master_Default_Group_Type` (`TemplateId`,`GroupEmailId`,`GroupType`),
  KEY `FK_Master_Default_GroupEmail` (`GroupEmailId`),
  KEY `idx_master_default_group_email_composite` (`TemplateId`,`GroupType`,`GroupEmailId`),
  CONSTRAINT `FK_Master_Default` FOREIGN KEY (`TemplateId`) REFERENCES `compl_master_default_templates` (`Id`) ON DELETE CASCADE,
  CONSTRAINT `FK_Master_Default_GroupEmail` FOREIGN KEY (`GroupEmailId`) REFERENCES `compl_group_email` (`Id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=55 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `compl_master_default_templates`
--

DROP TABLE IF EXISTS `compl_master_default_templates`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `compl_master_default_templates` (
  `Id` bigint NOT NULL AUTO_INCREMENT,
  `ConfigId` bigint NOT NULL,
  `Name` varchar(255) NOT NULL,
  `ValidFrom` datetime NOT NULL,
  `ValidTo` datetime DEFAULT NULL,
  `NumDayAlert` int DEFAULT '60',
  `Description` varchar(500) DEFAULT NULL,
  `SortOrder` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`Id`),
  KEY `fk_tmpl_config` (`ConfigId`),
  CONSTRAINT `fk_tmpl_config` FOREIGN KEY (`ConfigId`) REFERENCES `compl_master_default_configs` (`Id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=28 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `compl_master_default_trigger_condition_values`
--

DROP TABLE IF EXISTS `compl_master_default_trigger_condition_values`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `compl_master_default_trigger_condition_values` (
  `Id` bigint NOT NULL AUTO_INCREMENT,
  `ConditionId` bigint NOT NULL,
  `RefTypeValue` varchar(255) NOT NULL,
  `SortOrder` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`Id`),
  KEY `idx_mdtcv_condition` (`ConditionId`,`SortOrder`),
  KEY `idx_mdtcv_value` (`RefTypeValue`),
  CONSTRAINT `fk_mdtcv_condition` FOREIGN KEY (`ConditionId`) REFERENCES `compl_master_default_trigger_conditions` (`Id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `compl_master_default_trigger_conditions`
--

DROP TABLE IF EXISTS `compl_master_default_trigger_conditions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `compl_master_default_trigger_conditions` (
  `Id` bigint NOT NULL AUTO_INCREMENT,
  `ConfigId` bigint NOT NULL,
  `TriggerId` bigint NOT NULL COMMENT 'FK compl_ref_trigger',
  `TriggerRefTypeId` bigint NOT NULL,
  `SortOrder` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`Id`),
  KEY `idx_mdtc_config` (`ConfigId`,`SortOrder`),
  KEY `idx_mdtc_trigger` (`TriggerId`,`TriggerRefTypeId`),
  KEY `fk_mdtc_trigger_ref` (`TriggerRefTypeId`),
  CONSTRAINT `fk_mdtc_config` FOREIGN KEY (`ConfigId`) REFERENCES `compl_master_default_configs` (`Id`) ON DELETE CASCADE,
  CONSTRAINT `fk_mdtc_trigger` FOREIGN KEY (`TriggerId`) REFERENCES `compl_ref_trigger` (`Id`) ON DELETE RESTRICT,
  CONSTRAINT `fk_mdtc_trigger_ref` FOREIGN KEY (`TriggerRefTypeId`) REFERENCES `compl_reference_types` (`Id`) ON DELETE RESTRICT
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `compl_master_group_email`
--

DROP TABLE IF EXISTS `compl_master_group_email`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `compl_master_group_email` (
  `Id` bigint NOT NULL AUTO_INCREMENT,
  `MasterId` bigint NOT NULL,
  `GroupEmailId` bigint NOT NULL,
  `GroupType` tinyint NOT NULL,
  `CreatedDate` datetime DEFAULT CURRENT_TIMESTAMP,
  `CreatedBy` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`Id`),
  UNIQUE KEY `UK_Master_Group_Type` (`MasterId`,`GroupEmailId`,`GroupType`),
  KEY `FK_Master_GroupEmail` (`GroupEmailId`),
  KEY `idx_master_group_email_composite` (`MasterId`,`GroupType`,`GroupEmailId`),
  CONSTRAINT `FK_Master` FOREIGN KEY (`MasterId`) REFERENCES `compl_masters` (`Id`) ON DELETE CASCADE,
  CONSTRAINT `FK_Master_GroupEmail` FOREIGN KEY (`GroupEmailId`) REFERENCES `compl_group_email` (`Id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=2577 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `compl_master_hierarchies`
--

DROP TABLE IF EXISTS `compl_master_hierarchies`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `compl_master_hierarchies` (
  `Id` bigint NOT NULL AUTO_INCREMENT,
  `MasterCode` varchar(50) NOT NULL,
  `ParentCode` varchar(50) NOT NULL DEFAULT '',
  `DisplayOrder` int NOT NULL DEFAULT '0',
  `CreatedDate` datetime DEFAULT CURRENT_TIMESTAMP,
  `CreatedBy` varchar(50) DEFAULT NULL,
  `UpdatedDate` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `UpdatedBy` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`Id`),
  UNIQUE KEY `uq_compl_master_hierarchy` (`MasterCode`,`ParentCode`),
  KEY `idx_compl_master_hierarchy_parent` (`ParentCode`)
) ENGINE=InnoDB AUTO_INCREMENT=10 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `compl_masters`
--

DROP TABLE IF EXISTS `compl_masters`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `compl_masters` (
  `Id` bigint NOT NULL AUTO_INCREMENT,
  `Code` varchar(50) NOT NULL,
  `Name` varchar(255) NOT NULL,
  `ValidFrom` datetime NOT NULL,
  `ValidTo` datetime DEFAULT NULL,
  `NumDayAlert` int DEFAULT NULL,
  `Description` varchar(500) DEFAULT NULL,
  `IsIndividual` tinyint(1) DEFAULT '0',
  `IsDelete` tinyint(1) DEFAULT '0',
  `VersionNo` int DEFAULT '1',
  `ReplacedById` bigint DEFAULT NULL,
  `DuplicateId` bigint DEFAULT NULL,
  `CreatedDate` datetime DEFAULT CURRENT_TIMESTAMP,
  `CreatedBy` varchar(50) DEFAULT NULL,
  `UpdatedDate` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `UpdatedBy` varchar(50) DEFAULT NULL,
  `AlertType` tinyint DEFAULT '0',
  PRIMARY KEY (`Id`),
  UNIQUE KEY `uq_compl_master_code` (`Code`,`VersionNo`),
  KEY `idx_masters_validto` (`ValidTo`),
  KEY `idx_masters_createdby` (`CreatedBy`),
  FULLTEXT KEY `ft_search_master_idx` (`Name`,`Code`,`Description`),
  FULLTEXT KEY `ft_master_name_code` (`Name`,`Code`)
) ENGINE=InnoDB AUTO_INCREMENT=1178 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `compl_notifications`
--

DROP TABLE IF EXISTS `compl_notifications`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `compl_notifications` (
  `Id` bigint NOT NULL AUTO_INCREMENT,
  `UserEmail` varchar(100) NOT NULL,
  `Title` varchar(255) DEFAULT NULL,
  `Message` varchar(255) NOT NULL,
  `Type` varchar(50) DEFAULT NULL,
  `RedirectType` enum('Compliance','compl') NOT NULL,
  `RedirectId` int NOT NULL,
  `IsRead` tinyint(1) DEFAULT '0',
  `CreatedDate` datetime DEFAULT CURRENT_TIMESTAMP,
  `CreatedBy` varchar(50) DEFAULT NULL,
  `UpdatedDate` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `UpdatedBy` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`Id`),
  KEY `idx_user_email` (`UserEmail`),
  KEY `idx_redirect_type` (`RedirectType`)
) ENGINE=InnoDB AUTO_INCREMENT=22058 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `compl_ref_tracked_objects`
--

DROP TABLE IF EXISTS `compl_ref_tracked_objects`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `compl_ref_tracked_objects` (
  `Id` bigint NOT NULL AUTO_INCREMENT,
  `RefTypeId` bigint NOT NULL COMMENT 'FK to compl_reference_types',
  `TriggerId` bigint DEFAULT NULL COMMENT 'FK compl_ref_trigger',
  `Code` varchar(100) DEFAULT NULL,
  `Name` varchar(255) DEFAULT NULL,
  `RefValue` text,
  `GroupValue` varchar(255) DEFAULT NULL COMMENT 'RSVNAttributeTypeValueAlls.GroupValue',
  `IsNew` tinyint(1) NOT NULL DEFAULT '1',
  `CreatedDate` datetime DEFAULT CURRENT_TIMESTAMP,
  `CreatedBy` varchar(50) DEFAULT NULL,
  `UpdatedDate` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `UpdatedBy` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`Id`),
  UNIQUE KEY `uq_tracked_reftype_code` (`RefTypeId`,`Code`),
  KEY `idx_tracked_is_new` (`IsNew`,`RefTypeId`),
  KEY `idx_tracked_trigger` (`TriggerId`),
  CONSTRAINT `fk_tracked_ref_type` FOREIGN KEY (`RefTypeId`) REFERENCES `compl_reference_types` (`Id`) ON DELETE RESTRICT,
  CONSTRAINT `fk_tracked_trigger` FOREIGN KEY (`TriggerId`) REFERENCES `compl_ref_trigger` (`Id`) ON DELETE RESTRICT
) ENGINE=InnoDB AUTO_INCREMENT=216721 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `compl_ref_trigger`
--

DROP TABLE IF EXISTS `compl_ref_trigger`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `compl_ref_trigger` (
  `Id` bigint NOT NULL AUTO_INCREMENT,
  `RefTypeId` bigint NOT NULL COMMENT 'FK to compl_reference_types',
  `Model365` varchar(100) DEFAULT NULL,
  `Filter365` varchar(255) DEFAULT NULL COMMENT 'vd: Upholstery type "AttributeTypeRecId = 5637149831"',
  `DisplayName` varchar(255) DEFAULT NULL,
  `Description` varchar(1500) DEFAULT NULL,
  `IsShow` tinyint(1) NOT NULL DEFAULT '1',
  `SortOrder` int NOT NULL DEFAULT '0',
  `CreatedDate` datetime DEFAULT CURRENT_TIMESTAMP,
  `CreatedBy` varchar(50) DEFAULT NULL,
  `UpdatedDate` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `UpdatedBy` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`Id`),
  UNIQUE KEY `uq_compl_ref_trigger` (`RefTypeId`,`Model365`,`Filter365`),
  CONSTRAINT `fk_compl_ref_trigger` FOREIGN KEY (`RefTypeId`) REFERENCES `compl_reference_types` (`Id`) ON DELETE RESTRICT
) ENGINE=InnoDB AUTO_INCREMENT=9 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `compl_reference_types`
--

DROP TABLE IF EXISTS `compl_reference_types`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `compl_reference_types` (
  `Id` bigint NOT NULL AUTO_INCREMENT,
  `Code` varchar(20) DEFAULT NULL,
  `Name` varchar(100) NOT NULL,
  `DisplayOrder` int DEFAULT NULL,
  `Model365` varchar(150) DEFAULT NULL,
  `IsActive` tinyint(1) DEFAULT '1',
  `Description` varchar(255) DEFAULT NULL,
  `CreatedDate` datetime DEFAULT CURRENT_TIMESTAMP,
  `CreatedBy` varchar(50) DEFAULT NULL,
  `UpdatedDate` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `UpdatedBy` varchar(50) DEFAULT NULL,
  `AllowIndividual` tinyint(1) DEFAULT '1',
  PRIMARY KEY (`Id`),
  KEY `idx_active` (`IsActive`)
) ENGINE=InnoDB AUTO_INCREMENT=14 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `compl_references`
--

DROP TABLE IF EXISTS `compl_references`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `compl_references` (
  `Id` bigint NOT NULL AUTO_INCREMENT,
  `MasterId` bigint NOT NULL,
  `ComplianceId` bigint NOT NULL,
  `ComplType` tinyint NOT NULL DEFAULT '0',
  `RefTypeId` bigint DEFAULT NULL,
  `RefTypeValue` varchar(255) DEFAULT NULL,
  `ValidFrom` datetime DEFAULT CURRENT_TIMESTAMP,
  `ValidTo` datetime DEFAULT NULL,
  PRIMARY KEY (`Id`),
  UNIQUE KEY `uq_compl_ref_master_ref` (`MasterId`,`ComplianceId`,`RefTypeId`,`RefTypeValue`),
  KEY `fk_compl_references_compliance` (`ComplianceId`),
  KEY `fk_compl_references_reference_type` (`RefTypeId`),
  KEY `idx_references_masterid` (`MasterId`,`RefTypeId`,`RefTypeValue`,`ValidTo`),
  CONSTRAINT `fk_compl_references_compliance` FOREIGN KEY (`ComplianceId`) REFERENCES `compl_compliances` (`Id`) ON DELETE RESTRICT,
  CONSTRAINT `fk_compl_references_master` FOREIGN KEY (`MasterId`) REFERENCES `compl_masters` (`Id`) ON DELETE RESTRICT,
  CONSTRAINT `fk_compl_references_reference_type` FOREIGN KEY (`RefTypeId`) REFERENCES `compl_reference_types` (`Id`) ON DELETE RESTRICT
) ENGINE=InnoDB AUTO_INCREMENT=2351 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `compl_sharepoint_files`
--

DROP TABLE IF EXISTS `compl_sharepoint_files`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `compl_sharepoint_files` (
  `Id` bigint NOT NULL AUTO_INCREMENT,
  `FileId` varchar(255) NOT NULL,
  `DriveId` varchar(255) NOT NULL,
  `Name` varchar(1500) NOT NULL,
  `WebUrl` text,
  `DownloadUrl` text,
  `MimeType` varchar(100) DEFAULT NULL,
  `Size` bigint DEFAULT NULL,
  `Etag` varchar(255) DEFAULT NULL,
  `Ctag` varchar(255) DEFAULT NULL,
  `CreatedBy` varchar(255) DEFAULT NULL,
  `CreatedDatetime` datetime DEFAULT NULL,
  `LastModifiedBy` varchar(255) DEFAULT NULL,
  `LastModifiedDatetime` datetime DEFAULT NULL,
  `ParentId` varchar(255) DEFAULT NULL,
  `ParentName` varchar(255) DEFAULT NULL,
  `ParentPath` text,
  `FolderSharePoint` text,
  `RawJson` json DEFAULT NULL,
  `CreatedDate` datetime DEFAULT CURRENT_TIMESTAMP,
  `UpdatedDate` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `UpdatedBy` varchar(50) DEFAULT NULL,
  `IsMapped` tinyint DEFAULT '0',
  PRIMARY KEY (`Id`),
  UNIQUE KEY `uq_sharepoint_item` (`FileId`,`DriveId`)
) ENGINE=InnoDB AUTO_INCREMENT=3191 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `compl_so_missing`
--

DROP TABLE IF EXISTS `compl_so_missing`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `compl_so_missing` (
  `MasterId` bigint NOT NULL DEFAULT '0',
  `MasterCode` varchar(50) DEFAULT NULL,
  `MasterName` varchar(255) DEFAULT NULL,
  `MasterValidFrom` datetime DEFAULT NULL,
  `MasterValidTo` datetime DEFAULT NULL,
  `MasterNumDayAlert` int DEFAULT NULL,
  `MasterDescription` varchar(500) DEFAULT NULL,
  `MasterVersionNo` int DEFAULT NULL,
  `Status` varchar(7) NOT NULL DEFAULT '',
  `Id` bigint NOT NULL DEFAULT '0',
  `Code` varchar(100) NOT NULL DEFAULT '',
  `Name` varchar(511) NOT NULL DEFAULT '',
  `FileId` varchar(255) NOT NULL DEFAULT '',
  `ValidFrom` datetime DEFAULT NULL,
  `ValidTo` datetime DEFAULT NULL,
  `NumDayAlert` int DEFAULT NULL,
  `VersionNo` int DEFAULT NULL,
  `ReplacedById` bigint DEFAULT NULL,
  `Description` longtext NOT NULL,
  `AlertGroupsJson` json DEFAULT NULL,
  `ResponsibleGroupsJson` json DEFAULT NULL,
  `ConditionsJson` json DEFAULT NULL,
  `MappedRefTypeId` bigint unsigned DEFAULT NULL,
  `MappedRefTypeCode` varchar(150) DEFAULT NULL,
  `MappedRefTypeName` varchar(300) DEFAULT NULL,
  `MappedInputValue` varchar(255) DEFAULT NULL,
  `SalesId` varchar(45) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `compl_summary_so`
--

DROP TABLE IF EXISTS `compl_summary_so`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `compl_summary_so` (
  `Id` bigint NOT NULL AUTO_INCREMENT,
  `SalesOrder` varchar(50) DEFAULT NULL,
  `CusCode` varchar(100) DEFAULT NULL,
  `InvoiceDate` datetime DEFAULT NULL,
  `TotalApplied` int DEFAULT NULL,
  `TotalMissing` int DEFAULT NULL,
  `TotalOverdue` int DEFAULT NULL,
  `TotalCompliances` int DEFAULT NULL,
  `BomStatus` varchar(50) DEFAULT NULL,
  `RawJson` json DEFAULT NULL,
  `CreatedDate` datetime DEFAULT CURRENT_TIMESTAMP,
  `CreatedBy` varchar(50) DEFAULT NULL,
  `UpdatedDate` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `UpdatedBy` varchar(50) DEFAULT NULL,
  `MissingMasterIds` text,
  `OverdueMasterIds` text,
  `ResponsibleEmails` text,
  `AlertEmails` text,
  PRIMARY KEY (`Id`)
) ENGINE=InnoDB AUTO_INCREMENT=1266 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `compl_sync_sales_line`
--

DROP TABLE IF EXISTS `compl_sync_sales_line`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `compl_sync_sales_line` (
  `Id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `SalesId` varchar(50) DEFAULT NULL,
  `SalesStatus` varchar(50) NOT NULL,
  `ProductCode` varchar(50) NOT NULL,
  `ConfigId` varchar(20) NOT NULL,
  `ProductName` varchar(250) NOT NULL,
  `ProductDescription` varchar(250) NOT NULL,
  `ProductType` varchar(100) NOT NULL,
  `ProductRange` varchar(100) NOT NULL,
  `CreatedDate` datetime NOT NULL,
  PRIMARY KEY (`Id`),
  KEY `compl_sales_line_salesid_index` (`SalesId`),
  KEY `compl_sales_line_productcode_index` (`ProductCode`),
  KEY `compl_sales_line_configid_index` (`ConfigId`),
  KEY `compl_sales_line_producttype_index` (`ProductType`),
  KEY `compl_sales_line_productrange_index` (`ProductRange`)
) ENGINE=InnoDB AUTO_INCREMENT=1075 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `compl_sync_variant_attributes`
--

DROP TABLE IF EXISTS `compl_sync_variant_attributes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `compl_sync_variant_attributes` (
  `Id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `ProductCode` varchar(50) DEFAULT NULL,
  `ConfigId` varchar(20) NOT NULL,
  `GroupId` varchar(50) NOT NULL,
  `GroupValue` varchar(50) NOT NULL,
  `AttributeType` bigint NOT NULL,
  `AttributeTypeName` varchar(150) NOT NULL,
  `AttributeValue` bigint NOT NULL,
  `AttributeValueName` varchar(150) NOT NULL,
  `CreatedDate` datetime NOT NULL,
  PRIMARY KEY (`Id`),
  KEY `compl_variant_attributes_productcode_index` (`ProductCode`),
  KEY `compl_variant_attributes_configid_index` (`ConfigId`),
  KEY `compl_variant_attributes_attributetype_index` (`AttributeType`),
  KEY `compl_variant_attributes_attributevalue_index` (`AttributeValue`)
) ENGINE=InnoDB AUTO_INCREMENT=1936 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `compl_user_grid_preference`
--

DROP TABLE IF EXISTS `compl_user_grid_preference`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `compl_user_grid_preference` (
  `Id` bigint NOT NULL AUTO_INCREMENT,
  `UserEmail` varchar(320) NOT NULL COMMENT 'User email - references compl_user.Email',
  `PageId` varchar(100) NOT NULL COMMENT 'Page identifier, e.g. pipeline, customer, contact',
  `GridId` varchar(100) NOT NULL COMMENT 'Grid identifier in page scope, e.g. Customer, Pipeline, contacts',
  `ViewName` varchar(100) NOT NULL DEFAULT 'Default' COMMENT 'Named column view under page/grid scope',
  `IsDefault` tinyint(1) NOT NULL DEFAULT '0' COMMENT 'Default selected view for page/grid',
  `ColumnVisibilityJson` longtext NOT NULL COMMENT 'JSON object storing MUI DataGrid column visibility model',
  `CreatedOn` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `UpdatedOn` datetime DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`Id`),
  UNIQUE KEY `uq_user_page_grid_view` (`UserEmail`,`PageId`,`GridId`,`ViewName`),
  KEY `idx_user_grid_user_email` (`UserEmail`),
  KEY `idx_user_grid_page_grid` (`PageId`,`GridId`),
  KEY `idx_user_grid_default` (`UserEmail`,`PageId`,`GridId`,`IsDefault`)
) ENGINE=InnoDB AUTO_INCREMENT=209 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='Per-user DataGrid column visibility views by page and grid';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `eutr_documents`
--

DROP TABLE IF EXISTS `eutr_documents`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `eutr_documents` (
  `Id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `Name` varchar(255) DEFAULT NULL,
  `FileId` varchar(255) DEFAULT NULL,
  `ValidFrom` date DEFAULT NULL,
  `ValidTo` date DEFAULT NULL,
  `Invoice` varchar(255) DEFAULT NULL,
  `CreatedBy` varchar(50) DEFAULT NULL,
  `CreatedDate` datetime DEFAULT NULL,
  `UpdatedBy` varchar(50) DEFAULT NULL,
  `UpdatedDate` datetime DEFAULT NULL,
  PRIMARY KEY (`Id`)
) ENGINE=InnoDB AUTO_INCREMENT=41 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `eutr_master_documents`
--

DROP TABLE IF EXISTS `eutr_master_documents`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `eutr_master_documents` (
  `Id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `StepId` bigint unsigned DEFAULT NULL,
  `Prefix` varchar(255) DEFAULT NULL,
  `CreatedBy` varchar(50) DEFAULT NULL,
  `CreatedDate` datetime DEFAULT NULL,
  `UpdatedBy` varchar(50) DEFAULT NULL,
  `UpdatedDate` datetime DEFAULT NULL,
  PRIMARY KEY (`Id`),
  KEY `eutr_master_documents_stepid_foreign` (`StepId`),
  CONSTRAINT `eutr_master_documents_stepid_foreign` FOREIGN KEY (`StepId`) REFERENCES `eutr_steps` (`Id`)
) ENGINE=InnoDB AUTO_INCREMENT=33 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `eutr_purchase_attachments`
--

DROP TABLE IF EXISTS `eutr_purchase_attachments`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `eutr_purchase_attachments` (
  `Id` int unsigned NOT NULL AUTO_INCREMENT,
  `SalesId` varchar(50) NOT NULL,
  `PurchId` varchar(50) NOT NULL,
  `TemplateCode` varchar(50) NOT NULL,
  `CreatedBy` varchar(50) NOT NULL,
  `CreatedDate` datetime NOT NULL,
  `UpdatedBy` varchar(50) NOT NULL,
  `UpdatedDate` datetime NOT NULL,
  PRIMARY KEY (`Id`),
  KEY `eutr_purchase_attachments_templatecode_foreign` (`TemplateCode`),
  CONSTRAINT `eutr_purchase_attachments_templatecode_foreign` FOREIGN KEY (`TemplateCode`) REFERENCES `eutr_templates` (`Code`)
) ENGINE=InnoDB AUTO_INCREMENT=1284 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `eutr_purchase_missing`
--

DROP TABLE IF EXISTS `eutr_purchase_missing`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `eutr_purchase_missing` (
  `Id` int unsigned NOT NULL AUTO_INCREMENT,
  `PurchId` varchar(50) NOT NULL,
  `VendorCode` varchar(50) DEFAULT NULL,
  `VendorName` varchar(255) DEFAULT NULL,
  `TemplateId` varchar(50) DEFAULT NULL,
  `Note` text NOT NULL,
  `AlertForGroupId` bigint unsigned DEFAULT NULL,
  PRIMARY KEY (`Id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `eutr_reference_details`
--

DROP TABLE IF EXISTS `eutr_reference_details`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `eutr_reference_details` (
  `Id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `RefId` bigint unsigned DEFAULT NULL,
  `ConditionType` bigint NOT NULL DEFAULT '0',
  `ConditionValue` varchar(255) DEFAULT NULL,
  `CreatedBy` varchar(50) DEFAULT NULL,
  `CreatedDate` datetime DEFAULT NULL,
  `UpdatedBy` varchar(50) DEFAULT NULL,
  `UpdatedDate` datetime DEFAULT NULL,
  PRIMARY KEY (`Id`),
  KEY `eutr_reference_details_refid_foreign` (`RefId`),
  CONSTRAINT `eutr_reference_details_refid_foreign` FOREIGN KEY (`RefId`) REFERENCES `eutr_references` (`Id`)
) ENGINE=InnoDB AUTO_INCREMENT=8 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `eutr_reference_type_details`
--

DROP TABLE IF EXISTS `eutr_reference_type_details`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `eutr_reference_type_details` (
  `Id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `StepId` bigint unsigned DEFAULT NULL,
  `TypeId` bigint unsigned DEFAULT NULL,
  `CreatedBy` varchar(50) DEFAULT NULL,
  `CreatedDate` datetime DEFAULT NULL,
  `UpdatedBy` varchar(50) DEFAULT NULL,
  `UpdatedDate` datetime DEFAULT NULL,
  PRIMARY KEY (`Id`),
  KEY `eutr_reference_type_details_typeid_foreign` (`TypeId`),
  KEY `eutr_reference_type_details_stepid_foreign` (`StepId`),
  CONSTRAINT `eutr_reference_type_details_stepid_foreign` FOREIGN KEY (`StepId`) REFERENCES `eutr_steps` (`Id`),
  CONSTRAINT `eutr_reference_type_details_typeid_foreign` FOREIGN KEY (`TypeId`) REFERENCES `eutr_reference_types` (`Id`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `eutr_reference_types`
--

DROP TABLE IF EXISTS `eutr_reference_types`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `eutr_reference_types` (
  `Id` bigint unsigned NOT NULL,
  `Name` varchar(255) DEFAULT NULL,
  `CreatedBy` varchar(50) DEFAULT NULL,
  `CreatedDate` datetime DEFAULT NULL,
  `UpdatedBy` varchar(50) DEFAULT NULL,
  `UpdatedDate` datetime DEFAULT NULL,
  PRIMARY KEY (`Id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `eutr_references`
--

DROP TABLE IF EXISTS `eutr_references`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `eutr_references` (
  `Id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `RefId` bigint unsigned DEFAULT NULL,
  `StepId` bigint DEFAULT NULL,
  `DocumentId` bigint unsigned DEFAULT NULL,
  `RefType` bigint unsigned DEFAULT NULL,
  `RefValue` varchar(255) DEFAULT NULL,
  `CreatedBy` varchar(50) DEFAULT NULL,
  `CreatedDate` datetime DEFAULT NULL,
  `UpdatedBy` varchar(50) DEFAULT NULL,
  `UpdatedDate` datetime DEFAULT NULL,
  PRIMARY KEY (`Id`),
  KEY `eutr_references_documentid_foreign` (`DocumentId`),
  KEY `eutr_references_refid_foreign` (`RefId`),
  KEY `eutr_references_reftype_foreign` (`RefType`),
  CONSTRAINT `eutr_references_documentid_foreign` FOREIGN KEY (`DocumentId`) REFERENCES `eutr_documents` (`Id`),
  CONSTRAINT `eutr_references_refid_foreign` FOREIGN KEY (`RefId`) REFERENCES `eutr_template_details` (`Id`)
) ENGINE=InnoDB AUTO_INCREMENT=41 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `eutr_steps`
--

DROP TABLE IF EXISTS `eutr_steps`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `eutr_steps` (
  `Id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `Name` varchar(255) DEFAULT NULL,
  `CreatedBy` varchar(50) DEFAULT NULL,
  `CreatedDate` datetime DEFAULT NULL,
  `UpdatedBy` varchar(50) DEFAULT NULL,
  `UpdatedDate` datetime DEFAULT NULL,
  PRIMARY KEY (`Id`)
) ENGINE=InnoDB AUTO_INCREMENT=35 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `eutr_template_details`
--

DROP TABLE IF EXISTS `eutr_template_details`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `eutr_template_details` (
  `Id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `TemplateId` bigint unsigned DEFAULT NULL,
  `StepId` bigint unsigned DEFAULT NULL,
  `RequirementType` tinyint DEFAULT '0',
  `DisplayOrder` int DEFAULT '0',
  `CreatedBy` varchar(50) DEFAULT NULL,
  `CreatedDate` datetime DEFAULT NULL,
  `UpdatedBy` varchar(50) DEFAULT NULL,
  `UpdatedDate` datetime DEFAULT NULL,
  `TakeFrom` bigint unsigned DEFAULT NULL,
  `ParentId` bigint DEFAULT '0',
  PRIMARY KEY (`Id`),
  KEY `eutr_template_details_templateid_foreign` (`TemplateId`),
  KEY `eutr_template_details_stepid_foreign` (`StepId`),
  KEY `eutr_template_details_takefrom_foreign` (`TakeFrom`),
  CONSTRAINT `eutr_template_details_stepid_foreign` FOREIGN KEY (`StepId`) REFERENCES `eutr_steps` (`Id`),
  CONSTRAINT `eutr_template_details_takefrom_foreign` FOREIGN KEY (`TakeFrom`) REFERENCES `eutr_reference_types` (`Id`),
  CONSTRAINT `eutr_template_details_templateid_foreign` FOREIGN KEY (`TemplateId`) REFERENCES `eutr_templates` (`Id`)
) ENGINE=InnoDB AUTO_INCREMENT=337 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `eutr_template_references`
--

DROP TABLE IF EXISTS `eutr_template_references`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `eutr_template_references` (
  `Id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `TemplateId` bigint unsigned NOT NULL,
  `VendorCode` varchar(50) NOT NULL,
  `FromDate` date NOT NULL,
  `ToDate` date NOT NULL,
  `CreatedBy` varchar(50) NOT NULL,
  `CreatedDate` datetime NOT NULL,
  `UpdatedBy` varchar(50) NOT NULL,
  `UpdatedDate` datetime NOT NULL,
  PRIMARY KEY (`Id`),
  KEY `eutr_template_references_templateid_foreign` (`TemplateId`),
  CONSTRAINT `eutr_template_references_templateid_foreign` FOREIGN KEY (`TemplateId`) REFERENCES `eutr_templates` (`Id`)
) ENGINE=InnoDB AUTO_INCREMENT=17 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `eutr_templates`
--

DROP TABLE IF EXISTS `eutr_templates`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `eutr_templates` (
  `Id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `Code` varchar(50) DEFAULT NULL,
  `Name` varchar(400) DEFAULT NULL,
  `IsDefault` tinyint DEFAULT '0',
  `VersionId` tinyint DEFAULT '1',
  `Status` tinyint DEFAULT '0',
  `CreatedBy` varchar(50) DEFAULT NULL,
  `CreatedDate` datetime DEFAULT NULL,
  `UpdatedBy` varchar(50) DEFAULT NULL,
  `UpdatedDate` datetime DEFAULT NULL,
  `AlertFor` tinyint DEFAULT NULL,
  `IsDeleted` tinyint DEFAULT '0',
  `IsHide` tinyint DEFAULT '0',
  PRIMARY KEY (`Id`),
  KEY `eutr_templates_code_index` (`Code`),
  KEY `eutr_templates_ishide_index` (`IsHide`),
  KEY `eutr_templates_isdeleted_index` (`IsDeleted`)
) ENGINE=InnoDB AUTO_INCREMENT=21 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `hf_AggregatedCounter`
--

DROP TABLE IF EXISTS `hf_AggregatedCounter`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `hf_AggregatedCounter` (
  `Id` int NOT NULL AUTO_INCREMENT,
  `Key` varchar(100) CHARACTER SET utf8mb3 COLLATE utf8mb3_general_ci NOT NULL,
  `Value` int NOT NULL,
  `ExpireAt` datetime DEFAULT NULL,
  PRIMARY KEY (`Id`),
  UNIQUE KEY `IX_hf_CounterAggregated_Key` (`Key`)
) ENGINE=InnoDB AUTO_INCREMENT=509 DEFAULT CHARSET=utf8mb3;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `hf_Counter`
--

DROP TABLE IF EXISTS `hf_Counter`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `hf_Counter` (
  `Id` int NOT NULL AUTO_INCREMENT,
  `Key` varchar(100) CHARACTER SET utf8mb3 COLLATE utf8mb3_general_ci NOT NULL,
  `Value` int NOT NULL,
  `ExpireAt` datetime DEFAULT NULL,
  PRIMARY KEY (`Id`),
  KEY `IX_hf_Counter_Key` (`Key`)
) ENGINE=InnoDB AUTO_INCREMENT=1924 DEFAULT CHARSET=utf8mb3;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `hf_DistributedLock`
--

DROP TABLE IF EXISTS `hf_DistributedLock`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `hf_DistributedLock` (
  `Resource` varchar(100) CHARACTER SET utf8mb3 COLLATE utf8mb3_general_ci NOT NULL,
  `CreatedAt` datetime(6) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `hf_Hash`
--

DROP TABLE IF EXISTS `hf_Hash`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `hf_Hash` (
  `Id` int NOT NULL AUTO_INCREMENT,
  `Key` varchar(100) CHARACTER SET utf8mb3 COLLATE utf8mb3_general_ci NOT NULL,
  `Field` varchar(40) CHARACTER SET utf8mb3 COLLATE utf8mb3_general_ci NOT NULL,
  `Value` longtext,
  `ExpireAt` datetime(6) DEFAULT NULL,
  PRIMARY KEY (`Id`),
  UNIQUE KEY `IX_hf_Hash_Key_Field` (`Key`,`Field`)
) ENGINE=InnoDB AUTO_INCREMENT=717 DEFAULT CHARSET=utf8mb3;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `hf_Job`
--

DROP TABLE IF EXISTS `hf_Job`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `hf_Job` (
  `Id` int NOT NULL AUTO_INCREMENT,
  `StateId` int DEFAULT NULL,
  `StateName` varchar(20) CHARACTER SET utf8mb3 COLLATE utf8mb3_general_ci DEFAULT NULL,
  `InvocationData` longtext NOT NULL,
  `Arguments` longtext NOT NULL,
  `CreatedAt` datetime(6) NOT NULL,
  `ExpireAt` datetime(6) DEFAULT NULL,
  PRIMARY KEY (`Id`),
  KEY `IX_hf_Job_StateName` (`StateName`)
) ENGINE=InnoDB AUTO_INCREMENT=643 DEFAULT CHARSET=utf8mb3;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `hf_JobParameter`
--

DROP TABLE IF EXISTS `hf_JobParameter`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `hf_JobParameter` (
  `Id` int NOT NULL AUTO_INCREMENT,
  `JobId` int NOT NULL,
  `Name` varchar(40) CHARACTER SET utf8mb3 COLLATE utf8mb3_general_ci NOT NULL,
  `Value` longtext,
  PRIMARY KEY (`Id`),
  UNIQUE KEY `IX_hf_JobParameter_JobId_Name` (`JobId`,`Name`),
  KEY `FK_hf_JobParameter_Job` (`JobId`),
  CONSTRAINT `FK_hf_JobParameter_Job` FOREIGN KEY (`JobId`) REFERENCES `hf_Job` (`Id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=1748 DEFAULT CHARSET=utf8mb3;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `hf_JobQueue`
--

DROP TABLE IF EXISTS `hf_JobQueue`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `hf_JobQueue` (
  `Id` int NOT NULL AUTO_INCREMENT,
  `JobId` int NOT NULL,
  `FetchedAt` datetime(6) DEFAULT NULL,
  `Queue` varchar(50) CHARACTER SET utf8mb3 COLLATE utf8mb3_general_ci NOT NULL,
  `FetchToken` varchar(36) CHARACTER SET utf8mb3 COLLATE utf8mb3_general_ci DEFAULT NULL,
  PRIMARY KEY (`Id`),
  KEY `IX_hf_JobQueue_QueueAndFetchedAt` (`Queue`,`FetchedAt`)
) ENGINE=InnoDB AUTO_INCREMENT=657 DEFAULT CHARSET=utf8mb3;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `hf_JobState`
--

DROP TABLE IF EXISTS `hf_JobState`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `hf_JobState` (
  `Id` int NOT NULL AUTO_INCREMENT,
  `JobId` int NOT NULL,
  `CreatedAt` datetime(6) NOT NULL,
  `Name` varchar(20) CHARACTER SET utf8mb3 COLLATE utf8mb3_general_ci NOT NULL,
  `Reason` varchar(100) CHARACTER SET utf8mb3 COLLATE utf8mb3_general_ci DEFAULT NULL,
  `Data` longtext,
  PRIMARY KEY (`Id`),
  KEY `FK_hf_JobState_Job` (`JobId`),
  CONSTRAINT `FK_hf_JobState_Job` FOREIGN KEY (`JobId`) REFERENCES `hf_Job` (`Id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `hf_List`
--

DROP TABLE IF EXISTS `hf_List`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `hf_List` (
  `Id` int NOT NULL AUTO_INCREMENT,
  `Key` varchar(100) CHARACTER SET utf8mb3 COLLATE utf8mb3_general_ci NOT NULL,
  `Value` longtext,
  `ExpireAt` datetime(6) DEFAULT NULL,
  PRIMARY KEY (`Id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `hf_Server`
--

DROP TABLE IF EXISTS `hf_Server`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `hf_Server` (
  `Id` varchar(100) CHARACTER SET utf8mb3 COLLATE utf8mb3_general_ci NOT NULL,
  `Data` longtext NOT NULL,
  `LastHeartbeat` datetime(6) DEFAULT NULL,
  PRIMARY KEY (`Id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `hf_Set`
--

DROP TABLE IF EXISTS `hf_Set`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `hf_Set` (
  `Id` int NOT NULL AUTO_INCREMENT,
  `Key` varchar(100) CHARACTER SET utf8mb3 COLLATE utf8mb3_general_ci NOT NULL,
  `Value` varchar(256) CHARACTER SET utf8mb3 COLLATE utf8mb3_general_ci NOT NULL,
  `Score` float NOT NULL,
  `ExpireAt` datetime DEFAULT NULL,
  PRIMARY KEY (`Id`),
  UNIQUE KEY `IX_hf_Set_Key_Value` (`Key`,`Value`)
) ENGINE=InnoDB AUTO_INCREMENT=468261 DEFAULT CHARSET=utf8mb3;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `hf_State`
--

DROP TABLE IF EXISTS `hf_State`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `hf_State` (
  `Id` int NOT NULL AUTO_INCREMENT,
  `JobId` int NOT NULL,
  `Name` varchar(20) CHARACTER SET utf8mb3 COLLATE utf8mb3_general_ci NOT NULL,
  `Reason` varchar(100) CHARACTER SET utf8mb3 COLLATE utf8mb3_general_ci DEFAULT NULL,
  `CreatedAt` datetime(6) NOT NULL,
  `Data` longtext,
  PRIMARY KEY (`Id`),
  KEY `FK_hf_HangFire_State_Job` (`JobId`),
  CONSTRAINT `FK_hf_HangFire_State_Job` FOREIGN KEY (`JobId`) REFERENCES `hf_Job` (`Id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=1991 DEFAULT CHARSET=utf8mb3;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping events for database 'compliance_sys_db'
--

--
-- Dumping routines for database 'compliance_sys_db'
--
/*!50003 DROP FUNCTION IF EXISTS `compl_fn_get_rule_count` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` FUNCTION `compl_fn_get_rule_count`(
    p_compl_master_id BIGINT,
    p_compl_actual_id BIGINT,
    p_check_date DATE  -- Ngày check, thường là CURDATE() hoặc ngày cụ thể
) RETURNS int
    READS SQL DATA
    DETERMINISTIC
BEGIN
    DECLARE v_count INT;
    DECLARE v_actual_valid_from DATE;
    DECLARE v_actual_valid_to DATE;
    
    -- Lấy validity period của actual
    SELECT ValidFrom, ValidTo 
    INTO v_actual_valid_from, v_actual_valid_to
    FROM compl_actual
    WHERE Id = p_compl_actual_id;
    
    SELECT COUNT(DISTINCT r.Id) INTO v_count
    FROM compl_rule_item ri
    INNER JOIN compl_rule r ON r.Id = ri.RuleId
    WHERE ri.ComplMasterId = p_compl_master_id
      AND r.IsActive = 1
      
      -- Check: check_date phải nằm trong validity period của Rule
      AND (r.ValidFrom IS NULL OR r.ValidFrom <= p_check_date)
      AND (r.ValidTo IS NULL OR r.ValidTo >= p_check_date)
      
      -- Check: check_date phải nằm trong validity period của Actual
      AND (v_actual_valid_from IS NULL OR v_actual_valid_from <= p_check_date)
      AND (v_actual_valid_to IS NULL OR v_actual_valid_to >= p_check_date)
      
      -- Check: Có overlap giữa Rule Item và Actual validity periods
      -- Overlap exists if: ItemValidFrom <= ActualValidTo AND ItemValidTo >= ActualValidFrom
      AND (
          ri.ValidFrom IS NULL 
          OR ri.ValidTo IS NULL 
          OR v_actual_valid_from IS NULL 
          OR v_actual_valid_to IS NULL
          OR (
              ri.ValidFrom <= COALESCE(v_actual_valid_to, '9999-12-31')
              AND COALESCE(ri.ValidTo, '9999-12-31') >= v_actual_valid_from
          )
      )
      
      -- Check: check_date phải nằm trong overlap period của Rule Item
      AND (ri.ValidFrom IS NULL OR ri.ValidFrom <= p_check_date)
      AND (ri.ValidTo IS NULL OR ri.ValidTo >= p_check_date)
      
      -- Check if rule conditions are satisfied based on LogicalGroup
      AND (
          -- Case 1: No conditions = rule always matches
          NOT EXISTS (
              SELECT 1 FROM compl_rule_condition WHERE RuleId = r.Id
          )
          OR
          -- Case 2: Has conditions - check by LogicalGroup
          -- Different LogicalGroups = OR, same LogicalGroup = AND
          EXISTS (
              SELECT 1
              FROM compl_rule_condition rc
              WHERE rc.RuleId = r.Id
              GROUP BY rc.LogicalGroup
              HAVING 
                  -- All conditions in this LogicalGroup must be satisfied
                  COUNT(*) = SUM(
                      CASE 
                          -- Special handling for NOT_EXISTS operator
                          WHEN rc.Operator = 'NOT_EXISTS' THEN
                              CASE 
                                  WHEN NOT EXISTS (
                                      SELECT 1
                                      FROM compl_object_map com
                                      WHERE com.ComplActualId = p_compl_actual_id
                                        AND com.ReferenceType = rc.ReferenceType
                                        AND (
                                            com.MapRole = 2
                                            OR (
                                                com.MapRole = 1
                                                AND NOT EXISTS (
                                                    SELECT 1 
                                                    FROM compl_object_map com2 
                                                    WHERE com2.ComplActualId = p_compl_actual_id
                                                      AND com2.ReferenceType = rc.ReferenceType
                                                      AND com2.MapRole = 2
                                                )
                                            )
                                        )
                                        AND (com.ValidFrom IS NULL OR com.ValidFrom <= p_check_date)
                                        AND (com.ValidTo IS NULL OR com.ValidTo >= p_check_date)
                                  ) THEN 1
                                  ELSE 0
                              END
                          
                          -- Other operators: check if mapping exists and matches
                          -- Ưu tiên MapRole = 2 (CONDITION), nếu không có thì dùng MapRole = 1 (APPLY)
                          WHEN EXISTS (
                              SELECT 1
                              FROM compl_object_map com
                              WHERE com.ComplActualId = p_compl_actual_id
                                AND com.ReferenceType = rc.ReferenceType
                                AND (
                                    com.MapRole = 2  -- Ưu tiên CONDITION
                                    OR (
                                        com.MapRole = 1  -- Dùng APPLY nếu không có CONDITION
                                        AND NOT EXISTS (
                                            SELECT 1 
                                            FROM compl_object_map com2 
                                            WHERE com2.ComplActualId = p_compl_actual_id
                                              AND com2.ReferenceType = rc.ReferenceType
                                              AND com2.MapRole = 2
                                        )
                                    )
                                )
                                AND (com.ValidFrom IS NULL OR com.ValidFrom <= p_check_date)
                                AND (com.ValidTo IS NULL OR com.ValidTo >= p_check_date)
                                AND (
                                    com.ReferenceValue = 'ALL'  -- All always matches
									OR (
										CASE rc.Operator
											WHEN '=' THEN 
												com.ReferenceValue = rc.RequiredValue
											WHEN 'IN' THEN 
												FIND_IN_SET(com.ReferenceValue, rc.RequiredValue) > 0
											WHEN 'LIKE' THEN 
												com.ReferenceValue LIKE CONCAT('%', rc.RequiredValue, '%')
											WHEN 'EXISTS' THEN 
												1 = 1
											WHEN 'ALL' THEN 
												1 = 1
											ELSE 0
										END
									)
                                )
                          ) THEN 1
                          ELSE 0
                      END
                  )
          )
      )
      -- Priority and Override logic
      AND (
          r.IsOverride = 1  -- Override rule always applies
          OR 
          -- Non-override rule: check if no higher priority override rule exists
          NOT EXISTS (
              SELECT 1
              FROM compl_rule_item ri2
              INNER JOIN compl_rule r2 ON r2.Id = ri2.RuleId
              WHERE ri2.ComplMasterId = p_compl_master_id
                AND r2.IsActive = 1
                AND r2.IsOverride = 1
                AND r2.Priority < r.Priority  -- Higher priority (smaller number)
                AND (r2.ValidFrom IS NULL OR r2.ValidFrom <= p_check_date)
                AND (r2.ValidTo IS NULL OR r2.ValidTo >= p_check_date)
                AND (ri2.ValidFrom IS NULL OR ri2.ValidFrom <= p_check_date)
                AND (ri2.ValidTo IS NULL OR ri2.ValidTo >= p_check_date)
                AND (
                    ri2.ValidFrom IS NULL 
                    OR ri2.ValidTo IS NULL 
                    OR v_actual_valid_from IS NULL 
                    OR v_actual_valid_to IS NULL
                    OR (
                        ri2.ValidFrom <= COALESCE(v_actual_valid_to, '9999-12-31')
                        AND COALESCE(ri2.ValidTo, '9999-12-31') >= v_actual_valid_from
                    )
                )
          )
      );
    
    RETURN COALESCE(v_count, 0);
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `compl_sp_export_master_template` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `compl_sp_export_master_template`(IN p_created_by VARCHAR(255))
BEGIN
    /*
     * Export compl_masters data matching the import_master_template.xlsx format.
     * One row per condition. Multiple condition values are comma-separated.
     *
     * Column mapping:
     *   MasterCode        → compl_masters.Code                         (added per request)
     *   Regulation Name   → compl_masters.Name
     *   Valid From        → compl_masters.ValidFrom                    (DD/MM/YYYY)
     *   Valid To          → compl_masters.ValidTo                      (DD/MM/YYYY)
     *   Responsible Group → compl_group_email.Name  (GroupType = 1)
     *   Alert Group       → compl_group_email.Name  (GroupType = 2)
     *   Alert Before      → compl_masters.NumDayAlert
     *   Description       → compl_masters.Description
     *   Product test      → compl_masters.IsIndividual                 (YES / NO)
     *   Condition Type    → compl_reference_types.Name
     *   Condition Value   → GROUP_CONCAT(compl_master_condition_values.RefTypeValue)
     *   Condition Group   → compl_master_conditions.Logical            (AND / OR)
     */

    SELECT
        m.Code                                                  AS `MasterCode`,
        m.VersionNo                                             AS `VersionNo`,
        m.Name                                                  AS `RegulationName`,
        DATE_FORMAT(m.ValidFrom, '%d/%m/%Y')                    AS `ValidFrom`,
        DATE_FORMAT(m.ValidTo,   '%d/%m/%Y')                    AS `ValidTo`,
        rg.Name                                                 AS `ResponsibleGroup`,
        ag.Name                                                 AS `AlertGroup`,
        m.NumDayAlert                                           AS `AlertBeforeDays`,
        m.Description                                           AS `Description`,
        CASE WHEN m.IsIndividual = 1 THEN 'YES' ELSE 'NO' END  AS `Producttest`,
        rt.Name                                                 AS `ConditionType`,
        GROUP_CONCAT(
            mcv.RefTypeValue
            ORDER BY mcv.Id
            SEPARATOR ', '
        )                                                       AS `ConditionValue`,
        CASE WHEN mc.Logical = 1 THEN 'AND' ELSE 'OR' END      AS `ConditionGroup`

    FROM compl_masters m

    /* ── Responsible Group (GroupType = 1) ── */
    LEFT JOIN compl_master_group_email mrg
           ON mrg.MasterId  = m.Id
          AND mrg.GroupType = 1
    LEFT JOIN compl_group_email rg
           ON rg.Id = mrg.GroupEmailId

    /* ── Alert Group (GroupType = 2) ── */
    LEFT JOIN compl_master_group_email mag
           ON mag.MasterId  = m.Id
          AND mag.GroupType = 2
    LEFT JOIN compl_group_email ag
           ON ag.Id = mag.GroupEmailId

    /* ── Conditions (one row per condition) ── */
    LEFT JOIN compl_master_conditions mc
           ON mc.MasterId = m.Id

    LEFT JOIN compl_reference_types rt
           ON rt.Id = mc.RefTypeId

    /* ── Condition values → aggregated per condition ── */
    LEFT JOIN compl_master_condition_values mcv
           ON mcv.ConditionId = mc.Id

    WHERE m.IsDelete = 0 AND (m.CreatedBy = p_created_by OR p_created_by = '')

    GROUP BY
        m.Id,
        m.Code,
        m.VersionNo,
        m.Name,
        m.ValidFrom,
        m.ValidTo,
        rg.Name,
        ag.Name,
        m.NumDayAlert,
        m.Description,
        m.IsIndividual,
        mc.Id,
        rt.Name,
        mc.Logical

    ORDER BY
        m.Code,
        mc.Id;

END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `compl_sp_get_alert_compliances` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `compl_sp_get_alert_compliances`(
    IN p_ids TEXT,
    IN p_type INT
)
BEGIN
    WITH LatestComplianceVersions AS (
        SELECT Code, MAX(VersionNo) AS MaxVersion
        FROM compl_compliances
        GROUP BY Code
    ),
    LatestMasterVersions AS (
        SELECT Code, MAX(VersionNo) AS MaxVersion
        FROM compl_masters
        GROUP BY Code
    ),
    -- CTE để aggregate email groups theo MasterId
    compliance_emails AS (
        SELECT 
            ccge.ComplianceId,
            -- GroupType = 1: ResponsibleFor
            GROUP_CONCAT(DISTINCT CASE WHEN ccge.GroupType = 1 THEN cged.ResponseEmail END 
                ORDER BY CASE WHEN ccge.GroupType = 1 THEN cged.ResponseEmail END 
                SEPARATOR ',') AS ResponsibleFor,
            -- GroupType = 2: AlertFor
            GROUP_CONCAT(DISTINCT CASE WHEN ccge.GroupType = 2 THEN cged.ResponseEmail END 
                ORDER BY CASE WHEN ccge.GroupType = 2 THEN cged.ResponseEmail END 
                SEPARATOR ',') AS AlertFor,
            -- GroupType = 3: ResponsibleForAddition
            GROUP_CONCAT(DISTINCT CASE WHEN ccge.GroupType = 3 THEN cged.ResponseEmail END 
                ORDER BY CASE WHEN ccge.GroupType = 3 THEN cged.ResponseEmail END 
                SEPARATOR ',') AS ResponsibleForAddition,
            -- GroupType = 4: AlertForAddition
            GROUP_CONCAT(DISTINCT CASE WHEN ccge.GroupType = 4 THEN cged.ResponseEmail END 
                ORDER BY CASE WHEN ccge.GroupType = 4 THEN cged.ResponseEmail END 
                SEPARATOR ',') AS AlertForAddition
        FROM compl_compliance_group_email ccge
        LEFT JOIN compl_group_email_detail cged ON cged.GroupEmailId = ccge.GroupEmailId AND cged.IsActive = TRUE
        WHERE (p_ids IS NULL OR p_ids = '' OR FIND_IN_SET(ccge.ComplianceId, p_ids))
        GROUP BY ccge.ComplianceId
    )
    
    SELECT 
        cm.Name as MasterName,
        cm.Code as MasterCode,
        cd.Id,        
        cd.Name,
        cd.Code,
        cd.VersionNo,
        sf.Name as FileName,
        cd.FileId,
       
        cd.NumDayAlert,
        cd.ValidFrom,
        cd.ValidTo,
        cd.Description,        

        cd.CreatedDate,
        cd.CreatedBy,
        
        -- Compliance Emails từ CTE
        ce.ResponsibleFor as ResponsibleEmails,
        ce.AlertFor as AlertEmails,
        ce.ResponsibleForAddition,
        ce.AlertForAddition,
        
        CONCAT(DATEDIFF(cd.ValidTo, CURDATE()), ' days left') AS DaysRemaining

    FROM compl_compliances cd
    INNER JOIN LatestComplianceVersions lcv 
        ON cd.Code = lcv.Code AND cd.VersionNo = lcv.MaxVersion
	LEFT JOIN compliance_emails ce ON ce.ComplianceId = cd.Id
    LEFT JOIN compl_sharepoint_files sf ON sf.FileId = cd.FileId
    INNER JOIN compl_references crf ON crf.ComplianceId = cd.Id
    INNER JOIN compl_masters cm ON cm.Id = crf.MasterId
		AND CASE WHEN p_type = 0 THEN 1 = 1 ELSE cm.AlertType = 0 END
    INNER JOIN LatestMasterVersions lmv 
        ON cm.Code = lmv.Code AND cm.VersionNo = lmv.MaxVersion
    WHERE 
        (
            (p_ids IS NULL OR p_ids = '' AND ((cd.ValidTo IS NOT NULL AND DATE_ADD(CURDATE(), INTERVAL cd.NumDayAlert DAY) >= cd.ValidTo) OR cd.ValidTo < CURDATE()))
            OR (p_ids IS NOT NULL AND p_ids <> '' AND FIND_IN_SET(cd.Id, p_ids))
        )

    GROUP BY 
        cd.Id, cd.Name, cd.Code, cd.NumDayAlert, cd.ValidFrom, cd.ValidTo, 
        cd.Description, cd.CreatedDate, cd.CreatedBy,
        cd.FileId, sf.Name, cm.Name, cm.Code;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `compl_sp_get_alert_master_compliances` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `compl_sp_get_alert_master_compliances`(
    IN p_ids TEXT
)
BEGIN
	-- CTE để aggregate email groups theo MasterId
    WITH master_emails AS (
        SELECT 
            ccge.MasterId,
            -- GroupType = 1: ResponsibleFor
            GROUP_CONCAT(DISTINCT CASE WHEN ccge.GroupType = 1 THEN cged.ResponseEmail END 
                ORDER BY CASE WHEN ccge.GroupType = 1 THEN cged.ResponseEmail END 
                SEPARATOR ',') AS ResponsibleFor,
            -- GroupType = 2: AlertFor
            GROUP_CONCAT(DISTINCT CASE WHEN ccge.GroupType = 2 THEN cged.ResponseEmail END 
                ORDER BY CASE WHEN ccge.GroupType = 2 THEN cged.ResponseEmail END 
                SEPARATOR ',') AS AlertFor,
            -- GroupType = 3: ResponsibleForAddition
            GROUP_CONCAT(DISTINCT CASE WHEN ccge.GroupType = 3 THEN cged.ResponseEmail END 
                ORDER BY CASE WHEN ccge.GroupType = 3 THEN cged.ResponseEmail END 
                SEPARATOR ',') AS ResponsibleForAddition,
            -- GroupType = 4: AlertForAddition
            GROUP_CONCAT(DISTINCT CASE WHEN ccge.GroupType = 4 THEN cged.ResponseEmail END 
                ORDER BY CASE WHEN ccge.GroupType = 4 THEN cged.ResponseEmail END 
                SEPARATOR ',') AS AlertForAddition
        FROM compl_master_group_email ccge
        LEFT JOIN compl_group_email_detail cged ON cged.GroupEmailId = ccge.GroupEmailId AND cged.IsActive = TRUE
        WHERE (p_ids IS NULL OR p_ids = '' OR FIND_IN_SET(ccge.MasterId, p_ids))
        GROUP BY ccge.MasterId
    )
    
    SELECT 
        cd.Id,
        cd.Name AS MasterName,
        cd.Code AS MasterCode,
        '' FileName,
        '' FileId,
       
        cd.NumDayAlert,
        null ValidFrom,
        null ValidTo,
        cd.Description,        

        cd.CreatedDate,
        cd.CreatedBy,
        
        -- Compliance Emails từ CTE
        ce.ResponsibleFor as ResponsibleEmails,
        ce.AlertFor as AlertEmails,
        ce.ResponsibleForAddition,
        ce.AlertForAddition,
        
        -- CONCAT(DATEDIFF(cd.ValidTo, CURDATE()), ' days left') AS DaysRemaining
        null DaysRemaining

    FROM compl_masters cd
	LEFT JOIN master_emails ce ON ce.MasterId = cd.Id
    WHERE 
        (
            (p_ids IS NULL OR p_ids = '' AND ((cd.ValidTo IS NOT NULL AND DATE_ADD(CURDATE(), INTERVAL cd.NumDayAlert DAY) >= cd.ValidTo) OR cd.ValidTo < CURDATE()))
            OR (p_ids IS NOT NULL AND p_ids <> '' AND FIND_IN_SET(cd.Id, p_ids))
        )

    GROUP BY 
        cd.Id, cd.Name, cd.Code, cd.NumDayAlert,
        cd.ValidFrom, cd.ValidTo, cd.Description,
        cd.CreatedDate, cd.CreatedBy;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `compl_sp_get_all_related_compliances` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `compl_sp_get_all_related_compliances`(
    IN p_ref_type_id INT,
    IN p_ref_type_value VARCHAR(100),
    IN p_check_date DATE
)
BEGIN
    SET p_check_date = COALESCE(p_check_date, CURDATE());

    -- =====================================================================
    -- CLEANUP
    -- =====================================================================
    DROP TEMPORARY TABLE IF EXISTS tmp_p_country_groups;
    DROP TEMPORARY TABLE IF EXISTS tmp_matched_masters;
    DROP TEMPORARY TABLE IF EXISTS tmp_all_references;
    DROP TEMPORARY TABLE IF EXISTS tmp_valid_references;
    DROP TEMPORARY TABLE IF EXISTS tmp_applied_rows;
    DROP TEMPORARY TABLE IF EXISTS tmp_expired_compliances;
    DROP TEMPORARY TABLE IF EXISTS tmp_expired_compliances_2;
    DROP TEMPORARY TABLE IF EXISTS tmp_master_conditions_json;
    DROP TEMPORARY TABLE IF EXISTS tmp_master_groups_json;
    DROP TEMPORARY TABLE IF EXISTS tmp_missing_individual;
    DROP TEMPORARY TABLE IF EXISTS tmp_missing_master;

    -- =====================================================================
    -- STEP 0b: Build group lookup cho p_ref_type_value
    -- (giữ nguyên)
    -- =====================================================================
    CREATE TEMPORARY TABLE tmp_p_country_groups AS
    SELECT
        cg.Code AS GroupCode
    FROM compl_country_group_members cgm
    INNER JOIN compl_country_groups cg
            ON cg.Id       = cgm.GroupId
           AND cg.IsActive = 1
    INNER JOIN compl_reference_types crt
            ON crt.Id   = p_ref_type_id
           AND crt.Code = 'COUNTRY'
    WHERE cgm.CountryCode = p_ref_type_value;

    ALTER TABLE tmp_p_country_groups
        ADD INDEX idx_group (GroupCode);

    SET @p_group_codes = (
        SELECT GROUP_CONCAT(GroupCode ORDER BY GroupCode SEPARATOR ',')
        FROM tmp_p_country_groups
    );

    -- =====================================================================
    -- STEP 1: Find matched masters
    --
    --   [NOT IN] Tách thành 3 nhánh OR:
    --
    --   Nhánh 1 — IN / = (giữ nguyên):
    --     Thêm COALESCE(cmc.Operator,'=') != 'NOT IN' để loại NOT IN ra,
    --     tránh NOT IN condition bị match sai như IN.
    --
    --   Nhánh 2 — NOT IN [MỚI]:
    --     Master khớp khi p_ref_type_value KHÔNG nằm trong danh sách
    --     loại trừ của bất kỳ NOT IN condition nào.
    --     Dùng NOT EXISTS trên compl_master_condition_values (không phải
    --     temp table) → không bị Error 1137.
    --
    --   Nhánh 3 — No condition (giữ nguyên):
    --     Master không có condition nào → áp dụng cho tất cả.
    -- =====================================================================
    CREATE TEMPORARY TABLE tmp_matched_masters AS
    SELECT DISTINCT
        cm.Id          AS MasterId,
        cm.Code        AS MasterCode,
        cm.Name        AS MasterName,
        cm.ValidFrom   AS MasterValidFrom,
        cm.ValidTo     AS MasterValidTo,
        cm.NumDayAlert,
        cm.Description AS MasterDescription,
        cm.IsIndividual,
        cm.VersionNo   AS MasterVersionNo
    FROM compl_masters cm
    WHERE cm.IsDelete = 0
      AND p_check_date BETWEEN cm.ValidFrom AND COALESCE(cm.ValidTo, '2099-12-31')
      AND NOT EXISTS (
          SELECT 1 FROM compl_masters cm_newer
          WHERE cm_newer.Code     = cm.Code
            AND cm_newer.IsDelete = 0
            AND p_check_date BETWEEN cm_newer.ValidFrom AND COALESCE(cm_newer.ValidTo, '2099-12-31')
            AND (
                cm_newer.ValidFrom > cm.ValidFrom
                OR (cm_newer.ValidFrom = cm.ValidFrom AND cm_newer.Id > cm.Id)
            )
      )
      AND (

          -- ── Nhánh 1: IN / = operators (giữ nguyên logic) ─────────────
          -- Thêm Operator != 'NOT IN' để loại NOT IN ra khỏi nhánh này
          EXISTS (
              SELECT 1
              FROM compl_master_conditions cmc
              INNER JOIN compl_master_condition_values cmcv
                      ON cmcv.ConditionId = cmc.Id
              WHERE cmc.MasterId = cm.Id
                AND COALESCE(cmc.Operator, '=') != 'NOT IN'  -- [NOT IN] Loại NOT IN
                AND cmc.RefTypeId = p_ref_type_id
                AND (
                    cmcv.RefTypeValue = p_ref_type_value
                    OR cmcv.RefTypeValue = 'ALL'
                    OR (
                        @p_group_codes IS NOT NULL
                        AND FIND_IN_SET(cmcv.RefTypeValue, @p_group_codes) > 0
                    )
                )
          )

          OR

          -- ── Nhánh 2: NOT IN operator [MỚI] ───────────────────────────
          -- Master khớp khi p_ref_type_value KHÔNG bị loại trừ bởi
          -- bất kỳ NOT IN condition nào trên cùng ref type.
          EXISTS (
              SELECT 1
              FROM compl_master_conditions cmc
              WHERE cmc.MasterId = cm.Id
                AND cmc.Operator = 'NOT IN'
                AND cmc.RefTypeId = p_ref_type_id
                AND NOT EXISTS (
                    SELECT 1
                    FROM compl_master_condition_values cmcv
                    WHERE cmcv.ConditionId = cmc.Id
                      AND (
                          -- p_ref_type_value nằm trong danh sách loại trừ
                          cmcv.RefTypeValue = p_ref_type_value
                          OR
                          -- p_ref_type_value thuộc group bị loại trừ
                          (
                              @p_group_codes IS NOT NULL
                              AND FIND_IN_SET(cmcv.RefTypeValue, @p_group_codes) > 0
                          )
                      )
                )
          )

          OR

          -- ── Nhánh 3: Không có condition nào (giữ nguyên) ─────────────
          NOT EXISTS (
              SELECT 1 FROM compl_master_conditions WHERE MasterId = cm.Id
          )

      );

    -- =====================================================================
    -- STEP 2: Pre-compute ConditionsJson per MasterId
    --
    --   [NOT IN] Thêm xử lý status cho NOT IN condition values:
    --     - Các giá trị trong NOT IN list là "exclusion markers", không phải
    --       giá trị áp dụng → status = 'NoMap' cho tất cả NOT IN values.
    --     - Lý do: nếu master đã match đến đây thì p_ref_type_value chắc
    --       chắn KHÔNG bị loại trừ, nên các exclusion values đều ≠ input.
    --     - Thêm CASE đầu tiên check cmc.Operator = 'NOT IN' trước các
    --       nhánh cũ (cmc accessible vì subquery correlated).
    -- =====================================================================
    CREATE TEMPORARY TABLE tmp_master_conditions_json AS
    SELECT
        mm.MasterId,
        (
            SELECT JSON_ARRAYAGG(
                JSON_OBJECT(
                    'id',           cmc.Id,
                    'logical',      cmc.Logical,
                    'operator',     cmc.Operator,
                    'complType',    cmc.ComplType,
                    'refTypeId',    cmc.RefTypeId,
                    'displayType',  cmc.DisplayType,
                    'logicalName',  CASE cmc.Logical WHEN 1 THEN 'AND' WHEN 2 THEN 'OR' ELSE 'UNKNOWN' END,
                    'refTypeCode',  crt.Code,
                    'refTypeName',  crt.Name,
                    'conditionValues', (
                        SELECT JSON_ARRAYAGG(
                            JSON_OBJECT(
                                'id',                  cmcv.Id,
                                'ConditionId',         cmcv.ConditionId,
                                'refTypeValue',        cmcv.RefTypeValue,
                                'refTypeValueDisplay', cmcv.RefTypeValue,
                                'status', CASE
                                    -- [NOT IN] Exclusion values → NoMap
                                    -- cmc.Operator accessible vì subquery correlated với cmc bên ngoài
                                    WHEN cmc.Operator = 'NOT IN' THEN 'NoMap'
                                    -- [Giữ nguyên] NoMap: không khớp exact, ALL, hoặc group
                                    WHEN NOT (
                                        cmcv.RefTypeValue = p_ref_type_value
                                        OR (
                                            cmcv.RefTypeValue = 'ALL'
                                            AND p_ref_type_value IS NOT NULL
                                            AND p_ref_type_value != ''
                                        )
                                        OR (
                                            @p_group_codes IS NOT NULL
                                            AND FIND_IN_SET(cmcv.RefTypeValue, @p_group_codes) > 0
                                        )
                                    ) THEN 'NoMap'
                                    -- [Giữ nguyên] Map-Missing / Map-Ok
                                    WHEN NOT EXISTS (
                                        SELECT 1 FROM compl_references cr2
                                        WHERE cr2.MasterId  = mm.MasterId
                                          AND cr2.RefTypeId = cmc.RefTypeId
                                          AND (
                                              cr2.RefTypeValue = cmcv.RefTypeValue
                                              OR (cmcv.RefTypeValue = 'ALL' AND cr2.ComplType = 0)
                                          )
                                    ) THEN 'Map-Missing'
                                    ELSE 'Map-Ok'
                                END
                            )
                        )
                        FROM compl_master_condition_values cmcv
                        WHERE cmcv.ConditionId = cmc.Id
                    )
                )
            )
            FROM compl_master_conditions cmc
            LEFT JOIN compl_reference_types crt ON crt.Id = cmc.RefTypeId
            WHERE cmc.MasterId = mm.MasterId
        ) AS ConditionsJson
    FROM tmp_matched_masters mm;

    -- =====================================================================
    -- STEP 3: Pre-compute master-level email groups per MasterId
    -- (giữ nguyên)
    -- =====================================================================
    CREATE TEMPORARY TABLE tmp_master_groups_json AS
    SELECT
        mm.MasterId,
        (
            SELECT JSON_ARRAYAGG(JSON_OBJECT('groupName', ge.Name, 'emails',
                (SELECT JSON_ARRAYAGG(cged.ResponseEmail) FROM compl_group_email_detail cged
                 WHERE cged.GroupEmailId = ge.Id AND cged.IsActive = TRUE)))
            FROM compl_master_group_email cmge
            INNER JOIN compl_group_email ge ON cmge.GroupEmailId = ge.Id
            WHERE cmge.MasterId = mm.MasterId AND cmge.GroupType = 2
        ) AS AlertGroupsJson,
        (
            SELECT JSON_ARRAYAGG(JSON_OBJECT('groupName', ge.Name, 'emails',
                (SELECT JSON_ARRAYAGG(cged.ResponseEmail) FROM compl_group_email_detail cged
                 WHERE cged.GroupEmailId = ge.Id AND cged.IsActive = TRUE)))
            FROM compl_master_group_email cmge
            INNER JOIN compl_group_email ge ON cmge.GroupEmailId = ge.Id
            WHERE cmge.MasterId = mm.MasterId AND cmge.GroupType = 1
        ) AS ResponsibleGroupsJson
    FROM tmp_matched_masters mm;

    -- =====================================================================
    -- STEP 4: Get all compliance references for matched masters
    -- (giữ nguyên)
    -- =====================================================================
    CREATE TEMPORARY TABLE tmp_all_references AS
    SELECT
        mm.MasterId,
        mm.MasterCode,
        mm.MasterName,
        mm.MasterValidFrom,
        mm.MasterValidTo,
        mm.NumDayAlert,
        mm.MasterDescription,
        mm.IsIndividual,
        mm.MasterVersionNo,
        cr.Id           AS RefId,
        cr.ComplianceId,
        cr.ComplType,
        cr.RefTypeId,
        cr.RefTypeValue
    FROM tmp_matched_masters mm
    LEFT JOIN compl_references cr ON cr.MasterId = mm.MasterId;

    -- =====================================================================
    -- STEP 5: Validate references
    -- (giữ nguyên — references được validate theo value của chúng,
    --  không phụ thuộc vào operator của condition)
    -- =====================================================================
    CREATE TEMPORARY TABLE tmp_valid_references AS
    SELECT
        ar.*,
        CASE
            WHEN ar.RefId IS NULL THEN 0
            WHEN ar.ComplType = 0 THEN 1
            WHEN ar.ComplType = 1
                 AND ar.RefTypeId    = p_ref_type_id
                 AND ar.RefTypeValue IS NOT NULL
            THEN
                CASE
                    WHEN ar.RefTypeValue = p_ref_type_value
                      OR ar.RefTypeValue = 'ALL'
                    THEN 1
                    WHEN (
                        @p_group_codes IS NOT NULL
                        AND FIND_IN_SET(ar.RefTypeValue, @p_group_codes) > 0
                    )
                    THEN 1
                    ELSE 0
                END
            ELSE 0
        END AS IsValidReference,
        mcj.ConditionsJson
    FROM tmp_all_references ar
    LEFT JOIN tmp_master_conditions_json mcj ON mcj.MasterId = ar.MasterId;

    -- =====================================================================
    -- STEP 6: Build applied rows (active compliances only)
    -- (giữ nguyên)
    -- =====================================================================
    CREATE TEMPORARY TABLE tmp_applied_rows AS
    SELECT
        vr.MasterId,
        vr.MasterCode,
        vr.MasterName,
        vr.MasterValidFrom,
        vr.MasterValidTo,
        vr.NumDayAlert,
        vr.MasterDescription,
        vr.IsIndividual,
        vr.MasterVersionNo,
        cc.Id           AS ComplianceId,
        cc.Code         AS ComplianceCode,
        cc.Name         AS ComplianceName,
        cc.FileId,
        cc.ValidFrom    AS ComplianceValidFrom,
        cc.ValidTo      AS ComplianceValidTo,
        cc.NumDayAlert  AS ComplianceNumDayAlert,
        cc.Description  AS ComplianceDescription,
        cc.VersionNo    AS ComplianceVersionNo,
        cc.ReplacedById AS ComplianceReplacedById,
        ROW_NUMBER() OVER (
            PARTITION BY vr.MasterId, COALESCE(vr.RefTypeValue, '')
            ORDER BY cc.VersionNo DESC, cc.Id DESC
        ) AS rn,
        (
            SELECT JSON_ARRAYAGG(JSON_OBJECT('groupName', ge.Name, 'emails',
                (SELECT JSON_ARRAYAGG(cged.ResponseEmail) FROM compl_group_email_detail cged
                 WHERE cged.GroupEmailId = ge.Id AND cged.IsActive = TRUE)))
            FROM compl_compliance_group_email cmge
            INNER JOIN compl_group_email ge ON cmge.GroupEmailId = ge.Id
            WHERE cmge.ComplianceId = cc.Id AND cmge.GroupType = 2
        ) AS AlertGroupsJsonComp,
        (
            SELECT JSON_ARRAYAGG(JSON_OBJECT('groupName', ge.Name, 'emails',
                (SELECT JSON_ARRAYAGG(cged.ResponseEmail) FROM compl_group_email_detail cged
                 WHERE cged.GroupEmailId = ge.Id AND cged.IsActive = TRUE)))
            FROM compl_compliance_group_email cmge
            INNER JOIN compl_group_email ge ON cmge.GroupEmailId = ge.Id
            WHERE cmge.ComplianceId = cc.Id AND cmge.GroupType = 1
        ) AS ResponsibleGroupsJsonComp,
        vr.ConditionsJson,
        vr.RefTypeId    AS MappedRefTypeId,
        crt_map.Code    AS MappedRefTypeCode,
        crt_map.Name    AS MappedRefTypeName,
        vr.RefTypeValue AS MappedInputValue
    FROM tmp_valid_references vr
    INNER JOIN compl_compliances cc
           ON  cc.Id       = vr.ComplianceId
          AND  cc.IsDelete = 0
          AND  p_check_date >= DATE(cc.ValidFrom)
          AND  p_check_date <= DATE(COALESCE(cc.ValidTo, '2099-12-31'))
    LEFT JOIN compl_reference_types crt_map ON crt_map.Id = vr.RefTypeId
    WHERE vr.IsValidReference = 1;

    -- =====================================================================
    -- STEP 7: Collect expired compliances (for MISSING rows)
    -- (giữ nguyên)
    -- =====================================================================
    CREATE TEMPORARY TABLE tmp_expired_compliances AS
    SELECT
        cr.MasterId,
        cr.RefTypeId,
        cr.RefTypeValue,
        cr.ComplType    AS RefComplType,
        cc.Id           AS ExpiredComplianceId,
        cc.Code         AS ExpiredComplianceCode,
        cc.Name         AS ExpiredComplianceName,
        cc.FileId       AS ExpiredFileId,
        cc.ValidFrom    AS ExpiredValidFrom,
        cc.ValidTo      AS ExpiredValidTo,
        cc.NumDayAlert  AS ExpiredNumDayAlert,
        cc.Description  AS ExpiredComplianceDescription,
        cc.ReplacedById AS ExpiredReplacedById,
        cc.VersionNo    AS ExpiredVersionNo,
        ROW_NUMBER() OVER (
            PARTITION BY cr.MasterId, cr.RefTypeValue
            ORDER BY cc.ValidTo DESC
        ) AS rn
    FROM compl_references cr
    INNER JOIN compl_compliances cc
           ON  cc.Id       = cr.ComplianceId
          AND  cc.IsDelete = 0
          AND  DATE(cc.ValidTo) < p_check_date;

    CREATE TEMPORARY TABLE tmp_expired_compliances_2 AS
    SELECT * FROM tmp_expired_compliances;

    -- =====================================================================
    -- STEP 8: Pre-build MISSING rows for IsIndividual = 1
    --
    --   [NOT IN] Thêm AND cmc.Operator != 'NOT IN' vào JOIN condition:
    --     NOT IN conditions không phát sinh yêu cầu compliance riêng lẻ.
    --     Ví dụ: Customer NOT IN (10574, 10665) không có nghĩa là
    --     p_ref_type_value cần có compliance — đây là điều kiện loại trừ,
    --     không phải điều kiện bắt buộc tuân thủ.
    --
    --   Logic (A) và (B) giữ nguyên — chỉ áp dụng cho IN conditions.
    -- =====================================================================
    CREATE TEMPORARY TABLE tmp_missing_individual AS
    SELECT
        mm.MasterId,
        mm.MasterCode,
        mm.MasterName,
        mm.MasterValidFrom,
        mm.MasterValidTo,
        mm.NumDayAlert,
        mm.MasterDescription,
        mm.IsIndividual,
        mm.MasterVersionNo,
        p_ref_type_id    AS MappedRefTypeId,
        crt_main.Code    AS MappedRefTypeCode,
        crt_main.Name    AS MappedRefTypeName,
        p_ref_type_value AS MappedInputValue,
        mgj.AlertGroupsJson,
        mgj.ResponsibleGroupsJson,
        mcj.ConditionsJson
    FROM tmp_matched_masters mm
    INNER JOIN compl_master_conditions cmc
           ON  cmc.MasterId  = mm.MasterId
          AND  cmc.ComplType = 1
          AND  cmc.RefTypeId = p_ref_type_id
          AND  cmc.Operator != 'NOT IN'              -- [NOT IN] Bỏ NOT IN — không check missing
    LEFT JOIN compl_reference_types    crt_main ON crt_main.Id = p_ref_type_id
    LEFT JOIN tmp_master_groups_json   mgj      ON mgj.MasterId = mm.MasterId
    LEFT JOIN tmp_master_conditions_json mcj    ON mcj.MasterId = mm.MasterId
    WHERE mm.IsIndividual = 1
      -- (A) Condition value phải khớp: ALL, exact, hoặc group (giữ nguyên)
      AND (
          EXISTS (
              SELECT 1 FROM compl_master_condition_values cmcv
              WHERE cmcv.ConditionId = cmc.Id
                AND cmcv.RefTypeValue = 'ALL'
          )
          OR
          EXISTS (
              SELECT 1 FROM compl_master_condition_values cmcv
              WHERE cmcv.ConditionId = cmc.Id
                AND cmcv.RefTypeValue = p_ref_type_value
          )
          OR
          (
              @p_group_codes IS NOT NULL
              AND EXISTS (
                  SELECT 1
                  FROM compl_master_condition_values cmcv
                  WHERE cmcv.ConditionId = cmc.Id
                    AND FIND_IN_SET(cmcv.RefTypeValue, @p_group_codes) > 0
              )
          )
      )
      -- (B) Không có compliance đang valid cho input này (giữ nguyên)
      AND NOT EXISTS (
          SELECT 1
          FROM compl_references cr
          INNER JOIN compl_compliances cc
                 ON  cc.Id       = cr.ComplianceId
                AND  cc.IsDelete = 0
                AND  p_check_date >= DATE(cc.ValidFrom)
                AND  p_check_date <= DATE(COALESCE(cc.ValidTo, '2099-12-31'))
          WHERE cr.MasterId  = mm.MasterId
            AND cr.RefTypeId = cmc.RefTypeId
            AND (
                cr.RefTypeValue = p_ref_type_value
                OR
                (
                    @p_group_codes IS NOT NULL
                    AND FIND_IN_SET(cr.RefTypeValue, @p_group_codes) > 0
                )
            )
      )
    GROUP BY
        mm.MasterId, mm.MasterCode, mm.MasterName,
        mm.MasterValidFrom, mm.MasterValidTo,
        mm.NumDayAlert, mm.MasterDescription,
        mm.IsIndividual, mm.MasterVersionNo,
        crt_main.Code, crt_main.Name,
        mgj.AlertGroupsJson, mgj.ResponsibleGroupsJson,
        mcj.ConditionsJson;

    -- =====================================================================
    -- STEP 9: Pre-build MISSING rows for IsIndividual = 0
    -- (giữ nguyên — NOT IN không ảnh hưởng đến master-level missing:
    --  logic check ComplType=1 conditions và applied rows không đổi)
    -- =====================================================================
    CREATE TEMPORARY TABLE tmp_missing_master AS
    SELECT
        mm.MasterId,
        mm.MasterCode,
        mm.MasterName,
        mm.MasterValidFrom,
        mm.MasterValidTo,
        mm.NumDayAlert,
        mm.MasterDescription,
        mm.IsIndividual,
        mm.MasterVersionNo,
        mgj.AlertGroupsJson,
        mgj.ResponsibleGroupsJson,
        mcj.ConditionsJson
    FROM tmp_matched_masters mm
    LEFT JOIN tmp_master_groups_json     mgj ON mgj.MasterId = mm.MasterId
    LEFT JOIN tmp_master_conditions_json mcj ON mcj.MasterId = mm.MasterId
    WHERE mm.IsIndividual = 0
      AND NOT EXISTS (
          SELECT 1 FROM compl_master_conditions cmc_chk
          WHERE cmc_chk.MasterId = mm.MasterId AND cmc_chk.ComplType = 1
      )
      AND (
          NOT EXISTS (SELECT 1 FROM compl_references cr WHERE cr.MasterId = mm.MasterId)
          OR (
              EXISTS  (SELECT 1 FROM compl_references cr WHERE cr.MasterId = mm.MasterId)
              AND NOT EXISTS (
                  SELECT 1 FROM tmp_applied_rows ar_chk
                  WHERE ar_chk.MasterId = mm.MasterId AND ar_chk.rn = 1
              )
          )
      )
    GROUP BY
        mm.MasterId, mm.MasterCode, mm.MasterName,
        mm.MasterValidFrom, mm.MasterValidTo,
        mm.NumDayAlert, mm.MasterDescription,
        mm.IsIndividual, mm.MasterVersionNo,
        mgj.AlertGroupsJson, mgj.ResponsibleGroupsJson,
        mcj.ConditionsJson;

    -- =====================================================================
    -- STEP 10: Final UNION output
    -- (giữ nguyên)
    -- =====================================================================
    SELECT
        MasterId,
        MasterCode,
        MasterName,
        MasterValidFrom,
        MasterValidTo,
        NumDayAlert         AS MasterNumDayAlert,
        MasterDescription   AS Description,
        MasterVersionNo,
        Status,
        COALESCE(Id,   0)   AS Id,
        COALESCE(Code, '')  AS Code,
        COALESCE(Name, '')  AS Name,
        COALESCE(FileId,'') AS FileId,
        ValidFrom,
        ValidTo,
        NumDayAlert2        AS NumDayAlert,
        VersionNo,
        ReplacedById,
        COALESCE(ComplianceDescription, '') AS ComplianceDescription,
        AlertGroupsJson,
        ResponsibleGroupsJson,
        ConditionsJson,
        CAST(MappedRefTypeId   AS UNSIGNED)  AS MappedRefTypeId,
        CAST(MappedRefTypeCode AS CHAR(150)) AS MappedRefTypeCode,
        CAST(MappedRefTypeName AS CHAR(300)) AS MappedRefTypeName,
        CAST(MappedInputValue  AS CHAR(255)) AS MappedInputValue
    FROM (

        -- Stream 1: APPLIED
        SELECT
            ar.MasterId, ar.MasterCode, ar.MasterName,
            ar.MasterValidFrom, ar.MasterValidTo,
            ar.NumDayAlert, ar.MasterDescription, ar.MasterVersionNo,
            'APPLIED' AS Status,
            ar.ComplianceId                                            AS Id,
            ar.ComplianceCode                                          AS Code,
            CONCAT(ar.MasterName, ' ', ar.ComplianceName)             AS Name,
            ar.FileId,
            ar.ComplianceValidFrom                                     AS ValidFrom,
            ar.ComplianceValidTo                                       AS ValidTo,
            ar.ComplianceNumDayAlert                                   AS NumDayAlert2,
            ar.ComplianceVersionNo                                     AS VersionNo,
            ar.ComplianceReplacedById                                  AS ReplacedById,
            ar.ComplianceDescription,
            COALESCE(mgj.AlertGroupsJson,       ar.AlertGroupsJsonComp)       AS AlertGroupsJson,
            COALESCE(mgj.ResponsibleGroupsJson, ar.ResponsibleGroupsJsonComp) AS ResponsibleGroupsJson,
            ar.ConditionsJson,
            ar.MappedRefTypeId, ar.MappedRefTypeCode,
            ar.MappedRefTypeName, ar.MappedInputValue
        FROM tmp_applied_rows ar
        LEFT JOIN tmp_master_groups_json mgj ON mgj.MasterId = ar.MasterId
        WHERE ar.rn = 1

        UNION ALL

        -- Stream 2: MISSING – per input value (IsIndividual = 1)
        SELECT
            mi.MasterId, mi.MasterCode, mi.MasterName,
            mi.MasterValidFrom, mi.MasterValidTo,
            mi.NumDayAlert, mi.MasterDescription, mi.MasterVersionNo,
            'MISSING' AS Status,
            ec.ExpiredComplianceId   AS Id,
            ec.ExpiredComplianceCode AS Code,
            ec.ExpiredComplianceName AS Name,
            ec.ExpiredFileId         AS FileId,
            ec.ExpiredValidFrom      AS ValidFrom,
            ec.ExpiredValidTo        AS ValidTo,
            ec.ExpiredNumDayAlert    AS NumDayAlert2,
            ec.ExpiredVersionNo      AS VersionNo,
            ec.ExpiredReplacedById   AS ReplacedById,
            ec.ExpiredComplianceDescription AS ComplianceDescription,
            mi.AlertGroupsJson,
            mi.ResponsibleGroupsJson,
            mi.ConditionsJson,
            mi.MappedRefTypeId, mi.MappedRefTypeCode,
            mi.MappedRefTypeName, mi.MappedInputValue
        FROM tmp_missing_individual mi
        LEFT JOIN tmp_expired_compliances ec
               ON ec.MasterId    = mi.MasterId
              AND ec.RefTypeValue = mi.MappedInputValue
              AND ec.rn          = 1

        UNION ALL

        -- Stream 3: MISSING – master level (IsIndividual = 0)
        SELECT
            mm2.MasterId, mm2.MasterCode, mm2.MasterName,
            mm2.MasterValidFrom, mm2.MasterValidTo,
            mm2.NumDayAlert, mm2.MasterDescription, mm2.MasterVersionNo,
            'MISSING' AS Status,
            ec.ExpiredComplianceId                                      AS Id,
            ec.ExpiredComplianceCode                                    AS Code,
            CONCAT(mm2.MasterName, COALESCE(ec.ExpiredComplianceName,'')) AS Name,
            ec.ExpiredFileId         AS FileId,
            ec.ExpiredValidFrom      AS ValidFrom,
            ec.ExpiredValidTo        AS ValidTo,
            ec.ExpiredNumDayAlert    AS NumDayAlert2,
            ec.ExpiredVersionNo      AS VersionNo,
            ec.ExpiredReplacedById   AS ReplacedById,
            ec.ExpiredComplianceDescription AS ComplianceDescription,
            mm2.AlertGroupsJson,
            mm2.ResponsibleGroupsJson,
            mm2.ConditionsJson,
            NULL AS MappedRefTypeId,
            NULL AS MappedRefTypeCode,
            NULL AS MappedRefTypeName,
            NULL AS MappedInputValue
        FROM tmp_missing_master mm2
        LEFT JOIN tmp_expired_compliances_2 ec
               ON ec.MasterId    = mm2.MasterId
              AND ec.RefComplType = 0
              AND ec.rn          = 1

    ) final_output
    ORDER BY MasterCode, Status DESC;

    -- =====================================================================
    -- CLEANUP
    -- =====================================================================
    DROP TEMPORARY TABLE IF EXISTS tmp_p_country_groups;
    DROP TEMPORARY TABLE IF EXISTS tmp_matched_masters;
    DROP TEMPORARY TABLE IF EXISTS tmp_all_references;
    DROP TEMPORARY TABLE IF EXISTS tmp_valid_references;
    DROP TEMPORARY TABLE IF EXISTS tmp_applied_rows;
    DROP TEMPORARY TABLE IF EXISTS tmp_expired_compliances;
    DROP TEMPORARY TABLE IF EXISTS tmp_expired_compliances_2;
    DROP TEMPORARY TABLE IF EXISTS tmp_master_conditions_json;
    DROP TEMPORARY TABLE IF EXISTS tmp_master_groups_json;
    DROP TEMPORARY TABLE IF EXISTS tmp_missing_individual;
    DROP TEMPORARY TABLE IF EXISTS tmp_missing_master;

END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `compl_sp_get_compliances_by_master_id_static_paging` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `compl_sp_get_compliances_by_master_id_static_paging`(
    IN p_limit INT,
    IN p_offset INT,
    IN p_order_column VARCHAR(50),
    IN p_order_direction VARCHAR(4),
    IN p_search_text VARCHAR(255),
    IN p_due_days INT,
    IN p_user_email VARCHAR(50),
    IN p_master_id BIGINT,
    IN p_ref_type_value VARCHAR(255)
)
BEGIN
    WITH
    /* =======================
       LATEST COMPLIANCE VERSIONS
    ======================= */
    LatestComplianceVersions AS (
        SELECT Code, MAX(VersionNo) AS MaxVersion
        FROM compl_compliances
        GROUP BY Code
    ),
    /* =======================
       GROUP IDS
    ======================= */
    cte_group_ids AS (
        SELECT
            ComplianceId,
            GROUP_CONCAT(
                DISTINCT CASE WHEN GroupType = 2 THEN GroupEmailId END
                ORDER BY GroupEmailId SEPARATOR ','
            ) AS AlertGroupIds,
            GROUP_CONCAT(
                DISTINCT CASE WHEN GroupType = 1 THEN GroupEmailId END
                ORDER BY GroupEmailId SEPARATOR ','
            ) AS RespGroupIds
        FROM compl_compliance_group_email
        GROUP BY ComplianceId
    ),
	-- CTE để aggregate email groups theo ComplianceId
    compliance_emails AS (
        SELECT 
            ccge.ComplianceId,
            -- GroupType = 1: ResponsibleFor
            GROUP_CONCAT(DISTINCT CASE WHEN ccge.GroupType = 1 THEN cged.ResponseEmail END 
                ORDER BY CASE WHEN ccge.GroupType = 1 THEN cged.ResponseEmail END 
                SEPARATOR ',') AS ResponsibleFor,
            -- GroupType = 2: AlertFor
            GROUP_CONCAT(DISTINCT CASE WHEN ccge.GroupType = 2 THEN cged.ResponseEmail END 
                ORDER BY CASE WHEN ccge.GroupType = 2 THEN cged.ResponseEmail END 
                SEPARATOR ',') AS AlertFor,
            -- GroupType = 3: ResponsibleForAddition
            GROUP_CONCAT(DISTINCT CASE WHEN ccge.GroupType = 3 THEN cged.ResponseEmail END 
                ORDER BY CASE WHEN ccge.GroupType = 3 THEN cged.ResponseEmail END 
                SEPARATOR ',') AS ResponsibleForAddition,
            -- GroupType = 4: AlertForAddition
            GROUP_CONCAT(DISTINCT CASE WHEN ccge.GroupType = 4 THEN cged.ResponseEmail END 
                ORDER BY CASE WHEN ccge.GroupType = 4 THEN cged.ResponseEmail END 
                SEPARATOR ',') AS AlertForAddition
        FROM compl_compliance_group_email ccge
        LEFT JOIN compl_group_email_detail cged ON cged.GroupEmailId = ccge.GroupEmailId AND cged.IsActive = TRUE
        GROUP BY ccge.ComplianceId
    ),
    /* =======================
       GROUPS JSON
    ======================= */
    cte_groups_json AS (
        SELECT
            cmge.ComplianceId,
            cmge.GroupType,
            JSON_ARRAYAGG(
                JSON_OBJECT(
                    'groupName', ge.Name,
                    'emails', ged.Emails
                )
            ) AS GroupsJson
        FROM compl_compliance_group_email cmge
        JOIN compl_group_email ge
            ON ge.Id = cmge.GroupEmailId
        LEFT JOIN (
            SELECT
                GroupEmailId,
                JSON_ARRAYAGG(ResponseEmail) AS Emails
            FROM compl_group_email_detail
            WHERE IsActive = TRUE
            GROUP BY GroupEmailId
        ) ged
            ON ged.GroupEmailId = ge.Id
        GROUP BY cmge.ComplianceId, cmge.GroupType
    ),

    /* =======================
       CONDITIONS JSON
    ======================= */
    cte_conditions_json AS (
        SELECT
			mc.MasterId,
			JSON_ARRAYAGG(
				JSON_OBJECT(
					'id', mc.Id,
					'logical', mc.Logical,
					'logicalName', IF(mc.Logical = 1, 'AND', 'OR'),
					'refTypeId', mc.RefTypeId,
					'refTypeCode', rt.Code,
					'refTypeName', rt.Name,
					'operator', mc.Operator,
					'complType', mc.ComplType,
					'conditionValues', (
						SELECT JSON_ARRAYAGG(
							JSON_OBJECT(
								'id', mcv.Id,
                                'conditionId', mcv.ConditionId,
								'refTypeValue', mcv.RefTypeValue,
                                'refTypeValueDisplay', mcv.RefTypeValue
							)
						)
						FROM compl_master_condition_values mcv
						WHERE mcv.ConditionId = mc.Id
					)
				)
			) AS ConditionsJson
		FROM compl_master_conditions mc
		JOIN compl_reference_types rt
			ON rt.Id = mc.RefTypeId
		GROUP BY mc.MasterId
    )

    SELECT
		-- Master Code và Name
        cm.Id AS MasterId,
        cm.Code AS MasterCode,
        cm.Name AS MasterName,
        cm.VersionNo as MasterVersionNo,
        cm.ValidFrom AS MasterValidFrom,
        cm.ValidTo AS MasterValidTo,
        
        cd.Id,
        cd.Name,
        cd.Code,
        cd.NumDayAlert,
        cd.ValidFrom,
        cd.ValidTo,
        cd.Description,
        cd.CreatedDate,
        cd.CreatedBy,
        cd.VersionNo,
        cd.ReplacedById,
        
        -- Applied RefTypeId
		(
			SELECT crt2.Id
			FROM compl_references cr2
			INNER JOIN compl_reference_types crt2 ON crt2.Id = cr2.RefTypeId
			WHERE cr2.ComplianceId = cd.Id
			  AND cr2.RefTypeValue IS NOT NULL
			  AND (cr2.ValidTo IS NULL OR cr2.ValidTo >= NOW())
			LIMIT 1
		) AS RefTypeId,
		-- Applied RefTypeCode
		(
			SELECT crt2.Code
			FROM compl_references cr2
			INNER JOIN compl_reference_types crt2 ON crt2.Id = cr2.RefTypeId
			WHERE cr2.ComplianceId = cd.Id
			  AND cr2.RefTypeValue IS NOT NULL
			  AND (cr2.ValidTo IS NULL OR cr2.ValidTo >= NOW())
			LIMIT 1
		) AS RefTypeCode,
		-- Applied RefTypeValue
		(
			SELECT cr2.RefTypeValue
			FROM compl_references cr2
			WHERE cr2.ComplianceId = cd.Id
			  AND cr2.RefTypeValue IS NOT NULL
			  AND (cr2.ValidTo IS NULL OR cr2.ValidTo >= NOW())
			LIMIT 1
		) AS RefTypeValue,

        gi.AlertGroupIds,
        gi.RespGroupIds,

        ag.GroupsJson AS AlertGroupsJson,
        rg.GroupsJson AS ResponsibleGroupsJson,
		-- Compliance Emails từ CTE
        ce.ResponsibleFor as ResponsibleEmails,
        ce.AlertFor AS AlertEmails,
        ce.ResponsibleForAddition,
        ce.AlertForAddition,
        
        cj.ConditionsJson,
        
        cd.FileId,
        f.Name AS FileName,
        CONCAT(ROUND(f.Size / (1024 * 1024), 1), ' MB') AS FileSize,
        f.CreatedDatetime AS FileCreateDate
        
    FROM compl_compliances cd
    INNER JOIN LatestComplianceVersions lcv
        ON cd.Code = lcv.Code 
       AND cd.VersionNo = lcv.MaxVersion
    INNER JOIN compl_references cr
        ON cr.ComplianceId = cd.Id
       AND cr.MasterId = p_master_id
       -- filter theo p_ref_type_value
       AND (
           p_ref_type_value IS NULL
           OR TRIM(p_ref_type_value) = ''
           OR cr.RefTypeValue = p_ref_type_value
       )
    LEFT JOIN compl_masters cm
		ON cm.Id = p_master_id

    LEFT JOIN cte_group_ids gi
        ON gi.ComplianceId = cd.Id

    LEFT JOIN cte_groups_json ag
        ON ag.ComplianceId = cd.Id
       AND ag.GroupType = 2

    LEFT JOIN cte_groups_json rg
        ON rg.ComplianceId = cd.Id
       AND rg.GroupType = 1

    LEFT JOIN cte_conditions_json cj
        ON cj.MasterId = cr.MasterId
	
    LEFT JOIN compl_sharepoint_files f 
		ON cd.FileId = f.FileId
        
    LEFT JOIN compliance_emails ce 
		ON ce.ComplianceId = cd.Id    
    /* =======================
       FILTER
    ======================= */
    WHERE
        /* SEARCH */
        (
            p_search_text IS NULL
            OR TRIM(p_search_text) = ''
            OR (
                CHAR_LENGTH(TRIM(p_search_text)) >= 3
                AND MATCH(cd.Name, cd.Code, cd.Description)
                    AGAINST (p_search_text IN BOOLEAN MODE)
            )
            OR (
                CHAR_LENGTH(TRIM(p_search_text)) < 3
                AND (
                    cd.Name LIKE CONCAT('%', p_search_text, '%')
                    OR cd.Code LIKE CONCAT('%', p_search_text, '%')
                    OR cd.Description LIKE CONCAT('%', p_search_text, '%')
                )
            )
        )

        /* DUE DAYS */
        AND (
            p_due_days IS NULL
            OR (
                cd.ValidTo IS NOT NULL
                AND cd.ValidTo <= DATE_ADD(UTC_TIMESTAMP(), INTERVAL p_due_days DAY)
            )
        )

        /* USER EMAIL */
        AND (
            p_user_email IS NULL
            OR TRIM(p_user_email) = ''
            OR cd.CreatedBy = p_user_email
            OR EXISTS (
                SELECT 1
                FROM compl_compliance_group_email ccge
                JOIN compl_group_email_detail cged
                    ON ccge.GroupEmailId = cged.GroupEmailId
                WHERE ccge.ComplianceId = cd.Id
                  AND ccge.GroupType = 1
                  AND cged.IsActive = TRUE
                  AND cged.ResponseEmail = p_user_email
            )
        )

    /* =======================
       ORDER BY (WHITELIST)
    ======================= */
    ORDER BY
        CASE
            WHEN p_order_column = 'Name'
             AND UPPER(p_order_direction) = 'ASC'
            THEN cd.Name
        END ASC,
        CASE
            WHEN p_order_column = 'Name'
             AND UPPER(p_order_direction) = 'DESC'
            THEN cd.Name
        END DESC,

        CASE
            WHEN p_order_column = 'Code'
             AND UPPER(p_order_direction) = 'ASC'
            THEN cd.Code
        END ASC,
        CASE
            WHEN p_order_column = 'Code'
             AND UPPER(p_order_direction) = 'DESC'
            THEN cd.Code
        END DESC,

        CASE
            WHEN p_order_column = 'ValidTo'
             AND UPPER(p_order_direction) = 'ASC'
            THEN cd.ValidTo
        END ASC,
        CASE
            WHEN p_order_column = 'ValidTo'
             AND UPPER(p_order_direction) = 'DESC'
            THEN cd.ValidTo
        END DESC,

        /* fallback */
        cd.Id DESC

    LIMIT p_limit OFFSET p_offset;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `compl_sp_get_compliances_by_master_id_static_paging_count` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `compl_sp_get_compliances_by_master_id_static_paging_count`(
    IN p_search_text VARCHAR(255),
    IN p_due_days INT,
    IN p_user_email VARCHAR(50),
    IN p_master_id BIGINT,
    IN p_ref_type_value VARCHAR(255)
)
BEGIN
    SELECT COUNT(*) AS TotalCount
    FROM compl_compliances cd
    INNER JOIN (
        SELECT Code, MAX(VersionNo) AS MaxVersion
        FROM compl_compliances
        GROUP BY Code
    ) lcv
        ON cd.Code = lcv.Code
       AND cd.VersionNo = lcv.MaxVersion
    INNER JOIN compl_references cr
        ON cr.ComplianceId = cd.Id
       AND cr.MasterId = p_master_id
       AND (
           p_ref_type_value IS NULL
           OR TRIM(p_ref_type_value) = ''
           OR cr.RefTypeValue = p_ref_type_value
       )
    WHERE
        /* SEARCH */
        (
            p_search_text IS NULL
            OR TRIM(p_search_text) = ''
            OR (
                CHAR_LENGTH(TRIM(p_search_text)) >= 3
                AND MATCH(cd.Name, cd.Code, cd.Description)
                    AGAINST (p_search_text IN BOOLEAN MODE)
            )
            OR (
                CHAR_LENGTH(TRIM(p_search_text)) < 3
                AND (
                    cd.Name LIKE CONCAT('%', p_search_text, '%')
                    OR cd.Code LIKE CONCAT('%', p_search_text, '%')
                    OR cd.Description LIKE CONCAT('%', p_search_text, '%')
                )
            )
        )

        /* DUE DAYS */
        AND (
            p_due_days IS NULL
            OR (
                cd.ValidTo IS NOT NULL
                AND cd.ValidTo <= DATE_ADD(UTC_TIMESTAMP(), INTERVAL p_due_days DAY)
            )
        )

        /* USER EMAIL */
        AND (
            p_user_email IS NULL
            OR TRIM(p_user_email) = ''
            OR cd.CreatedBy = p_user_email
            OR EXISTS (
                SELECT 1
                FROM compl_compliance_group_email ccge
                JOIN compl_group_email_detail cged
                    ON ccge.GroupEmailId = cged.GroupEmailId
                WHERE ccge.ComplianceId = cd.Id
                  AND ccge.GroupType = 1
                  AND cged.IsActive = TRUE
                  AND cged.ResponseEmail = p_user_email
            )
        );
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `compl_sp_get_compliance_by_reference_dashboard` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `compl_sp_get_compliance_by_reference_dashboard`(
    IN p_due_days INT,
    IN p_user_email VARCHAR(50)
)
BEGIN
    DECLARE v_date DATE;
    DECLARE v_use_filter BOOLEAN DEFAULT TRUE;
    DECLARE v_total_count INT DEFAULT 0;

    /* =========================
       DATE FILTER
       ========================= */
    IF p_due_days IS NULL OR p_due_days = 0 THEN
        SET v_use_filter = FALSE;
    ELSE
        SET v_date = DATE_ADD(CURDATE(), INTERVAL p_due_days DAY);
    END IF;

    /* =========================
       TOTAL COMPLIANCE (1 TIME)
       ========================= */
    SELECT COUNT(DISTINCT c.Id)
    INTO v_total_count
    FROM compl_compliances c
    WHERE
        (
            v_use_filter = FALSE
            OR (
                c.ValidTo IS NOT NULL
                AND c.ValidTo >= CURDATE()   -- ← chưa hết hạn
                AND c.ValidTo <= v_date      -- ← trong khoảng due_days ngày tới
            )
        )
        AND
        (
            p_user_email IS NULL
            OR c.CreatedBy = p_user_email
            OR EXISTS (
                SELECT 1
                FROM compl_compliance_group_email cge
                JOIN compl_group_email_detail ged
                    ON ged.GroupEmailId = cge.GroupEmailId
                   AND ged.IsActive = 1
                WHERE cge.ComplianceId = c.Id
                  AND cge.GroupType = 1
                  AND ged.ResponseEmail = p_user_email
            )
        );

    /* =========================
       CATEGORY BREAKDOWN
       ========================= */
    SELECT JSON_ARRAYAGG(
        JSON_OBJECT(
            'refType',     t.Id,
            'code',        t.Code,
            'name',        t.Name,
            'total',       v_total_count,
            'compliant',   compliant_count,
            'percentage',
                COALESCE(
                    ROUND((compliant_count * 100.0) / NULLIF(v_total_count, 0), 1),
                    0
                ),
            'color',
                CASE t.Code
                    WHEN 'COUNTRY'        THEN '#7c92ff'
                    WHEN 'FACTORY'        THEN '#2196f3'
                    WHEN 'CUSTOMER'       THEN '#4caf50'
                    WHEN 'PRODUCT'        THEN '#ff9800'
                    WHEN 'MATERIAL'       THEN '#9c27b0'
                    WHEN 'PRODUCT_TYPE'   THEN '#00bcd4'
                    WHEN 'VARIANT'        THEN '#795548'
                    WHEN 'ATTRIBUTE'      THEN '#607d8b'
                    WHEN 'COST_GROUP'     THEN '#e91e63'
                    ELSE '#9e9e9e'
                END
        )
    ) AS compliance_by_category
    FROM
    (
        SELECT
            rt.Id,
            rt.Code,
            rt.Name,
            COUNT(DISTINCT c.Id) AS compliant_count
        FROM compl_reference_types rt
        JOIN compl_master_conditions mc
            ON mc.RefTypeId = rt.Id
            AND mc.DisplayType != 0
        JOIN compl_masters m
            ON m.Id = mc.MasterId
        JOIN compl_references r
            ON r.MasterId = m.Id
        JOIN compl_compliances c
            ON c.Id = r.ComplianceId
        WHERE rt.IsActive = 1
          AND
            (
                v_use_filter = FALSE
                OR (
                    c.ValidTo IS NOT NULL
                    AND c.ValidTo >= CURDATE()   -- ← chưa hết hạn
                    AND c.ValidTo <= v_date      -- ← trong khoảng due_days ngày tới
                )
            )
          AND
            (
                p_user_email IS NULL
                OR c.CreatedBy = p_user_email
                OR EXISTS (
                    SELECT 1
                    FROM compl_compliance_group_email cge
                    JOIN compl_group_email_detail ged
                        ON ged.GroupEmailId = cge.GroupEmailId
                       AND ged.IsActive = 1
                    WHERE cge.ComplianceId = c.Id
                      AND cge.GroupType = 1
                      AND ged.ResponseEmail = p_user_email
                )
            )
        GROUP BY rt.Id, rt.Code, rt.Name
    ) t;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `compl_sp_get_compliance_detail_for_export` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `compl_sp_get_compliance_detail_for_export`(IN p_created_by VARCHAR(255))
BEGIN
    SELECT
        m.Code                  AS MasterCode,
        m.Name  				AS MasterName,
        c.Code                  AS ComplianceCode,
        c.Name                  AS ComplianceName,
        c.VersionNo 			as ComplianceVersionNo,
        CASE 
			WHEN ParentPath LIKE '%root:/%' 
			THEN SUBSTRING(ParentPath, LOCATE('root:/', ParentPath) + 6)
			ELSE ParentPath
		 END AS FolderSharePoint,
        sf.Name                 AS FileName,
        c.ValidFrom             AS ValidFrom,
        c.ValidTo               AS ValidTo,
        c.FileId                AS FileId,
        c.Description,
        m.VersionNo				AS MasterVersionNo
    FROM compl_compliances c
    LEFT JOIN compl_sharepoint_files sf
        ON sf.FileId = c.FileId
    LEFT JOIN compl_references r
        ON r.ComplianceId = c.Id
    LEFT JOIN compl_masters m
        ON m.Id = r.MasterId
    WHERE c.IsDelete = 0 AND (c.CreatedBy = p_created_by OR p_created_by = '')
    ORDER BY c.Code, m.Code;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `compl_sp_get_compliance_file_names` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `compl_sp_get_compliance_file_names`(
    IN p_file_ids JSON  -- e.g. '["fileId1","fileId2","fileId3"]'
)
BEGIN
    SELECT distinct
        sf.FileId,
        sf.Name                                             AS OriginalName,
        CONCAT(
            m.Code,        '_',
            REPLACE(m.Name,        '/', '_'), '_',
			REPLACE(IFNULL(m.Description, ''), '/', '_'),
            IF(m.IsIndividual = 1, REPLACE(IFNULL(c.Name, ''), '/', '_'), ''),  -- ← lấy tên compliance cho IsInvidual
            '.',
            SUBSTRING_INDEX(sf.Name, '.', -1)              -- lấy extension
        )                                                   AS FileName
    FROM compl_sharepoint_files   sf
    JOIN compl_compliances        c   ON c.FileId       = sf.FileId
                                     AND c.IsDelete     = 0
    JOIN compl_references         r   ON r.ComplianceId = c.Id
    JOIN compl_masters            m   ON m.Id           = r.MasterId
                                     AND m.IsDelete     = 0
    JOIN JSON_TABLE(
        p_file_ids,
        '$[*]' COLUMNS (FileId VARCHAR(255) PATH '$')
    ) AS jt ON sf.FileId = jt.FileId;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `compl_sp_get_compliance_summary_dashboard` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `compl_sp_get_compliance_summary_dashboard`(
    IN p_due_days INT,
    IN p_user_email VARCHAR(50)
)
BEGIN
    DECLARE totalCount INT DEFAULT 0;
    DECLARE expiringCount INT DEFAULT 0;
    DECLARE overdueCount INT DEFAULT 0;

    /* =========================
       1️⃣ TOTAL COMPLIANCES
       ========================= */
    SELECT COUNT(DISTINCT c.Id)
    INTO totalCount
    FROM compl_compliances c
    WHERE
        (
            p_user_email IS NULL
            OR c.CreatedBy = p_user_email
            OR EXISTS (
                SELECT 1
                FROM compl_compliance_group_email cge
                JOIN compl_group_email_detail ged
                    ON ged.GroupEmailId = cge.GroupEmailId
                   AND ged.IsActive = 1
                WHERE cge.ComplianceId = c.Id
                  AND cge.GroupType = 1 -- RespGroup
                  AND ged.ResponseEmail = p_user_email
            )
        );

    /* =========================
       2️⃣ EXPIRING SOON
       ========================= */
    SELECT COUNT(DISTINCT c.Id)
    INTO expiringCount
    FROM compl_compliances c
    WHERE c.ValidTo IS NOT NULL
      AND c.ValidTo >= CURDATE()
      AND c.ValidTo <= DATE_ADD(CURDATE(), INTERVAL p_due_days DAY)
      AND
        (
            p_user_email IS NULL
            OR c.CreatedBy = p_user_email
            OR EXISTS (
                SELECT 1
                FROM compl_compliance_group_email cge
                JOIN compl_group_email_detail ged
                    ON ged.GroupEmailId = cge.GroupEmailId
                   AND ged.IsActive = 1
                WHERE cge.ComplianceId = c.Id
                  AND cge.GroupType = 1 -- RespGroup
                  AND ged.ResponseEmail = p_user_email
            )
        );

    /* =========================
       3️⃣ OVERDUE
       ========================= */
    SELECT COUNT(DISTINCT c.Id)
    INTO overdueCount
    FROM compl_compliances c
    WHERE c.ValidTo IS NOT NULL
      AND c.ValidTo < CURDATE()
      AND
        (
            p_user_email IS NULL
            OR c.CreatedBy = p_user_email
            OR EXISTS (
                SELECT 1
                FROM compl_compliance_group_email cge
                JOIN compl_group_email_detail ged
                    ON ged.GroupEmailId = cge.GroupEmailId
                   AND ged.IsActive = 1
                WHERE cge.ComplianceId = c.Id
                  AND cge.GroupType = 1 -- RespGroup
                  AND ged.ResponseEmail = p_user_email
            )
        );

    /* =========================
       4️⃣ RETURN JSON ARRAY
       ========================= */
    SELECT JSON_ARRAY(
        JSON_OBJECT(
            'key', 'total',
            'title', 'Total Compliances',
            'value', FORMAT(totalCount, 0),
            'subtitle', 'All active requirements',
            'icon', 'Assessment',
            'color', '#2196f3',
            'bgColor', '#e3f2fd'
        ),
        JSON_OBJECT(
            'key', 'expiring',
            'title', 'Expiring Soon',
            'value', FORMAT(expiringCount, 0),
            'subtitle', CONCAT('Within ', p_due_days, ' days'),
            'icon', 'Schedule',
            'color', '#ff9800',
            'bgColor', '#fff3e0'
        ),
        JSON_OBJECT(
            'key', 'overdue',
            'title', 'Expired',
            'value', FORMAT(overdueCount, 0),
            'subtitle', 'Require immediate action',
            'icon', 'Error',
            'color', '#f44336',
            'bgColor', '#ffebee'
        )
    ) AS compliance_summary;

END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `compl_sp_get_compl_compliances_for_search` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `compl_sp_get_compl_compliances_for_search`(
    IN p_limit INT,
    IN p_offset INT,    
    IN p_search_text VARCHAR(255),
    IN p_user_email VARCHAR(50)
)
BEGIN	
    DECLARE v_search_escaped VARCHAR(255);
    DECLARE v_search_like VARCHAR(255);
    DECLARE v_use_fulltext BOOLEAN DEFAULT FALSE;	
    
    -- ── Escape search text & check fulltext ───────────────────────────────
    IF p_search_text IS NOT NULL AND p_search_text <> '' THEN
        SET v_search_like = p_search_text;
        SET v_search_like = REPLACE(v_search_like, '\\', '\\\\');
        SET v_search_like = REPLACE(v_search_like, '''', '''''');
        SET v_search_like = REPLACE(v_search_like, '%', '\\%');
        SET v_search_like = REPLACE(v_search_like, '_', '\\_');
        
        IF CHAR_LENGTH(TRIM(p_search_text)) > 3 
           AND p_search_text NOT REGEXP '[+\\-<>()~*"@%_]' THEN
            SET v_use_fulltext = TRUE;
            
            SET v_search_escaped = p_search_text;
            SET v_search_escaped = REPLACE(v_search_escaped, '\\', '\\\\');
            SET v_search_escaped = REPLACE(v_search_escaped, '''', '''''');
            SET v_search_escaped = REPLACE(v_search_escaped, '+', '\\+');
            SET v_search_escaped = REPLACE(v_search_escaped, '-', '\\-');
            SET v_search_escaped = REPLACE(v_search_escaped, '<', '\\<');
            SET v_search_escaped = REPLACE(v_search_escaped, '>', '\\>');
            SET v_search_escaped = REPLACE(v_search_escaped, '(', '\\(');
            SET v_search_escaped = REPLACE(v_search_escaped, ')', '\\)');
            SET v_search_escaped = REPLACE(v_search_escaped, '~', '\\~');
            SET v_search_escaped = REPLACE(v_search_escaped, '*', '\\*');
            SET v_search_escaped = REPLACE(v_search_escaped, '"', '\\"');
            SET v_search_escaped = REPLACE(v_search_escaped, '@', '\\@');
        END IF;
    END IF;     
    
    -- ── PART 1: Compliance (master đã có compliance) ──────────────────────
    SELECT 		
        'compliance'    AS type,
        c.Id,
        CONCAT(
				(
					SELECT GROUP_CONCAT(DISTINCT cm.Name ORDER BY cm.Name SEPARATOR ' / ')
					FROM compl_references cr
					INNER JOIN compl_masters cm ON cm.Id = cr.MasterId
					WHERE cr.ComplianceId = c.Id
				), ' ', c.Name, ' (', c.Code, ')')  AS title,     
        c.Description   AS description,
        c.CreatedDate,			
        -- ── lấy masterId ──────────────────────────────────────────────────────────
		(
        SELECT GROUP_CONCAT(DISTINCT cm.Id ORDER BY cm.Name SEPARATOR ',')
        FROM compl_references cr
        INNER JOIN compl_masters cm ON cm.Id = cr.MasterId
        WHERE cr.ComplianceId = c.Id
          -- Chỉ lấy master version mới nhất
          AND NOT EXISTS (
              SELECT 1 FROM compl_masters cm2
              WHERE cm2.Code = cm.Code AND cm2.VersionNo > cm.VersionNo
          )
		) AS masterId,

		(
			SELECT GROUP_CONCAT(DISTINCT cm.Code ORDER BY cm.Name SEPARATOR ',')
			FROM compl_references cr
			INNER JOIN compl_masters cm ON cm.Id = cr.MasterId
			WHERE cr.ComplianceId = c.Id
			  -- Chỉ lấy master version mới nhất
			  AND NOT EXISTS (
				  SELECT 1 FROM compl_masters cm2
				  WHERE cm2.Code = cm.Code AND cm2.VersionNo > cm.VersionNo
			  )
		) AS masterCode,
        
        -- Reference Types từ compl_master_conditions
        (
            SELECT GROUP_CONCAT(DISTINCT crt.Name ORDER BY crt.Name SEPARATOR ', ')
            FROM compl_references cr
            INNER JOIN compl_masters cm ON cm.Id = cr.MasterId
            INNER JOIN compl_master_conditions cmc ON cmc.MasterId = cm.Id
            INNER JOIN compl_reference_types crt ON crt.Id = cmc.RefTypeId
            WHERE cr.ComplianceId = c.Id
        ) AS referenceType,
        
        -- Exact score
        CASE 
            WHEN p_search_text IS NULL OR p_search_text = '' THEN 0
            WHEN c.Name        LIKE CONCAT('%', v_search_like, '%') THEN 100
            WHEN c.Code        LIKE CONCAT('%', v_search_like, '%') THEN 100
            WHEN c.Description LIKE CONCAT('%', v_search_like, '%') THEN 100
            WHEN EXISTS (
                SELECT 1
                FROM compl_references cr2
                INNER JOIN compl_masters cm2 ON cm2.Id = cr2.MasterId
                WHERE cr2.ComplianceId = c.Id
                  AND (
                      cm2.Code LIKE CONCAT('%', v_search_like, '%')
                      OR cm2.Name LIKE CONCAT('%', v_search_like, '%')
                  )
            ) THEN 80
            ELSE 0
        END AS exact_score,
        
        -- Relevance score (fulltext)
        CASE 
            WHEN v_use_fulltext THEN 
                MATCH(c.Name, c.Code, c.Description) AGAINST (v_search_escaped IN BOOLEAN MODE)
            ELSE 0
        END AS relevance_score
        
    FROM compl_compliances c
    WHERE 1=1
    
        -- Chỉ lấy version mới nhất theo Code
        AND NOT EXISTS (
            SELECT 1
            FROM compl_compliances c2
            WHERE c2.Code = c.Code
              AND c2.VersionNo > c.VersionNo
        )
    
        -- Search condition
        AND (
            p_search_text IS NULL 
            OR p_search_text = ''
            OR (
                v_use_fulltext = TRUE
                AND (
                    MATCH(c.Name, c.Code, c.Description) AGAINST (v_search_escaped IN BOOLEAN MODE)
                    OR c.Name        LIKE CONCAT('%', v_search_like, '%')
                    OR c.Code        LIKE CONCAT('%', v_search_like, '%')
                    OR c.Description LIKE CONCAT('%', v_search_like, '%')
                )
            )
            OR (
                v_use_fulltext = FALSE
                AND (
                    c.Name        LIKE CONCAT('%', v_search_like, '%')
                    OR c.Code        LIKE CONCAT('%', v_search_like, '%')
                    OR c.Description LIKE CONCAT('%', v_search_like, '%')
                )
            )
            OR EXISTS (
                SELECT 1
                FROM compl_references cr2
                INNER JOIN compl_masters cm2 ON cm2.Id = cr2.MasterId
                WHERE cr2.ComplianceId = c.Id
                  AND (
                      cm2.Code LIKE CONCAT('%', v_search_like, '%')
                      OR cm2.Name LIKE CONCAT('%', v_search_like, '%')
                  )
            )
        )
        
        -- User email filter
        AND (
            p_user_email IS NULL 
            OR p_user_email = ''
            OR c.CreatedBy = p_user_email
            OR EXISTS (
                SELECT 1 
                FROM compl_compliance_group_email ccge
                INNER JOIN compl_group_email_detail cged 
                    ON cged.GroupEmailId = ccge.GroupEmailId
                WHERE ccge.ComplianceId = c.Id
                  AND cged.ResponseEmail = p_user_email
                  AND ccge.GroupType IN (1, 3)
                  AND cged.IsActive = TRUE
            )
        )

    UNION ALL

    -- ── PART 2: Master chưa có compliance nào ────────────────────────────
    SELECT
        'master'        AS type,
        m.Id,
        CONCAT(m.Name, ' (', m.Code, ')') AS title,
        m.Description   AS description,
        m.CreatedDate,		
        CAST(m.Id AS CHAR)  AS masterId,
		m.Code              AS masterCode,
        
        -- Reference Types từ conditions của master
        (
            SELECT GROUP_CONCAT(DISTINCT crt.Name ORDER BY crt.Name SEPARATOR ', ')
            FROM compl_master_conditions cmc
            INNER JOIN compl_reference_types crt ON crt.Id = cmc.RefTypeId
            WHERE cmc.MasterId = m.Id
        ) AS referenceType,
        
        -- Exact score
        CASE
            WHEN p_search_text IS NULL OR p_search_text = '' THEN 0
            WHEN m.Name LIKE CONCAT('%', v_search_like, '%') THEN 100
            WHEN m.Code LIKE CONCAT('%', v_search_like, '%') THEN 100
            ELSE 0
        END AS exact_score,
        
        0 AS relevance_score

    FROM compl_masters m
    WHERE 1=1
    
        -- Chỉ lấy master chưa có compliance nào
        AND NOT EXISTS (
            SELECT 1
            FROM compl_references cr
            WHERE cr.MasterId = m.Id
        )
        
        -- Search condition
        AND (
            p_search_text IS NULL
            OR p_search_text = ''
            OR m.Name LIKE CONCAT('%', v_search_like, '%')
            OR m.Code LIKE CONCAT('%', v_search_like, '%')
        )
        
        -- User email filter
        AND (
            p_user_email IS NULL
            OR p_user_email = ''
            OR m.CreatedBy = p_user_email
        )
        
        -- Chỉ lấy master version mới nhất
		AND NOT EXISTS (
			SELECT 1
			FROM compl_masters m2
			WHERE m2.Code = m.Code
			  AND m2.VersionNo > m.VersionNo
		)

		-- Chỉ lấy master chưa có compliance nào (đã có sẵn)
		AND NOT EXISTS (
			SELECT 1
			FROM compl_references cr
			WHERE cr.MasterId = m.Id
		)

    -- ── Order & Paging (áp dụng cho toàn bộ UNION) ───────────────────────
    ORDER BY 
        exact_score     DESC,
        CASE WHEN v_use_fulltext THEN relevance_score ELSE 0 END DESC,
        CreatedDate     DESC
    LIMIT p_limit OFFSET p_offset;
    
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `compl_sp_get_compl_compliances_for_search_count` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `compl_sp_get_compl_compliances_for_search_count`(
    IN p_search_text VARCHAR(255),
    IN p_user_email VARCHAR(50)
)
BEGIN	
    DECLARE v_search_escaped VARCHAR(255);
    DECLARE v_search_like VARCHAR(255);
    DECLARE v_use_fulltext BOOLEAN DEFAULT FALSE;	
    
    -- ── Escape search text & check fulltext ───────────────────────────────
    IF p_search_text IS NOT NULL AND p_search_text <> '' THEN
        SET v_search_like = p_search_text;
        SET v_search_like = REPLACE(v_search_like, '\\', '\\\\');
        SET v_search_like = REPLACE(v_search_like, '''', '''''');
        SET v_search_like = REPLACE(v_search_like, '%', '\\%');
        SET v_search_like = REPLACE(v_search_like, '_', '\\_');
        
        IF CHAR_LENGTH(TRIM(p_search_text)) > 3 
           AND p_search_text NOT REGEXP '[+\\-<>()~*"@%_]' THEN
            SET v_use_fulltext = TRUE;
            
            SET v_search_escaped = p_search_text;
            SET v_search_escaped = REPLACE(v_search_escaped, '\\', '\\\\');
            SET v_search_escaped = REPLACE(v_search_escaped, '''', '''''');
            SET v_search_escaped = REPLACE(v_search_escaped, '+', '\\+');
            SET v_search_escaped = REPLACE(v_search_escaped, '-', '\\-');
            SET v_search_escaped = REPLACE(v_search_escaped, '<', '\\<');
            SET v_search_escaped = REPLACE(v_search_escaped, '>', '\\>');
            SET v_search_escaped = REPLACE(v_search_escaped, '(', '\\(');
            SET v_search_escaped = REPLACE(v_search_escaped, ')', '\\)');
            SET v_search_escaped = REPLACE(v_search_escaped, '~', '\\~');
            SET v_search_escaped = REPLACE(v_search_escaped, '*', '\\*');
            SET v_search_escaped = REPLACE(v_search_escaped, '"', '\\"');
            SET v_search_escaped = REPLACE(v_search_escaped, '@', '\\@');
        END IF;
    END IF;

    SELECT 
        SUM(cnt) AS total
    FROM (

        -- ── PART 1: Compliance ────────────────────────────────────────────
        SELECT COUNT(*) AS cnt
        FROM compl_compliances c
        WHERE 1=1
        
            AND NOT EXISTS (
                SELECT 1
                FROM compl_compliances c2
                WHERE c2.Code = c.Code
                  AND c2.VersionNo > c.VersionNo
            )
            
            AND (
                p_search_text IS NULL 
                OR p_search_text = ''
                OR (
                    v_use_fulltext = TRUE
                    AND (
                        MATCH(c.Name, c.Code, c.Description) AGAINST (v_search_escaped IN BOOLEAN MODE)
                        OR c.Name        LIKE CONCAT('%', v_search_like, '%')
                        OR c.Code        LIKE CONCAT('%', v_search_like, '%')
                        OR c.Description LIKE CONCAT('%', v_search_like, '%')
                    )
                )
                OR (
                    v_use_fulltext = FALSE
                    AND (
                        c.Name        LIKE CONCAT('%', v_search_like, '%')
                        OR c.Code        LIKE CONCAT('%', v_search_like, '%')
                        OR c.Description LIKE CONCAT('%', v_search_like, '%')
                    )
                )
                OR EXISTS (
                    SELECT 1
                    FROM compl_references cr2
                    INNER JOIN compl_masters cm2 ON cm2.Id = cr2.MasterId
                    WHERE cr2.ComplianceId = c.Id
                      AND (
                          cm2.Code LIKE CONCAT('%', v_search_like, '%')
                          OR cm2.Name LIKE CONCAT('%', v_search_like, '%')
                      )
                )
            )
            
            AND (
                p_user_email IS NULL 
                OR p_user_email = ''
                OR c.CreatedBy = p_user_email
                OR EXISTS (
                    SELECT 1 
                    FROM compl_compliance_group_email ccge
                    INNER JOIN compl_group_email_detail cged 
                        ON cged.GroupEmailId = ccge.GroupEmailId
                    WHERE ccge.ComplianceId = c.Id
                      AND cged.ResponseEmail = p_user_email
                      AND ccge.GroupType IN (1, 3)
                      AND cged.IsActive = TRUE
                )
            )

        UNION ALL

        -- ── PART 2: Master chưa có compliance ────────────────────────────
        SELECT COUNT(*) AS cnt
        FROM compl_masters m
        WHERE 1=1
        
            AND NOT EXISTS (
                SELECT 1
                FROM compl_references cr
                WHERE cr.MasterId = m.Id
            )
            
            AND (
                p_search_text IS NULL
                OR p_search_text = ''
                OR m.Name LIKE CONCAT('%', v_search_like, '%')
                OR m.Code LIKE CONCAT('%', v_search_like, '%')
            )
            
            AND (
                p_user_email IS NULL
                OR p_user_email = ''
                OR m.CreatedBy = p_user_email
            )

    ) AS combined;

END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `compl_sp_get_compl_compliances_paging` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `compl_sp_get_compl_compliances_paging`(
    IN p_limit INT,
    IN p_offset INT,
    IN p_order_column VARCHAR(50),
    IN p_order_direction VARCHAR(4),
    IN p_search_text VARCHAR(255),  
    IN p_due_days INT,
    IN p_user_email VARCHAR(50),
    IN p_ref_type_id BIGINT,        
    IN p_ref_type_value VARCHAR(255),
    IN p_created_by VARCHAR(50)
)
BEGIN
    DECLARE v_search_escaped VARCHAR(255);
    DECLARE v_use_fulltext BOOLEAN DEFAULT FALSE;
    
    -- Validate và sanitize order column (prevent SQL injection)
    IF p_order_column NOT IN ('Id', 'Name', 'Code', 'ValidFrom', 'ValidTo', 'CreatedDate', 'NumDayAlert') THEN
        SET p_order_column = 'Id';
    END IF;
    
    -- Validate order direction
    IF UPPER(p_order_direction) NOT IN ('ASC', 'DESC') THEN
        SET p_order_direction = 'DESC';
    END IF;
    
    -- Escape search text một lần duy nhất
    IF p_search_text IS NOT NULL AND p_search_text <> '' THEN
        SET v_search_escaped = p_search_text;
        -- Escape cho LIKE pattern
        SET v_search_escaped = REPLACE(v_search_escaped, '\\', '\\\\');
        SET v_search_escaped = REPLACE(v_search_escaped, '''', '''''');
        SET v_search_escaped = REPLACE(v_search_escaped, '%', '\\%');
        SET v_search_escaped = REPLACE(v_search_escaped, '_', '\\_');
        
        -- Check fulltext (>= 3 chars)
        IF CHAR_LENGTH(TRIM(p_search_text)) >= 3 THEN
            SET v_use_fulltext = TRUE;
            -- Escape cho fulltext search
            SET v_search_escaped = REPLACE(v_search_escaped, '+', '\\+');
            SET v_search_escaped = REPLACE(v_search_escaped, '-', '\\-');
            SET v_search_escaped = REPLACE(v_search_escaped, '<', '\\<');
            SET v_search_escaped = REPLACE(v_search_escaped, '>', '\\>');
            SET v_search_escaped = REPLACE(v_search_escaped, '(', '\\(');
            SET v_search_escaped = REPLACE(v_search_escaped, ')', '\\)');
            SET v_search_escaped = REPLACE(v_search_escaped, '~', '\\~');
            SET v_search_escaped = REPLACE(v_search_escaped, '*', '\\*');
            SET v_search_escaped = REPLACE(v_search_escaped, '"', '\\"');
            SET v_search_escaped = REPLACE(v_search_escaped, '@', '\\@');
        END IF;
    END IF;
	
    WITH
    /* =======================
       LATEST VERSIONS
    ======================= */
    LatestComplianceVersions AS (
        -- Lấy VersionNo cao nhất cho mỗi Code
        SELECT Code, MAX(VersionNo) AS MaxVersion
        FROM compl_compliances
        GROUP BY Code
    ),
    /* =======================
       LATEST MASTER VERSIONS
    ======================= */
    LatestMasterVersions AS (
        -- Lấy VersionNo cao nhất cho mỗi Code của Master
        SELECT Code, MAX(VersionNo) AS MaxVersion
        FROM compl_masters
        GROUP BY Code
    ),
    /* =======================
       GROUP IDS
    ======================= */
    cte_group_ids AS (
        SELECT
            ComplianceId,
            GROUP_CONCAT(
                DISTINCT CASE WHEN GroupType = 2 THEN GroupEmailId END
                ORDER BY GroupEmailId SEPARATOR ','
            ) AS AlertGroupIds,
            GROUP_CONCAT(
                DISTINCT CASE WHEN GroupType = 1 THEN GroupEmailId END
                ORDER BY GroupEmailId SEPARATOR ','
            ) AS RespGroupIds
        FROM compl_compliance_group_email
        GROUP BY ComplianceId
    ),
    -- CTE để aggregate email groups theo ComplianceId
    compliance_emails AS (
        SELECT 
            ccge.ComplianceId,
            -- GroupType = 1: ResponsibleFor
            GROUP_CONCAT(DISTINCT CASE WHEN ccge.GroupType = 1 THEN cged.ResponseEmail END 
                ORDER BY CASE WHEN ccge.GroupType = 1 THEN cged.ResponseEmail END 
                SEPARATOR ',') AS ResponsibleFor,
            -- GroupType = 2: AlertFor
            GROUP_CONCAT(DISTINCT CASE WHEN ccge.GroupType = 2 THEN cged.ResponseEmail END 
                ORDER BY CASE WHEN ccge.GroupType = 2 THEN cged.ResponseEmail END 
                SEPARATOR ',') AS AlertFor,
            -- GroupType = 3: ResponsibleForAddition
            GROUP_CONCAT(DISTINCT CASE WHEN ccge.GroupType = 3 THEN cged.ResponseEmail END 
                ORDER BY CASE WHEN ccge.GroupType = 3 THEN cged.ResponseEmail END 
                SEPARATOR ',') AS ResponsibleForAddition,
            -- GroupType = 4: AlertForAddition
            GROUP_CONCAT(DISTINCT CASE WHEN ccge.GroupType = 4 THEN cged.ResponseEmail END 
                ORDER BY CASE WHEN ccge.GroupType = 4 THEN cged.ResponseEmail END 
                SEPARATOR ',') AS AlertForAddition
        FROM compl_compliance_group_email ccge
        LEFT JOIN compl_group_email_detail cged ON cged.GroupEmailId = ccge.GroupEmailId AND cged.IsActive = TRUE
        GROUP BY ccge.ComplianceId
    ),
    -- CTE để filter compliances
    filtered_compliances AS (
        SELECT DISTINCT cd.Id
        FROM compl_compliances cd
        INNER JOIN LatestComplianceVersions lcv 
            ON cd.Code = lcv.Code AND cd.VersionNo = lcv.MaxVersion
        LEFT JOIN compl_compliance_group_email ccge ON ccge.ComplianceId = cd.Id
        LEFT JOIN compl_group_email_detail cged ON cged.GroupEmailId = ccge.GroupEmailId AND cged.IsActive = TRUE
        LEFT JOIN compl_references cr ON cr.ComplianceId = cd.Id
        INNER JOIN compl_masters cm ON cm.Id = cr.MasterId
        INNER JOIN LatestMasterVersions lmv 
            ON cm.Code = lmv.Code AND cm.VersionNo = lmv.MaxVersion
        LEFT JOIN compl_master_conditions cmc ON cmc.MasterId = cm.Id
        LEFT JOIN compl_master_condition_values cmcv ON cmcv.ConditionId = cmc.Id
        WHERE 1=1
            -- Search condition (Compliance + Master)
			AND (
				p_search_text IS NULL OR p_search_text = ''
				OR (
					v_use_fulltext = TRUE 
					AND (
						MATCH(cd.Name, cd.Code, cd.Description) 
							AGAINST (v_search_escaped IN BOOLEAN MODE)
						OR MATCH(cm.Name, cm.Code)
							AGAINST (v_search_escaped IN BOOLEAN MODE)
						-- THÊM LIKE fallback để catch "TB117" khi search "117"
						OR cd.Code LIKE CONCAT('%', v_search_escaped, '%')
						OR cd.Name LIKE CONCAT('%', v_search_escaped, '%')
						OR cd.Description LIKE CONCAT('%', v_search_escaped, '%')
						OR cm.Code LIKE CONCAT('%', v_search_escaped, '%')
						OR cm.Name LIKE CONCAT('%', v_search_escaped, '%')
					)
				)
				OR (
					v_use_fulltext = FALSE
					AND (
						cd.Code LIKE CONCAT('%', v_search_escaped, '%')
						OR cd.Name LIKE CONCAT('%', v_search_escaped, '%')
						OR cd.Description LIKE CONCAT('%', v_search_escaped, '%')
						OR cm.Code LIKE CONCAT('%', v_search_escaped, '%')
						OR cm.Name LIKE CONCAT('%', v_search_escaped, '%')
					)
				)
			)
            -- Due days filter
            -- Điều kiện 1: Loại expired khi p_due_days > 0 (độc lập với các filter khác)
			AND (
				p_due_days IS NULL
				OR p_due_days <= 0
				OR cd.ValidTo IS NULL
				OR cd.ValidTo >= UTC_TIMESTAMP()
			)

			-- Điều kiện 2: Filter khoảng ngày
			AND (
				p_due_days IS NULL
				OR (p_due_days <= 0 
					AND cd.ValidTo IS NOT NULL 
					AND cd.ValidTo < UTC_TIMESTAMP())
				OR (p_due_days > 0 
					AND cd.ValidTo IS NOT NULL 
					AND cd.ValidTo <= DATE_ADD(UTC_TIMESTAMP(), INTERVAL p_due_days DAY))
			)            
            -- User email filter
            AND (
                p_user_email IS NULL 
                OR p_user_email = ''
                OR cd.CreatedBy = p_user_email
                OR EXISTS (
                    SELECT 1 
                    FROM compl_compliance_group_email cmge
                    INNER JOIN compl_group_email_detail cged 
                        ON cged.GroupEmailId = cmge.GroupEmailId
                    WHERE cmge.ComplianceId = cd.Id
                      AND cmge.GroupType = 1
                      AND cged.IsActive = TRUE
                      AND cged.ResponseEmail = p_user_email
                )
            )            
            -- Filter by reference type and value
            AND (
                (p_ref_type_id IS NULL AND p_ref_type_value IS NULL)
                OR (
                    cmc.RefTypeId = p_ref_type_id
                    AND (p_ref_type_value IS NULL OR cmcv.RefTypeValue = p_ref_type_value)
                )
                OR (
					cr.RefTypeId = p_ref_type_id
                    AND (p_ref_type_value IS NULL OR cr.RefTypeValue = p_ref_type_value)
                )
            )
			-- Filter CreatdBy
            AND (cd.CreatedBy like concat('%',p_created_by,'%')
				OR p_created_by IS NULL 
                OR p_created_by = '')
    )
    SELECT 
		-- Master Code và Name
        cm.Id AS MasterId,
        cm.Code AS MasterCode,
        cm.Name AS MasterName,
        cm.VersionNo as MasterVersionNo,
        cm.ValidFrom AS MasterValidFrom,
        cm.ValidTo AS MasterValidTo,
        cm.IsIndividual AS MasterIsIndividual,
        
        cd.Id,
        cd.Name,
        cd.Code,
        cd.NumDayAlert,
        cd.ValidFrom,
        cd.ValidTo,
        cd.FileId,
        cd.Description,
        cd.CreatedDate,
        cd.CreatedBy,
        cd.VersionNo,
        cd.ReplacedById,
                
        -- Applied RefTypeId
		(
			SELECT crt2.Id
			FROM compl_references cr2
			INNER JOIN compl_reference_types crt2 ON crt2.Id = cr2.RefTypeId
			WHERE cr2.ComplianceId = cd.Id
			  AND cr2.RefTypeValue IS NOT NULL
			  AND (cr2.ValidTo IS NULL OR cr2.ValidTo >= NOW())
			LIMIT 1
		) AS RefTypeId,
		-- Applied RefTypeCode
		(
			SELECT crt2.Code
			FROM compl_references cr2
			INNER JOIN compl_reference_types crt2 ON crt2.Id = cr2.RefTypeId
			WHERE cr2.ComplianceId = cd.Id
			  AND cr2.RefTypeValue IS NOT NULL
			  AND (cr2.ValidTo IS NULL OR cr2.ValidTo >= NOW())
			LIMIT 1
		) AS RefTypeCode,
		-- Applied RefTypeValue
		(
			SELECT cr2.RefTypeValue
			FROM compl_references cr2
			WHERE cr2.ComplianceId = cd.Id
			  AND cr2.RefTypeValue IS NOT NULL
			  AND (cr2.ValidTo IS NULL OR cr2.ValidTo >= NOW())
			LIMIT 1
		) AS RefTypeValue,
        
        -- Applied RefTypeValues JSON - Format JSON cho frontend
        (
            SELECT JSON_ARRAYAGG(
                JSON_OBJECT(
                    'refTypeId', cr2.RefTypeId,
                    'refTypeCode', crt2.Code,
                    'refTypeName', crt2.Name,
                    'refTypeValue', cr2.RefTypeValue,
                    'validFrom', cr2.ValidFrom,
                    'validTo', cr2.ValidTo
                )
            )
            FROM compl_references cr2
            LEFT JOIN compl_reference_types crt2 ON crt2.Id = cr2.RefTypeId
            WHERE cr2.ComplianceId = cd.Id
              AND cr2.RefTypeValue IS NOT NULL
              AND (cr2.ValidTo IS NULL OR cr2.ValidTo >= NOW())
        ) AS AppliedRefTypeValuesJson,
        
        -- Alert Group IDs (GroupType = 2)
        (
            SELECT GROUP_CONCAT(DISTINCT GroupEmailId ORDER BY GroupEmailId SEPARATOR ',')
            FROM compl_compliance_group_email 
            WHERE ComplianceId = cd.Id AND GroupType = 2
        ) AS AlertGroupIds,
        
        -- Responsible Group IDs (GroupType = 1)
        (
            SELECT GROUP_CONCAT(DISTINCT GroupEmailId ORDER BY GroupEmailId SEPARATOR ',')
            FROM compl_compliance_group_email 
            WHERE ComplianceId = cd.Id AND GroupType = 1
        ) AS RespGroupIds,
        
        -- Alert Groups JSON
        (
            SELECT JSON_ARRAYAGG(
                JSON_OBJECT(
                    'groupName', ge.Name,
                    'emails', (
                        SELECT JSON_ARRAYAGG(cged.ResponseEmail)
                        FROM compl_group_email_detail cged
                        WHERE cged.GroupEmailId = ge.Id AND cged.IsActive = TRUE
                    )
                )
            )
            FROM compl_compliance_group_email ccge
            INNER JOIN compl_group_email ge ON ccge.GroupEmailId = ge.Id
            WHERE ccge.ComplianceId = cd.Id AND ccge.GroupType = 2
        ) AS AlertGroupsJson,
        
        -- Responsible Groups JSON
        (
            SELECT JSON_ARRAYAGG(
                JSON_OBJECT(
                    'groupName', ge.Name,
                    'emails', (
                        SELECT JSON_ARRAYAGG(cged.ResponseEmail)
                        FROM compl_group_email_detail cged
                        WHERE cged.GroupEmailId = ge.Id AND cged.IsActive = TRUE
                    )
                )
            )
            FROM compl_compliance_group_email ccge
            INNER JOIN compl_group_email ge ON ccge.GroupEmailId = ge.Id
            WHERE ccge.ComplianceId = cd.Id AND ccge.GroupType = 1
        ) AS ResponsibleGroupsJson,
        
        /*
        -- Conditions JSON
        (
			SELECT JSON_ARRAYAGG(
                    JSON_OBJECT(
                        "id", cmc.Id,
                        "logical", cmc.Logical,
                        "operator", cmc.Operator,
                        "complType", cmc.ComplType,
                        "refTypeId", cmc.RefTypeId,
                        "logicalName", CASE cmc.Logical WHEN 1 THEN "AND" WHEN 2 THEN "OR" ELSE "UNKNOWN" END,
                        "refTypeCode", crt.Code,
                        "refTypeName", crt.Name,
                        "conditionValues", (
                            SELECT JSON_ARRAYAGG(
                                JSON_OBJECT(
                                    "id", cmcv.Id,
                                    "ConditionId", cmcv.ConditionId,
                                    "refTypeValue", cmcv.RefTypeValue,
                                    "refTypeValueDisplay", cmcv.RefTypeValue,
                                    "status", CASE 
										WHEN EXISTS (
											SELECT 1
											FROM compl_references cr
											WHERE cr.MasterId = cmc.MasterId
											  AND cr.RefTypeId = cmc.RefTypeId
											  AND cr.RefTypeValue = cmcv.RefTypeValue
											  AND (cr.ValidTo IS NULL OR cr.ValidTo >= NOW())
										) THEN "OK"
										ELSE "Missing"
									END
                                )
                            )
                            FROM compl_master_condition_values cmcv
                            WHERE cmcv.ConditionId = cmc.Id
                        )
                    )
                )
                FROM compl_master_conditions cmc
                LEFT JOIN compl_reference_types crt ON crt.Id = cmc.RefTypeId
                WHERE cmc.MasterId = cm.Id
            ) AS ConditionsJson,
		*/
        NULL AS ConditionsJson,
        -- Compliance Emails từ CTE
        ce.ResponsibleFor,
        ce.AlertFor,
        ce.ResponsibleForAddition,
        ce.AlertForAddition,
        
        gi.AlertGroupIds,
        gi.RespGroupIds,
        
        -- Relevance score for fulltext search
        CASE 
            WHEN v_use_fulltext THEN 
                MATCH(cd.Name, cd.Code, cd.Description) AGAINST (v_search_escaped IN BOOLEAN MODE)
            ELSE 0
        END AS relevance_score,
        
        sf.Name as FileName,
        CONCAT(ROUND(sf.Size / (1024 * 1024), 1), ' MB') AS FileSize
        
    FROM compl_compliances cd
    INNER JOIN filtered_compliances fc ON fc.Id = cd.Id
    LEFT JOIN compl_references cr ON cr.ComplianceId = cd.Id
    INNER JOIN compl_masters cm ON cm.Id = cr.MasterId
    INNER JOIN LatestMasterVersions lmv 
        ON cm.Code = lmv.Code AND cm.VersionNo = lmv.MaxVersion
    LEFT JOIN compliance_emails ce ON ce.ComplianceId = cd.Id
    LEFT JOIN compl_sharepoint_files sf ON sf.FileId = cd.FileId
    LEFT JOIN cte_group_ids gi
        ON gi.ComplianceId = cd.Id
    ORDER BY 
        CASE WHEN v_use_fulltext THEN relevance_score ELSE NULL END DESC,
        CASE WHEN p_order_column = 'Id' AND p_order_direction = 'ASC' THEN cd.Id END ASC,
        CASE WHEN p_order_column = 'Id' AND p_order_direction = 'DESC' THEN cd.Id END DESC,
        CASE WHEN p_order_column = 'Name' AND p_order_direction = 'ASC' THEN cd.Name END ASC,
        CASE WHEN p_order_column = 'Name' AND p_order_direction = 'DESC' THEN cd.Name END DESC,
        CASE WHEN p_order_column = 'Code' AND p_order_direction = 'ASC' THEN cd.Code END ASC,
        CASE WHEN p_order_column = 'Code' AND p_order_direction = 'DESC' THEN cd.Code END DESC,
        CASE WHEN p_order_column = 'ValidFrom' AND p_order_direction = 'ASC' THEN cd.ValidFrom END ASC,
        CASE WHEN p_order_column = 'ValidFrom' AND p_order_direction = 'DESC' THEN cd.ValidFrom END DESC,
        CASE WHEN p_order_column = 'ValidTo' AND p_order_direction = 'ASC' THEN cd.ValidTo END ASC,
        CASE WHEN p_order_column = 'ValidTo' AND p_order_direction = 'DESC' THEN cd.ValidTo END DESC,
        CASE WHEN p_order_column = 'CreatedDate' AND p_order_direction = 'ASC' THEN cd.CreatedDate END ASC,
        CASE WHEN p_order_column = 'CreatedDate' AND p_order_direction = 'DESC' THEN cd.CreatedDate END DESC,
        cd.Id DESC
    LIMIT p_limit OFFSET p_offset;
    
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `compl_sp_get_compl_compliances_paging_count` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `compl_sp_get_compl_compliances_paging_count`(
    IN p_search_text VARCHAR(255),  
    IN p_due_days INT,
    IN p_user_email VARCHAR(50),
    IN p_ref_type_id BIGINT,        
    IN p_ref_type_value VARCHAR(255),
    IN p_created_by VARCHAR(50)
)
BEGIN
    DECLARE v_search_escaped VARCHAR(255);
    DECLARE v_use_fulltext BOOLEAN DEFAULT FALSE;
    
    -- Escape search text một lần duy nhất
    IF p_search_text IS NOT NULL AND p_search_text <> '' THEN
        SET v_search_escaped = p_search_text;
        -- Escape cho LIKE pattern
        SET v_search_escaped = REPLACE(v_search_escaped, '\\', '\\\\');
        SET v_search_escaped = REPLACE(v_search_escaped, '''', '''''');
        SET v_search_escaped = REPLACE(v_search_escaped, '%', '\\%');
        SET v_search_escaped = REPLACE(v_search_escaped, '_', '\\_');
        
        -- Check fulltext (>= 3 chars)
        IF CHAR_LENGTH(TRIM(p_search_text)) >= 3 THEN
            SET v_use_fulltext = TRUE;
            -- Escape cho fulltext search
            SET v_search_escaped = REPLACE(v_search_escaped, '+', '\\+');
            SET v_search_escaped = REPLACE(v_search_escaped, '-', '\\-');
            SET v_search_escaped = REPLACE(v_search_escaped, '<', '\\<');
            SET v_search_escaped = REPLACE(v_search_escaped, '>', '\\>');
            SET v_search_escaped = REPLACE(v_search_escaped, '(', '\\(');
            SET v_search_escaped = REPLACE(v_search_escaped, ')', '\\)');
            SET v_search_escaped = REPLACE(v_search_escaped, '~', '\\~');
            SET v_search_escaped = REPLACE(v_search_escaped, '*', '\\*');
            SET v_search_escaped = REPLACE(v_search_escaped, '"', '\\"');
            SET v_search_escaped = REPLACE(v_search_escaped, '@', '\\@');
        END IF;
    END IF;
    
    -- Count query - đếm số row thực tế sẽ trả về trong paging query
    WITH 
    /* =======================
       LATEST VERSIONS
    ======================= */
    LatestComplianceVersions AS (
        -- Lấy VersionNo cao nhất cho mỗi Code
        SELECT Code, MAX(VersionNo) AS MaxVersion
        FROM compl_compliances
        GROUP BY Code
    ),
    /* =======================
       LATEST MASTER VERSIONS
    ======================= */
    LatestMasterVersions AS (
        -- Lấy VersionNo cao nhất cho mỗi Code của Master
        SELECT Code, MAX(VersionNo) AS MaxVersion
        FROM compl_masters
        GROUP BY Code
    ),
    filtered_compliances AS (
        SELECT DISTINCT cd.Id
        FROM compl_compliances cd
        INNER JOIN LatestComplianceVersions lcv 
            ON cd.Code = lcv.Code AND cd.VersionNo = lcv.MaxVersion
        LEFT JOIN compl_compliance_group_email ccge ON ccge.ComplianceId = cd.Id
        LEFT JOIN compl_group_email_detail cged ON cged.GroupEmailId = ccge.GroupEmailId AND cged.IsActive = TRUE
        LEFT JOIN compl_references cr ON cr.ComplianceId = cd.Id
        INNER JOIN compl_masters cm ON cm.Id = cr.MasterId
        INNER JOIN LatestMasterVersions lmv 
            ON cm.Code = lmv.Code AND cm.VersionNo = lmv.MaxVersion
        LEFT JOIN compl_master_conditions cmc ON cmc.MasterId = cm.Id
        LEFT JOIN compl_master_condition_values cmcv ON cmcv.ConditionId = cmc.Id
        WHERE 1=1
            -- Search condition (Compliance + Master)
			AND (
				p_search_text IS NULL OR p_search_text = ''
				OR (
					v_use_fulltext = TRUE 
					AND (
						MATCH(cd.Name, cd.Code, cd.Description) 
							AGAINST (v_search_escaped IN BOOLEAN MODE)
						OR MATCH(cm.Name, cm.Code)
							AGAINST (v_search_escaped IN BOOLEAN MODE)
						-- ✅ THÊM LIKE fallback để catch "TB117" khi search "117"
						OR cd.Code LIKE CONCAT('%', v_search_escaped, '%')
						OR cd.Name LIKE CONCAT('%', v_search_escaped, '%')
						OR cd.Description LIKE CONCAT('%', v_search_escaped, '%')
						OR cm.Code LIKE CONCAT('%', v_search_escaped, '%')
						OR cm.Name LIKE CONCAT('%', v_search_escaped, '%')
					)
				)
				OR (
					v_use_fulltext = FALSE
					AND (
						cd.Code LIKE CONCAT('%', v_search_escaped, '%')
						OR cd.Name LIKE CONCAT('%', v_search_escaped, '%')
						OR cd.Description LIKE CONCAT('%', v_search_escaped, '%')
						OR cm.Code LIKE CONCAT('%', v_search_escaped, '%')
						OR cm.Name LIKE CONCAT('%', v_search_escaped, '%')
					)
				)
			)
            -- Due days filter
            -- Điều kiện 1: Loại expired khi p_due_days > 0 (độc lập với các filter khác)
			AND (
				p_due_days IS NULL
				OR p_due_days <= 0
				OR cd.ValidTo IS NULL
				OR cd.ValidTo >= UTC_TIMESTAMP()
			)
			-- Điều kiện 2: Filter khoảng ngày
			AND (
				p_due_days IS NULL
				OR (p_due_days <= 0 
					AND cd.ValidTo IS NOT NULL 
					AND cd.ValidTo < UTC_TIMESTAMP())
				OR (p_due_days > 0 
					AND cd.ValidTo IS NOT NULL 
					AND cd.ValidTo <= DATE_ADD(UTC_TIMESTAMP(), INTERVAL p_due_days DAY))
			)
            -- User email filter
            AND (
                p_user_email IS NULL 
                OR p_user_email = ''
                OR cd.CreatedBy = p_user_email
                OR EXISTS (
                    SELECT 1 
                    FROM compl_compliance_group_email cmge
                    INNER JOIN compl_group_email_detail cged 
                        ON cged.GroupEmailId = cmge.GroupEmailId
                    WHERE cmge.ComplianceId = cd.Id
                      AND cmge.GroupType = 1
                      AND cged.IsActive = TRUE
                      AND cged.ResponseEmail = p_user_email
                )
            )
            -- Filter by reference type and value
            AND (
                (p_ref_type_id IS NULL AND p_ref_type_value IS NULL)
                OR (
                    cmc.RefTypeId = p_ref_type_id
                    AND (p_ref_type_value IS NULL OR cmcv.RefTypeValue = p_ref_type_value)
                )
                OR (
					cr.RefTypeId = p_ref_type_id
                    AND (p_ref_type_value IS NULL OR cr.RefTypeValue = p_ref_type_value)
                )
            )
			-- Filter CreatdBy
            AND (cd.CreatedBy like concat('%',p_created_by,'%')
				OR p_created_by IS NULL 
                OR p_created_by = '')
    )
    -- Count số rows thực tế sau khi JOIN với các bảng khác
    SELECT COUNT(*) AS TotalCount
    FROM (
        SELECT cd.Id, cm.Id AS MasterId
        FROM compl_compliances cd
        INNER JOIN filtered_compliances fc ON fc.Id = cd.Id
        LEFT JOIN compl_references cr ON cr.ComplianceId = cd.Id
        INNER JOIN compl_masters cm ON cm.Id = cr.MasterId
        INNER JOIN LatestMasterVersions lmv 
            ON cm.Code = lmv.Code AND cm.VersionNo = lmv.MaxVersion
        GROUP BY cd.Id, cm.Id
    ) AS final_result;
    
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `compl_sp_get_compl_compliances_paging_masters_json` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `compl_sp_get_compl_compliances_paging_masters_json`(
    IN p_limit INT,
    IN p_offset INT,
    IN p_order_column VARCHAR(50),
    IN p_order_direction VARCHAR(4),
    IN p_search_text VARCHAR(255),  
    IN p_due_days INT,
    IN p_user_email VARCHAR(50)
)
BEGIN
    DECLARE v_search_escaped VARCHAR(255);
    DECLARE v_use_fulltext BOOLEAN DEFAULT FALSE;
    
    -- Validate và sanitize order column (prevent SQL injection)
    IF p_order_column NOT IN ('Id', 'Name', 'Code', 'ValidFrom', 'ValidTo', 'CreatedDate', 'NumDayAlert') THEN
        SET p_order_column = 'Id';
    END IF;
    
    -- Validate order direction
    IF UPPER(p_order_direction) NOT IN ('ASC', 'DESC') THEN
        SET p_order_direction = 'DESC';
    END IF;
    
    -- Escape search text một lần duy nhất
    IF p_search_text IS NOT NULL AND p_search_text <> '' THEN
        SET v_search_escaped = p_search_text;
        -- Escape cho LIKE pattern
        SET v_search_escaped = REPLACE(v_search_escaped, '\\', '\\\\');
        SET v_search_escaped = REPLACE(v_search_escaped, '''', '''''');
        SET v_search_escaped = REPLACE(v_search_escaped, '%', '\\%');
        SET v_search_escaped = REPLACE(v_search_escaped, '_', '\\_');
        
        -- Check fulltext (>= 3 chars)
        IF CHAR_LENGTH(TRIM(p_search_text)) >= 3 THEN
            SET v_use_fulltext = TRUE;
            -- Escape cho fulltext search
            SET v_search_escaped = REPLACE(v_search_escaped, '+', '\\+');
            SET v_search_escaped = REPLACE(v_search_escaped, '-', '\\-');
            SET v_search_escaped = REPLACE(v_search_escaped, '<', '\\<');
            SET v_search_escaped = REPLACE(v_search_escaped, '>', '\\>');
            SET v_search_escaped = REPLACE(v_search_escaped, '(', '\\(');
            SET v_search_escaped = REPLACE(v_search_escaped, ')', '\\)');
            SET v_search_escaped = REPLACE(v_search_escaped, '~', '\\~');
            SET v_search_escaped = REPLACE(v_search_escaped, '*', '\\*');
            SET v_search_escaped = REPLACE(v_search_escaped, '"', '\\"');
            SET v_search_escaped = REPLACE(v_search_escaped, '@', '\\@');
        END IF;
    END IF;

    -- CTE để aggregate email groups theo ComplianceId
    WITH compliance_emails AS (
        SELECT 
            ccge.ComplianceId,
            -- GroupType = 1: ResponsibleFor
            GROUP_CONCAT(DISTINCT CASE WHEN ccge.GroupType = 1 THEN cged.ResponseEmail END 
                ORDER BY CASE WHEN ccge.GroupType = 1 THEN cged.ResponseEmail END 
                SEPARATOR ',') AS ResponsibleFor,
            -- GroupType = 2: AlertFor
            GROUP_CONCAT(DISTINCT CASE WHEN ccge.GroupType = 2 THEN cged.ResponseEmail END 
                ORDER BY CASE WHEN ccge.GroupType = 2 THEN cged.ResponseEmail END 
                SEPARATOR ',') AS AlertFor,
            -- GroupType = 3: ResponsibleForAddition
            GROUP_CONCAT(DISTINCT CASE WHEN ccge.GroupType = 3 THEN cged.ResponseEmail END 
                ORDER BY CASE WHEN ccge.GroupType = 3 THEN cged.ResponseEmail END 
                SEPARATOR ',') AS ResponsibleForAddition,
            -- GroupType = 4: AlertForAddition
            GROUP_CONCAT(DISTINCT CASE WHEN ccge.GroupType = 4 THEN cged.ResponseEmail END 
                ORDER BY CASE WHEN ccge.GroupType = 4 THEN cged.ResponseEmail END 
                SEPARATOR ',') AS AlertForAddition
        FROM compl_compliance_group_email ccge
        LEFT JOIN compl_group_email_detail cged ON cged.GroupEmailId = ccge.GroupEmailId AND cged.IsActive = TRUE
        GROUP BY ccge.ComplianceId
    ),
    -- CTE để filter compliances
    filtered_compliances AS (
        SELECT DISTINCT cd.Id
        FROM compl_compliances cd
        LEFT JOIN compl_compliance_group_email ccge ON ccge.ComplianceId = cd.Id
        LEFT JOIN compl_group_email_detail cged ON cged.GroupEmailId = ccge.GroupEmailId AND cged.IsActive = TRUE
        WHERE 1=1
            -- Search condition
            AND (
                p_search_text IS NULL OR p_search_text = ''
                OR (
                    v_use_fulltext = TRUE 
                    AND MATCH(cd.Name, cd.Code, cd.Description) AGAINST (v_search_escaped IN BOOLEAN MODE)
                )
                OR (
                    v_use_fulltext = FALSE
                    AND (
                        cd.Code LIKE CONCAT('%', v_search_escaped, '%')
                        OR cd.Name LIKE CONCAT('%', v_search_escaped, '%')
                        OR cd.Description LIKE CONCAT('%', v_search_escaped, '%')
                    )
                )
            )
            -- Due days filter
            AND (
                p_due_days IS NULL 
                OR (cd.ValidTo IS NOT NULL AND cd.ValidTo <= DATE_ADD(UTC_TIMESTAMP(), INTERVAL p_due_days DAY))
            )
            -- User email filter
            AND (
                p_user_email IS NULL OR p_user_email = ''
                OR cd.CreatedBy = p_user_email
                OR cged.ResponseEmail = p_user_email
            )
    )
    SELECT 
        cd.Id,
        cd.Name,
        cd.Code,
        cd.NumDayAlert,
        cd.ValidFrom,
        cd.ValidTo,
        cd.FileId,
        cd.Description,
        cd.CreatedDate,
        cd.CreatedBy,
        
        -- Alert Group IDs (GroupType = 2)
        (
            SELECT GROUP_CONCAT(DISTINCT GroupEmailId ORDER BY GroupEmailId SEPARATOR ',')
            FROM compl_compliance_group_email 
            WHERE ComplianceId = cd.Id AND GroupType = 2
        ) AS AlertGroupIds,
        
        -- Responsible Group IDs (GroupType = 1)
        (
            SELECT GROUP_CONCAT(DISTINCT GroupEmailId ORDER BY GroupEmailId SEPARATOR ',')
            FROM compl_compliance_group_email 
            WHERE ComplianceId = cd.Id AND GroupType = 1
        ) AS RespGroupIds,
        
        -- Alert Groups JSON
        (
            SELECT JSON_ARRAYAGG(
                JSON_OBJECT(
                    'groupName', ge.Name,
                    'emails', (
                        SELECT JSON_ARRAYAGG(cged.ResponseEmail)
                        FROM compl_group_email_detail cged
                        WHERE cged.GroupEmailId = ge.Id AND cged.IsActive = TRUE
                    )
                )
            )
            FROM compl_compliance_group_email ccge
            INNER JOIN compl_group_email ge ON ccge.GroupEmailId = ge.Id
            WHERE ccge.ComplianceId = cd.Id AND ccge.GroupType = 2
        ) AS AlertGroupsJson,
        
        -- Responsible Groups JSON
        (
            SELECT JSON_ARRAYAGG(
                JSON_OBJECT(
                    'groupName', ge.Name,
                    'emails', (
                        SELECT JSON_ARRAYAGG(cged.ResponseEmail)
                        FROM compl_group_email_detail cged
                        WHERE cged.GroupEmailId = ge.Id AND cged.IsActive = TRUE
                    )
                )
            )
            FROM compl_compliance_group_email ccge
            INNER JOIN compl_group_email ge ON ccge.GroupEmailId = ge.Id
            WHERE ccge.ComplianceId = cd.Id AND ccge.GroupType = 1
        ) AS ResponsibleGroupsJson,
        
        -- Masters JSON
        (
            SELECT JSON_ARRAYAGG(
                JSON_OBJECT(
                    'id', cm.Id,
                    'code', cm.Code,
                    'name', cm.Name,
                    'validFrom', cm.ValidFrom,
                    'validTo', cm.ValidTo,
                    'numDayAlert', cm.NumDayAlert,
                    'description', cm.Description
                )
            )
            FROM compl_references cr
            INNER JOIN compl_masters cm ON cr.MasterId = cm.Id
            WHERE cr.ComplianceId = cd.Id
        ) AS MastersJson,
        
        -- Conditions JSON
        (
            SELECT JSON_ARRAYAGG(
                JSON_OBJECT(
                    'id', mc.Id,
                    'logical', mc.Logical,
                    'logicalName', CASE WHEN mc.Logical = 1 THEN 'AND' ELSE 'OR' END,
                    'refTypeId', mc.RefTypeId,
                    'refTypeCode', rt.Code,
                    'refTypeName', rt.Name,
                    'refTypeValue', mc.RefTypeValue,
                    'refTypeValueDisplay', mc.RefTypeValue
                )
            )
            FROM compl_master_conditions mc
            JOIN compl_reference_types rt ON mc.RefTypeId = rt.Id
            JOIN compl_references cr ON cr.MasterId = mc.MasterId
            WHERE cr.ComplianceId = cd.Id
        ) AS ConditionsJson,
        
        -- Compliance Emails từ CTE
        ce.ResponsibleFor,
        ce.AlertFor,
        ce.ResponsibleForAddition,
        ce.AlertForAddition,
        
        -- Relevance score for fulltext search
        CASE 
            WHEN v_use_fulltext THEN 
                MATCH(cd.Name, cd.Code, cd.Description) AGAINST (v_search_escaped IN BOOLEAN MODE)
            ELSE 0
        END AS relevance_score
        
    FROM compl_compliances cd
    INNER JOIN filtered_compliances fc ON fc.Id = cd.Id
    LEFT JOIN compliance_emails ce ON ce.ComplianceId = cd.Id
    ORDER BY 
        CASE WHEN v_use_fulltext THEN relevance_score ELSE NULL END DESC,
        CASE WHEN p_order_column = 'Id' AND p_order_direction = 'ASC' THEN cd.Id END ASC,
        CASE WHEN p_order_column = 'Id' AND p_order_direction = 'DESC' THEN cd.Id END DESC,
        CASE WHEN p_order_column = 'Name' AND p_order_direction = 'ASC' THEN cd.Name END ASC,
        CASE WHEN p_order_column = 'Name' AND p_order_direction = 'DESC' THEN cd.Name END DESC,
        CASE WHEN p_order_column = 'Code' AND p_order_direction = 'ASC' THEN cd.Code END ASC,
        CASE WHEN p_order_column = 'Code' AND p_order_direction = 'DESC' THEN cd.Code END DESC,
        CASE WHEN p_order_column = 'ValidFrom' AND p_order_direction = 'ASC' THEN cd.ValidFrom END ASC,
        CASE WHEN p_order_column = 'ValidFrom' AND p_order_direction = 'DESC' THEN cd.ValidFrom END DESC,
        CASE WHEN p_order_column = 'ValidTo' AND p_order_direction = 'ASC' THEN cd.ValidTo END ASC,
        CASE WHEN p_order_column = 'ValidTo' AND p_order_direction = 'DESC' THEN cd.ValidTo END DESC,
        CASE WHEN p_order_column = 'CreatedDate' AND p_order_direction = 'ASC' THEN cd.CreatedDate END ASC,
        CASE WHEN p_order_column = 'CreatedDate' AND p_order_direction = 'DESC' THEN cd.CreatedDate END DESC,
        cd.Id DESC
    LIMIT p_limit OFFSET p_offset;
    
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `compl_sp_get_compl_master_by_code` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `compl_sp_get_compl_master_by_code`(IN p_code VARCHAR(50))
BEGIN
    -- Lấy Id của version mới nhất theo Code
    DECLARE v_id BIGINT;
    
    SELECT Id INTO v_id
    FROM compl_masters
    WHERE Code = p_code
    ORDER BY VersionNo DESC
    LIMIT 1;

    -- Result set 1: Master
    SELECT 
        c.Id,		
        c.Code,
        c.Name,                
        c.ValidFrom,
        c.ValidTo,
        c.NumDayAlert,          
        c.IsDelete,
        c.VersionNo,
        c.ReplacedById,
        c.IsIndividual,
        c.DuplicateId,
        
        -- Tính trạng thái: active, expiring, overdue, expired
        CASE 
            WHEN c.IsDelete = 1 THEN 'expired'
            WHEN c.ValidTo < CURDATE() THEN 'overdue'
            WHEN DATEDIFF(c.ValidTo, CURDATE()) <= 30 THEN 'expiring'
            ELSE 'active'
        END AS Status,
        CONCAT(DATEDIFF(c.ValidTo, CURDATE()), ' days left') AS ExpiryWarning,		
        c.Description,

        c.CreatedDate,
        c.CreatedBy,
        COALESCE(c.UpdatedDate, c.CreatedDate) AS UpdatedDate,
        COALESCE(c.UpdatedBy, c.CreatedBy) AS UpdatedBy,        
        (
            SELECT GROUP_CONCAT(DISTINCT cged.ResponseEmail ORDER BY cged.ResponseEmail SEPARATOR ',')
            FROM compl_master_group_email cmge                
            LEFT JOIN compl_group_email_detail cged ON cged.GroupEmailId = cmge.GroupEmailId
            WHERE cmge.MasterId = c.Id AND cmge.GroupType = 1 AND cged.IsActive = 1
        ) AS ResponsibleFor,
        (
            SELECT GROUP_CONCAT(DISTINCT cged.ResponseEmail ORDER BY cged.ResponseEmail SEPARATOR ',')
            FROM compl_master_group_email cmge                
            LEFT JOIN compl_group_email_detail cged ON cged.GroupEmailId = cmge.GroupEmailId
            WHERE cmge.MasterId = c.Id AND cmge.GroupType = 2 AND cged.IsActive = 1
        ) AS AlertFor,
        (
            SELECT GROUP_CONCAT(DISTINCT cged.ResponseEmail ORDER BY cged.ResponseEmail SEPARATOR ',')
            FROM compl_master_group_email cmge                
            LEFT JOIN compl_group_email_detail cged ON cged.GroupEmailId = cmge.GroupEmailId
            WHERE cmge.MasterId = c.Id AND cmge.GroupType = 3 AND cged.IsActive = 1
        ) AS ResponsibleForAddition,
        (
            SELECT GROUP_CONCAT(DISTINCT cged.ResponseEmail ORDER BY cged.ResponseEmail SEPARATOR ',')
            FROM compl_master_group_email cmge                
            LEFT JOIN compl_group_email_detail cged ON cged.GroupEmailId = cmge.GroupEmailId
            WHERE cmge.MasterId = c.Id AND cmge.GroupType = 4 AND cged.IsActive = 1
        ) AS AlertForAddition,
        
        -- Alert Groups
        (
            SELECT GROUP_CONCAT(DISTINCT GroupEmailId ORDER BY GroupEmailId SEPARATOR ',')
            FROM compl_master_group_email 
            WHERE MasterId = c.Id AND GroupType = 2
        ) AS AlertGroupIds,
        
        -- Responsible Groups
        (
            SELECT GROUP_CONCAT(DISTINCT GroupEmailId ORDER BY GroupEmailId SEPARATOR ',')
            FROM compl_master_group_email 
            WHERE MasterId = c.Id AND GroupType = 1
        ) AS RespGroupIds,

        -- Responsible Groups JSON
        (
            SELECT JSON_ARRAYAGG(
                JSON_OBJECT(
                    'groupName', ge.Name,
                    'emails', (
                        SELECT JSON_ARRAYAGG(cged.ResponseEmail)
                        FROM compl_group_email_detail cged
                        WHERE cged.GroupEmailId = ge.Id AND cged.IsActive = TRUE
                    )
                )
            )
            FROM compl_master_group_email cmge
            INNER JOIN compl_group_email ge ON cmge.GroupEmailId = ge.Id
            WHERE cmge.MasterId = c.Id AND cmge.GroupType = 1
        ) AS ResponsibleGroupsJson,
        -- Đếm số compliance đã có theo master
        (
            SELECT COUNT(*)
			FROM compl_references cr            
            WHERE cr.MasterId = v_id             
        ) AS TotalCompliances
    FROM compl_masters c
    WHERE c.Id = v_id;
    
    -- Result set 2: Conditions
    SELECT 		
        com.*, 
        crt.Code AS RefTypeCode,
        crt.Name AS RefTypeName,
        CASE WHEN com.Logical = 1 THEN 'AND' ELSE 'OR' END AS LogicalName
    FROM compl_master_conditions com
    LEFT JOIN compl_reference_types crt ON crt.Id = com.RefTypeId
    WHERE com.MasterId = v_id;	
    
    -- Result set 3: Emails
    SELECT 		
        cmge.*,        
        ge.Name AS GroupEmailName
    FROM compl_master_group_email cmge
    LEFT JOIN compl_group_email ge ON ge.Id = cmge.GroupEmailId
    WHERE cmge.MasterId = v_id;
    
    -- Result Set 4: Condition Values
    SELECT 
        cmcv.Id,
        cmcv.ConditionId,
        cmcv.RefTypeValue,
        cmcv.RefTypeValue AS RefTypeValueDisplay
    FROM compl_master_condition_values cmcv
    INNER JOIN compl_master_conditions cmc ON cmcv.ConditionId = cmc.Id
    WHERE cmc.MasterId = v_id;

END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `compl_sp_get_compl_master_by_id` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `compl_sp_get_compl_master_by_id`(IN p_id BIGINT)
BEGIN
    SELECT
		c.Id,
        c.Code,
        c.Name,
        c.ValidFrom,
        c.ValidTo,
        c.NumDayAlert,
        c.IsDelete,
        c.VersionNo,
		c.ReplacedById,
        c.IsIndividual,
        c.DuplicateId,
        c.AlertType,

        -- Tính trạng thái: active, expiring, overdue, expired
        CASE
            WHEN c.IsDelete = 1 THEN 'expired'
            WHEN c.ValidTo < CURDATE() THEN 'overdue'
            WHEN DATEDIFF(c.ValidTo, CURDATE()) <= 30 THEN 'expiring'
            ELSE 'active'
        END AS Status,
        CONCAT(DATEDIFF(c.ValidTo, CURDATE()), ' days left') AS ExpiryWarning,
        c.Description,

        c.CreatedDate,
        c.CreatedBy,
		COALESCE(c.UpdatedDate, c.CreatedDate) as UpdatedDate,
        COALESCE(c.UpdatedBy, c.CreatedBy) as UpdatedBy,
        (
			SELECT GROUP_CONCAT(DISTINCT cged.ResponseEmail ORDER BY cged.ResponseEmail SEPARATOR ',') as email
              FROM compl_master_group_email cmge
               LEFT JOIN compl_group_email_detail cged ON cged.GroupEmailId = cmge.GroupEmailId
              WHERE cmge.MasterId = c.Id AND cmge.GroupType = 1 AND cged.IsActive = 1
        ) as ResponsibleFor,
        (
			SELECT GROUP_CONCAT(DISTINCT cged.ResponseEmail ORDER BY cged.ResponseEmail SEPARATOR ',') as email
              FROM compl_master_group_email cmge
               LEFT JOIN compl_group_email_detail cged ON cged.GroupEmailId = cmge.GroupEmailId
              WHERE cmge.MasterId = c.Id AND cmge.GroupType = 2 AND cged.IsActive = 1
        ) as AlertFor,
        (
			SELECT GROUP_CONCAT(DISTINCT cged.ResponseEmail ORDER BY cged.ResponseEmail SEPARATOR ',') as email
              FROM compl_master_group_email cmge
               LEFT JOIN compl_group_email_detail cged ON cged.GroupEmailId = cmge.GroupEmailId
              WHERE cmge.MasterId = c.Id AND cmge.GroupType = 3 AND cged.IsActive = 1
        ) as ResponsibleForAddition,
        (
			SELECT GROUP_CONCAT(DISTINCT cged.ResponseEmail ORDER BY cged.ResponseEmail SEPARATOR ',') as email
              FROM compl_master_group_email cmge
               LEFT JOIN compl_group_email_detail cged ON cged.GroupEmailId = cmge.GroupEmailId
              WHERE cmge.MasterId = c.Id AND cmge.GroupType = 4 AND cged.IsActive = 1
        ) as AlertForAddition,

        -- Alert Groups
        (
            SELECT GROUP_CONCAT(DISTINCT GroupEmailId ORDER BY GroupEmailId SEPARATOR ',')
            FROM compl_master_group_email
            WHERE MasterId = c.Id AND GroupType = 2
        ) AS AlertGroupIds,

        -- Responsible Groups
        (
            SELECT GROUP_CONCAT(DISTINCT GroupEmailId ORDER BY GroupEmailId SEPARATOR ',')
            FROM compl_master_group_email
            WHERE MasterId = c.Id AND GroupType = 1
        ) AS RespGroupIds,
        -- Responsible Groups JSON
        (
            SELECT JSON_ARRAYAGG(
                JSON_OBJECT(
                    'groupName', ge.Name,
                    'emails', (
                        SELECT JSON_ARRAYAGG(cged.ResponseEmail)
                        FROM compl_group_email_detail cged
                        WHERE cged.GroupEmailId = ge.Id AND cged.IsActive = TRUE
                    )
                )
            )
            FROM compl_master_group_email cmge
            INNER JOIN compl_group_email ge ON cmge.GroupEmailId = ge.Id
            WHERE cmge.MasterId = c.Id AND cmge.GroupType = 1
        ) AS ResponsibleGroupsJson,
        -- Đếm số compliance đã có theo master
        (
            SELECT COUNT(*)
			FROM compl_references cr
            WHERE cr.MasterId = p_id
        ) AS TotalCompliances
    FROM compl_masters c
    WHERE c.Id = p_id;

    -- Result set 2: Conditions
    SELECT
        com.*,
        crt.Code as `RefTypeCode`,
        crt.Name as `RefTypeName`,
        CASE WHEN com.Logical = 1 THEN 'AND' ELSE 'OR' END AS LogicalName
    FROM compl_master_conditions com
    LEFT JOIN compl_reference_types crt ON crt.Id = com.RefTypeId
    WHERE com.MasterId = p_id;

    -- Result set 3: Emails
    SELECT
        cmge.*,
        ge.Name as GroupEmailName
    FROM compl_master_group_email cmge
    LEFT JOIN compl_group_email ge ON ge.Id = cmge.GroupEmailId
    WHERE cmge.MasterId = p_id;

     -- Result Set 4: Condition Values
	 SELECT
		 cmcv.Id,
		 cmcv.ConditionId,
		 cmcv.RefTypeValue,
		 cmcv.RefTypeValue AS RefTypeValueDisplay
	 FROM compl_master_condition_values cmcv
	 INNER JOIN compl_master_conditions cmc ON cmcv.ConditionId = cmc.Id
	 WHERE cmc.MasterId = p_id;
	 -- ORDER BY cmc.BlockNo, cmc.ConditionNo;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `compl_sp_get_compl_master_condition` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `compl_sp_get_compl_master_condition`(IN p_master_id INT)
BEGIN
SELECT JSON_ARRAYAGG(
                JSON_OBJECT(
                    'id', cmc.Id,
                    'logical', cmc.Logical,
                    'operator', cmc.Operator,
                    'complType', cmc.ComplType,
                    'refTypeId', cmc.RefTypeId,
                    'displayType', cmc.DisplayType,
                    'logicalName', CASE cmc.Logical 
                        WHEN 1 THEN 'AND' 
                        WHEN 2 THEN 'OR' 
                        ELSE 'UNKNOWN' 
                    END,
                    'refTypeCode', crt.Code,
                    'refTypeName', crt.Name,
                    'conditionValues', (
                        SELECT JSON_ARRAYAGG(
                            JSON_OBJECT(
                                'id', cmcv.Id,
                                'ConditionId', cmcv.ConditionId,
                                'refTypeValue', cmcv.RefTypeValue,
                                'refTypeValueDisplay', cmcv.RefTypeValue,
                                'status', CASE 
                                    WHEN EXISTS (
                                        SELECT 1
                                        FROM compl_references cr
                                        WHERE cr.MasterId = cmc.MasterId
                                          AND cr.RefTypeId = cmc.RefTypeId
                                          AND cr.RefTypeValue = cmcv.RefTypeValue
                                          AND (cr.ValidTo IS NULL OR cr.ValidTo >= NOW())
                                    ) THEN 'OK'
                                    ELSE 'Missing'
                                END
                            )
                        )
                        FROM compl_master_condition_values cmcv
                        WHERE cmcv.ConditionId = cmc.Id
                    )
                )
            ) AS ConditionsJson
            FROM compl_master_conditions cmc
            LEFT JOIN compl_reference_types crt ON crt.Id = cmc.RefTypeId
            WHERE cmc.MasterId = p_master_id;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `compl_sp_get_compl_master_missing` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `compl_sp_get_compl_master_missing`(
    IN p_user_email VARCHAR(50)
)
BEGIN
    WITH LatestVersions AS (
        SELECT Code, MAX(VersionNo) AS MaxVersion
        FROM compl_masters
        GROUP BY Code
    ),
    MasterData AS (
        SELECT
            cd.Id,
            cd.Name,
            cd.Code,
            cd.NumDayAlert,
            cd.ValidFrom,
            cd.ValidTo,
            cd.Description,
            cd.CreatedDate,
            cd.CreatedBy,
            cd.VersionNo,
            cd.ReplacedById,
            cd.IsIndividual,

            CASE
                WHEN EXISTS (
                    SELECT 1
                    FROM compl_master_conditions mc_check
                    WHERE mc_check.MasterId = cd.Id
                      AND mc_check.ComplType = 1
                )
                THEN 1
                ELSE 0
            END AS ComplType,

            CASE
                WHEN NOT EXISTS (
                    SELECT 1
                    FROM compl_master_conditions mc_check
                    WHERE mc_check.MasterId = cd.Id
                      AND mc_check.ComplType = 1
                )
                AND EXISTS (
                    SELECT 1
                    FROM compl_references cr
                    WHERE cr.MasterId = cd.Id
                )
                THEN 'OK'
                ELSE 'Missing'
            END AS Status

        FROM compl_masters cd
        INNER JOIN LatestVersions lv
            ON cd.Code = lv.Code AND cd.VersionNo = lv.MaxVersion
        WHERE 1=1
            -- User email filter
            AND (
                p_user_email IS NULL
                OR p_user_email = ''
                OR cd.CreatedBy = p_user_email
                OR EXISTS (
                    SELECT 1
                    FROM compl_master_group_email cmge
                    INNER JOIN compl_group_email_detail cged
                        ON cged.GroupEmailId = cmge.GroupEmailId
                    WHERE cmge.MasterId = cd.Id
                      AND cmge.GroupType = 1
                      AND cged.IsActive = TRUE
                      AND cged.ResponseEmail = p_user_email
                )
            )
    )
    SELECT
        md.*,
        -- Đếm số compliance đã có theo master
        (
            SELECT COUNT(DISTINCT cr.MasterId, cr.RefTypeId, cr.RefTypeValue)
            FROM compl_references cr
            INNER JOIN compl_compliances cc ON cr.ComplianceId = cc.Id
            WHERE cr.MasterId = md.Id
              AND cc.IsDelete = 0
        ) AS TotalCompliances

    FROM MasterData md
    WHERE md.Status = 'Missing'   -- Chỉ lấy các master bị thiếu compliance
    ORDER BY md.Id DESC;

END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `compl_sp_get_compl_master_missing_for_alert` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `compl_sp_get_compl_master_missing_for_alert`(
    IN p_user_email VARCHAR(50)
)
BEGIN
    WITH LatestVersions AS (
        SELECT Code, MAX(VersionNo) AS MaxVersion
        FROM compl_masters
        GROUP BY Code
    ),
    MasterData AS (
        SELECT
            cd.Id,
            cd.Name,
            cd.Code,
            cd.NumDayAlert,
            cd.ValidFrom,
            cd.ValidTo,
            cd.Description,
            cd.CreatedDate,
            cd.CreatedBy,
            cd.VersionNo,
            cd.ReplacedById,
            cd.IsIndividual,
            CASE
                WHEN EXISTS (
                    SELECT 1
                    FROM compl_master_conditions mc_check
                    WHERE mc_check.MasterId = cd.Id
                      AND mc_check.ComplType = 1
                )
                THEN 1
                ELSE 0
            END AS ComplType,
            CASE
                WHEN NOT EXISTS (
                    SELECT 1
                    FROM compl_master_conditions mc_check
                    WHERE mc_check.MasterId = cd.Id
                      AND mc_check.ComplType = 1
                )
                AND EXISTS (
                    SELECT 1
                    FROM compl_references cr
                    INNER JOIN compl_compliances cc ON cr.ComplianceId = cc.Id
                    WHERE cr.MasterId = cd.Id
                      AND cc.IsDelete = 0
                )
                THEN 'OK'
                ELSE 'Missing'
            END AS Status
        FROM compl_masters cd
        INNER JOIN LatestVersions lv
            ON cd.Code = lv.Code AND cd.VersionNo = lv.MaxVersion
        WHERE cd.IsDelete = 0
            AND (
                p_user_email IS NULL
                OR p_user_email = ''
                OR cd.CreatedBy = p_user_email
                OR EXISTS (
                    SELECT 1
                    FROM compl_master_group_email cmge
                    INNER JOIN compl_group_email_detail cged
                        ON cged.GroupEmailId = cmge.GroupEmailId
                    WHERE cmge.MasterId = cd.Id
                      AND cmge.GroupType = 1
                      AND cged.IsActive = TRUE
                      AND cged.ResponseEmail = p_user_email
                )
            )
    ),
    -- ✅ CTE lấy email groups từ compl_sp_get_alert_master_compliances
    MasterEmails AS (
        SELECT
            ccge.MasterId,
            GROUP_CONCAT(DISTINCT CASE WHEN ccge.GroupType = 1 THEN cged.ResponseEmail END
                ORDER BY CASE WHEN ccge.GroupType = 1 THEN cged.ResponseEmail END
                SEPARATOR ',') AS ResponsibleFor,
            GROUP_CONCAT(DISTINCT CASE WHEN ccge.GroupType = 2 THEN cged.ResponseEmail END
                ORDER BY CASE WHEN ccge.GroupType = 2 THEN cged.ResponseEmail END
                SEPARATOR ',') AS AlertFor,
            GROUP_CONCAT(DISTINCT CASE WHEN ccge.GroupType = 3 THEN cged.ResponseEmail END
                ORDER BY CASE WHEN ccge.GroupType = 3 THEN cged.ResponseEmail END
                SEPARATOR ',') AS ResponsibleForAddition,
            GROUP_CONCAT(DISTINCT CASE WHEN ccge.GroupType = 4 THEN cged.ResponseEmail END
                ORDER BY CASE WHEN ccge.GroupType = 4 THEN cged.ResponseEmail END
                SEPARATOR ',') AS AlertForAddition
        FROM compl_master_group_email ccge
        LEFT JOIN compl_group_email_detail cged
            ON cged.GroupEmailId = ccge.GroupEmailId AND cged.IsActive = TRUE
        GROUP BY ccge.MasterId
    )
    SELECT
        -- md.*,
        md.Id,
        md.Name AS MasterName,
        md.Code AS MasterCode,
        '' FileName,
        '' FileId,

        md.NumDayAlert,
        null ValidFrom,
        null ValidTo,
        md.Description,

        md.CreatedDate,
        md.CreatedBy,

        -- ✅ Email fields từ MasterEmails CTE
        me.ResponsibleFor   AS ResponsibleEmails,
        me.AlertFor         AS AlertEmails,
        me.ResponsibleForAddition,
        me.AlertForAddition,

        -- Đếm số compliance đã có theo master
        (
            SELECT COUNT(DISTINCT cr.MasterId, cr.RefTypeId, cr.RefTypeValue)
            FROM compl_references cr
            INNER JOIN compl_compliances cc ON cr.ComplianceId = cc.Id
            WHERE cr.MasterId = md.Id
              AND cc.IsDelete = 0
        ) AS TotalCompliances
    FROM MasterData md
    LEFT JOIN MasterEmails me ON me.MasterId = md.Id  -- ✅ JOIN vào MasterData
    WHERE md.Status = 'Missing'
    ORDER BY md.Id DESC;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `compl_sp_get_compl_master_paging` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `compl_sp_get_compl_master_paging`(
    IN p_limit INT,
    IN p_offset INT,
    IN p_order_column VARCHAR(50),
    IN p_order_direction VARCHAR(4),
    IN p_search_text VARCHAR(255),
    IN p_due_days INT,
    IN p_user_email VARCHAR(50),
    IN p_ref_type_id BIGINT,
    IN p_ref_type_value VARCHAR(255),
    IN p_status VARCHAR(10),          -- 'OK', 'Missing', hoặc NULL = không filter
    IN p_created_by VARCHAR(50),
    IN p_is_individual tinyint
)
BEGIN
    DECLARE v_search_pattern VARCHAR(257);
    DECLARE v_search_fulltext VARCHAR(257);
    DECLARE v_min_search_length INT DEFAULT 3;

    IF p_search_text IS NOT NULL AND TRIM(p_search_text) != '' THEN
        SET v_search_pattern = CONCAT('%', TRIM(p_search_text), '%');
        SET v_search_fulltext = CONCAT(
            '"',
            REPLACE(
                REPLACE(
                    REPLACE(TRIM(p_search_text), '"', ''),
                    '+', ''),
                '\\', ''),
            '"'
        );
    END IF;

    WITH LatestVersions AS (
        SELECT Code, MAX(VersionNo) AS MaxVersion
        FROM compl_masters
        GROUP BY Code
    ),
    MasterData AS (
        SELECT
            cd.Id,
            cd.Name,
            cd.Code,
            cd.NumDayAlert,
            cd.ValidFrom,
            cd.ValidTo,
            cd.Description,
            cd.CreatedDate,
            cd.CreatedBy,
            cd.VersionNo,
            cd.ReplacedById,
            cd.IsIndividual,
            cd.AlertType,

            CASE
                WHEN p_search_text IS NOT NULL
                     AND CHAR_LENGTH(TRIM(p_search_text)) >= v_min_search_length
                THEN MATCH(cd.Name, cd.Code, cd.Description)
                     AGAINST (v_search_fulltext IN BOOLEAN MODE)
                ELSE 0
            END AS relevance_score,

            CASE
                WHEN EXISTS (
                    SELECT 1
                    FROM compl_master_conditions mc_check
                    WHERE mc_check.MasterId = cd.Id
                      AND mc_check.ComplType = 1
                )
                THEN 1
                ELSE 0
            END AS ComplType,

            CASE
                WHEN NOT EXISTS (
                    SELECT 1
                    FROM compl_master_conditions mc_check
                    WHERE mc_check.MasterId = cd.Id
                      AND mc_check.ComplType = 1
                )
                AND EXISTS (
                    SELECT 1
                    FROM compl_references cr
                    INNER JOIN compl_compliances cc ON cr.ComplianceId = cc.Id
                    WHERE cr.MasterId = cd.Id
                      AND cc.IsDelete = 0
                )
                THEN 'OK'
                ELSE 'Missing'
            END AS Status

        FROM compl_masters cd
        INNER JOIN LatestVersions lv
            ON cd.Code = lv.Code AND cd.VersionNo = lv.MaxVersion
        WHERE cd.IsDelete = 0
            AND (
                p_search_text IS NULL
                OR TRIM(p_search_text) = ''
                OR (
                    CASE
                        WHEN CHAR_LENGTH(TRIM(p_search_text)) >= v_min_search_length
                        THEN MATCH(cd.Name, cd.Code, cd.Description)
                             AGAINST (v_search_fulltext IN BOOLEAN MODE)
                        ELSE 0
                    END > 0
                    OR cd.Code LIKE v_search_pattern
                    OR cd.Name LIKE v_search_pattern
                    OR cd.Description LIKE v_search_pattern
                )
            )
            AND (
                p_due_days IS NULL
                OR (cd.ValidTo IS NOT NULL
                    AND cd.ValidTo <= DATE_ADD(UTC_TIMESTAMP(), INTERVAL p_due_days DAY))
            )
            AND (
                p_user_email IS NULL
                OR p_user_email = ''
                OR cd.CreatedBy = p_user_email
                OR EXISTS (
                    SELECT 1
                    FROM compl_master_group_email cmge
                    INNER JOIN compl_group_email_detail cged
                        ON cged.GroupEmailId = cmge.GroupEmailId
                    WHERE cmge.MasterId = cd.Id
                      AND cmge.GroupType = 1
                      AND cged.IsActive = TRUE
                      AND cged.ResponseEmail = p_user_email
                )
            )
            AND (
                (p_ref_type_id IS NULL AND p_ref_type_value IS NULL)
                OR EXISTS (
                    SELECT 1
                    FROM compl_master_conditions cmc
                    INNER JOIN compl_master_condition_values cmcv
                        ON cmcv.ConditionId = cmc.Id
                    WHERE cmc.MasterId = cd.Id
                      AND (p_ref_type_id IS NULL OR cmc.RefTypeId = p_ref_type_id)
                      AND (p_ref_type_value IS NULL OR cmcv.RefTypeValue = p_ref_type_value)
                )
            )
            -- Status filter
            AND (
                p_status IS NULL
                OR TRIM(p_status) = ''
                OR (
                    UPPER(TRIM(p_status)) = 'OK'
                    AND NOT EXISTS (
                        SELECT 1 FROM compl_master_conditions mc_check
                        WHERE mc_check.MasterId = cd.Id AND mc_check.ComplType = 1
                    )
                    AND EXISTS (
                        SELECT 1 FROM compl_references cr
                        INNER JOIN compl_compliances cc ON cr.ComplianceId = cc.Id
                        WHERE cr.MasterId = cd.Id
                          AND cc.IsDelete = 0
                    )
                )
                OR (
                    UPPER(TRIM(p_status)) = 'MISSING'
                    AND (
                        EXISTS (
                            SELECT 1 FROM compl_master_conditions mc_check
                            WHERE mc_check.MasterId = cd.Id AND mc_check.ComplType = 1
                        )
                        OR NOT EXISTS (
                            SELECT 1 FROM compl_references cr
                            INNER JOIN compl_compliances cc ON cr.ComplianceId = cc.Id
                            WHERE cr.MasterId = cd.Id
                              AND cc.IsDelete = 0
                        )
                    )
                )
            )
            -- Filter CreatdBy
            AND (cd.CreatedBy like concat('%',p_created_by,'%')
				OR p_created_by IS NULL
                OR p_created_by = '')
            AND (
                p_is_individual IS NULL
                OR cd.IsIndividual = p_is_individual
            )
    )
    SELECT
        md.*,

        -- Alert Groups
        (
            SELECT GROUP_CONCAT(DISTINCT GroupEmailId ORDER BY GroupEmailId SEPARATOR ',')
            FROM compl_master_group_email
            WHERE MasterId = md.Id AND GroupType = 2
        ) AS AlertGroupIds,

        -- Responsible Groups
        (
            SELECT GROUP_CONCAT(DISTINCT GroupEmailId ORDER BY GroupEmailId SEPARATOR ',')
            FROM compl_master_group_email
            WHERE MasterId = md.Id AND GroupType = 1
        ) AS RespGroupIds,

        -- Alert Groups JSON
        (
            SELECT JSON_ARRAYAGG(
                JSON_OBJECT(
                    'groupName', ge.Name,
                    'emails', (
                        SELECT JSON_ARRAYAGG(cged.ResponseEmail)
                        FROM compl_group_email_detail cged
                        WHERE cged.GroupEmailId = ge.Id AND cged.IsActive = TRUE
                    )
                )
            )
            FROM compl_master_group_email cmge
            INNER JOIN compl_group_email ge ON cmge.GroupEmailId = ge.Id
            WHERE cmge.MasterId = md.Id AND cmge.GroupType = 2
        ) AS AlertGroupsJson,

        -- Responsible Groups JSON
        (
            SELECT JSON_ARRAYAGG(
                JSON_OBJECT(
                    'groupName', ge.Name,
                    'emails', (
                        SELECT JSON_ARRAYAGG(cged.ResponseEmail)
                        FROM compl_group_email_detail cged
                        WHERE cged.GroupEmailId = ge.Id AND cged.IsActive = TRUE
                    )
                )
            )
            FROM compl_master_group_email cmge
            INNER JOIN compl_group_email ge ON cmge.GroupEmailId = ge.Id
            WHERE cmge.MasterId = md.Id AND cmge.GroupType = 1
        ) AS ResponsibleGroupsJson,

        -- Conditions JSON
        NULL AS ConditionsJson,

        -- Đếm số compliance đã có theo master
        (
            SELECT COUNT(DISTINCT cr.MasterId, cr.RefTypeId, cr.RefTypeValue)
            FROM compl_references cr
            INNER JOIN compl_compliances cc ON cr.ComplianceId = cc.Id
            WHERE cr.MasterId = md.Id
              AND cc.IsDelete = 0
        ) AS TotalCompliances,
        mdc.Id   AS MasterDefaultConfigId,
		mdc.Code AS MasterDefaultConfigCode,
		mdc.Name AS MasterDefaultConfigName
    FROM MasterData md
    LEFT JOIN compl_master_default_logs mdl
		ON mdl.CreatedMasterId = md.Id
		AND mdl.Status = 'SUCCESS'
	LEFT JOIN compl_master_default_configs mdc
		ON mdc.Id = mdl.ConfigId
	LEFT JOIN compl_master_default_templates mdt
		ON mdt.Id = mdl.TemplateId
    ORDER BY
        CASE
            WHEN p_search_text IS NOT NULL AND TRIM(p_search_text) != ''
            THEN relevance_score
            ELSE 0
        END DESC,
        CASE
            WHEN p_order_column = 'Id' AND UPPER(p_order_direction) = 'ASC' THEN md.Id
            WHEN p_order_column = 'Code' AND UPPER(p_order_direction) = 'ASC' THEN md.Code
            WHEN p_order_column = 'Name' AND UPPER(p_order_direction) = 'ASC' THEN md.Name
            WHEN p_order_column = 'ValidTo' AND UPPER(p_order_direction) = 'ASC' THEN md.ValidTo
            WHEN p_order_column = 'Status' AND UPPER(p_order_direction) = 'ASC' THEN md.Status
        END ASC,
        CASE
            WHEN p_order_column = 'Id' AND UPPER(p_order_direction) = 'DESC' THEN md.Id
            WHEN p_order_column = 'Code' AND UPPER(p_order_direction) = 'DESC' THEN md.Code
            WHEN p_order_column = 'Name' AND UPPER(p_order_direction) = 'DESC' THEN md.Name
            WHEN p_order_column = 'ValidTo' AND UPPER(p_order_direction) = 'DESC' THEN md.ValidTo
            WHEN p_order_column = 'Status' AND UPPER(p_order_direction) = 'DESC' THEN md.Status
        END DESC,
        md.Id DESC
    LIMIT p_limit OFFSET p_offset;

END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `compl_sp_get_compl_master_paging_count` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `compl_sp_get_compl_master_paging_count`(
    IN p_search_text VARCHAR(255),
    IN p_due_days INT,
    IN p_user_email VARCHAR(50),
    IN p_ref_type_id BIGINT,
    IN p_ref_type_value VARCHAR(255),
    IN p_status VARCHAR(10),          -- 'OK', 'Missing', hoặc NULL = không filter
    IN p_created_by VARCHAR(50),
    IN p_is_individual tinyint
)
BEGIN
    DECLARE v_search_pattern VARCHAR(257);
    DECLARE v_search_fulltext VARCHAR(257);
    DECLARE v_min_search_length INT DEFAULT 3;

    -- Prepare search patterns, SET v_search_fulltext
	IF p_search_text IS NOT NULL AND TRIM(p_search_text) != '' THEN
		SET v_search_pattern = CONCAT('%', TRIM(p_search_text), '%');

		-- Escape các ký tự đặc biệt của FULLTEXT boolean mode
		SET v_search_fulltext = CONCAT(
			'"',
			REPLACE(
				REPLACE(
					REPLACE(TRIM(p_search_text), '"', ''),  -- xóa dấu "
					'+', ''),                                -- xóa +
				'\\', ''),                                   -- xóa backslash
			'"'
		);
		-- Kết quả: 'MAS-00081' → '"MAS-00081"' (phrase search, hyphen được xử lý literal)
	END IF;

    -- Count Query with CTE
    WITH LatestVersions AS (
        -- Lấy Id của version mới nhất cho mỗi Code
        SELECT Code, MAX(VersionNo) AS MaxVersion
        FROM compl_masters
        GROUP BY Code
    )
    SELECT COUNT(*) AS TotalCount
    FROM compl_masters cd
    INNER JOIN LatestVersions lv
        ON cd.Code = lv.Code AND cd.VersionNo = lv.MaxVersion
    WHERE cd.IsDelete = 0
        -- Search filter with FULLTEXT + LIKE fallback
        AND (
            p_search_text IS NULL
            OR TRIM(p_search_text) = ''
            OR (
                -- Use FULLTEXT if length is sufficient
                CASE
                    WHEN CHAR_LENGTH(TRIM(p_search_text)) >= v_min_search_length
                    THEN MATCH(cd.Name, cd.Code, cd.Description)
                         AGAINST (v_search_fulltext IN BOOLEAN MODE)
                    ELSE 0
                END > 0
                -- Fallback to LIKE for short words
                OR cd.Code LIKE v_search_pattern
                OR cd.Name LIKE v_search_pattern
                OR cd.Description LIKE v_search_pattern
            )
        )
        -- Due days filter
        AND (
            p_due_days IS NULL
            OR (cd.ValidTo IS NOT NULL
                AND cd.ValidTo <= DATE_ADD(UTC_TIMESTAMP(), INTERVAL p_due_days DAY))
        )
        -- User email filter
        AND (
            p_user_email IS NULL
            OR p_user_email = ''
            OR cd.CreatedBy = p_user_email
            OR EXISTS (
                SELECT 1
                FROM compl_master_group_email cmge
                INNER JOIN compl_group_email_detail cged
                    ON cged.GroupEmailId = cmge.GroupEmailId
                WHERE cmge.MasterId = cd.Id
                  AND cmge.GroupType = 1
                  AND cged.IsActive = TRUE
                  AND cged.ResponseEmail = p_user_email
            )
        )
        -- Filter by reference type and value
        AND (
            (p_ref_type_id IS NULL AND p_ref_type_value IS NULL)
            OR EXISTS (
                SELECT 1
                FROM compl_master_conditions cmc
                INNER JOIN compl_master_condition_values cmcv
                    ON cmcv.ConditionId = cmc.Id
                WHERE cmc.MasterId = cd.Id
                  AND (p_ref_type_id IS NULL OR cmc.RefTypeId = p_ref_type_id)
                  AND (p_ref_type_value IS NULL OR cmcv.RefTypeValue = p_ref_type_value)
            )
        )
        -- Status filter
            AND (
                p_status IS NULL
                OR TRIM(p_status) = ''
                OR (
                    UPPER(TRIM(p_status)) = 'OK'
                    AND NOT EXISTS (
                        SELECT 1 FROM compl_master_conditions mc_check
                        WHERE mc_check.MasterId = cd.Id AND mc_check.ComplType = 1
                    )
                    AND EXISTS (
                        SELECT 1 FROM compl_references cr
                        INNER JOIN compl_compliances cc ON cr.ComplianceId = cc.Id
                        WHERE cr.MasterId = cd.Id
                          AND cc.IsDelete = 0
                    )
                )
                OR (
                    UPPER(TRIM(p_status)) = 'MISSING'
                    AND (
                        EXISTS (
                            SELECT 1 FROM compl_master_conditions mc_check
                            WHERE mc_check.MasterId = cd.Id AND mc_check.ComplType = 1
                        )
                        OR NOT EXISTS (
                            SELECT 1 FROM compl_references cr
                            INNER JOIN compl_compliances cc ON cr.ComplianceId = cc.Id
                            WHERE cr.MasterId = cd.Id
                              AND cc.IsDelete = 0
                        )
                    )
                )
            )
            -- Filter CreatdBy
            AND (cd.CreatedBy like concat('%',p_created_by,'%')
				OR p_created_by IS NULL
                OR p_created_by = '')
            AND (
                p_is_individual IS NULL
                OR cd.IsIndividual = p_is_individual
            )
            ;

END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `compl_sp_get_compl_master_paging_search_condition` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `compl_sp_get_compl_master_paging_search_condition`(
    IN p_limit INT,
    IN p_offset INT,
    IN p_order_column VARCHAR(50),
    IN p_order_direction VARCHAR(4),
    IN p_search_text VARCHAR(255),  
    IN p_due_days INT,
    IN p_user_email VARCHAR(50),
    -- New parameters for condition filtering
    IN p_ref_type_id BIGINT,           -- Single RefTypeId to filter
    IN p_ref_type_value VARCHAR(255),  -- Single RefTypeValue to filter
    IN p_conditions_json JSON          -- Multiple conditions as JSON array
    -- Example: [{"refTypeId": 1, "refTypeValue": "DNK"}, {"refTypeId": 2, "refTypeValue": "10235"}]
)
BEGIN
    DECLARE v_search_escaped VARCHAR(255);
    DECLARE v_use_fulltext BOOLEAN DEFAULT FALSE;
    DECLARE v_has_single_condition BOOLEAN DEFAULT FALSE;
    DECLARE v_has_multiple_conditions BOOLEAN DEFAULT FALSE;
    
    -- Check if we have condition filters
    IF p_ref_type_id IS NOT NULL AND p_ref_type_value IS NOT NULL THEN
        SET v_has_single_condition = TRUE;
    END IF;
    
    IF p_conditions_json IS NOT NULL AND JSON_LENGTH(p_conditions_json) > 0 THEN
        SET v_has_multiple_conditions = TRUE;
    END IF;
    
    -- Escape search text và check fulltext
    IF p_search_text IS NOT NULL AND p_search_text <> '' THEN
        SET v_search_escaped = REPLACE(REPLACE(p_search_text, '\\', '\\\\'), '''', '''''');
        SET v_search_escaped = REPLACE(v_search_escaped, '+', '\\+');
        SET v_search_escaped = REPLACE(v_search_escaped, '-', '\\-');
        SET v_search_escaped = REPLACE(v_search_escaped, '<', '\\<');
        SET v_search_escaped = REPLACE(v_search_escaped, '>', '\\>');
        SET v_search_escaped = REPLACE(v_search_escaped, '(', '\\(');
        SET v_search_escaped = REPLACE(v_search_escaped, ')', '\\)');
        SET v_search_escaped = REPLACE(v_search_escaped, '~', '\\~');
        SET v_search_escaped = REPLACE(v_search_escaped, '*', '\\*');
        SET v_search_escaped = REPLACE(v_search_escaped, '"', '\\"');
        SET v_search_escaped = REPLACE(v_search_escaped, '@', '\\@');
        
        IF CHAR_LENGTH(TRIM(p_search_text)) >= 3 THEN
            SET v_use_fulltext = TRUE;
        END IF;
    END IF;

    SET @sql = '
        SELECT            
            cd.Id,
            cd.Name,
            cd.Code,            
            cd.NumDayAlert,
            cd.ValidFrom,
            cd.ValidTo,            
            cd.Description,            
            cd.CreatedDate,
            cd.CreatedBy,
            -- Check có All specific hay không
            CASE 
                WHEN EXISTS (
                    SELECT 1 
                    FROM compl_master_conditions mc_check 
                    WHERE mc_check.MasterId = cd.Id 
                    AND mc_check.RefTypeValue = ''All specific''
                )
                THEN 1
                ELSE 0
            END AS ComplType,
            -- Status check
            CASE 
                WHEN NOT EXISTS (
                    SELECT 1 
                    FROM compl_master_conditions mc_check 
                    WHERE mc_check.MasterId = cd.Id 
                    AND mc_check.RefTypeValue = ''All specific''
                )
                AND EXISTS (
                    SELECT 1 
                    FROM compl_references cr 
                    WHERE cr.MasterId = cd.Id
                )
                THEN ''OK''
                ELSE ''Missing''
            END AS Status,
            (
                SELECT GROUP_CONCAT(DISTINCT GroupEmailId ORDER BY GroupEmailId SEPARATOR '','')
                FROM compl_master_group_email WHERE MasterId = cd.Id AND GroupType = 2
            ) AS AlertGroupIds,
            (
                SELECT GROUP_CONCAT(DISTINCT GroupEmailId ORDER BY GroupEmailId SEPARATOR '','')
                FROM compl_master_group_email WHERE MasterId = cd.Id AND GroupType = 1
            ) AS RespGroupIds,
            (
                SELECT JSON_ARRAYAGG(
                    JSON_OBJECT(
                        "groupName", ge.Name,
                        "emails", (
                            SELECT JSON_ARRAYAGG(cged.ResponseEmail)
                            FROM compl_group_email_detail cged
                            WHERE cged.GroupEmailId = ge.Id AND cged.IsActive = TRUE
                        )
                    )
                )
                FROM compl_master_group_email cmge
                INNER JOIN compl_group_email ge ON cmge.GroupEmailId = ge.Id
                WHERE cmge.MasterId = cd.Id AND cmge.GroupType = 2
            ) AS AlertGroupsJson,
            (
                SELECT JSON_ARRAYAGG(
                    JSON_OBJECT(
                        "groupName", ge.Name,
                        "emails", (
                            SELECT JSON_ARRAYAGG(cged.ResponseEmail)
                            FROM compl_group_email_detail cged
                            WHERE cged.GroupEmailId = ge.Id AND cged.IsActive = TRUE
                        )
                    )
                )
                FROM compl_master_group_email cmge
                INNER JOIN compl_group_email ge ON cmge.GroupEmailId = ge.Id
                WHERE cmge.MasterId = cd.Id AND cmge.GroupType = 1
            ) AS ResponsibleGroupsJson,            
            -- JSON cho Conditions
            (
                SELECT JSON_ARRAYAGG(
                    JSON_OBJECT(
                        "id", mc.Id,
                        "logical", mc.Logical,
                        "logicalName", CASE WHEN mc.Logical = 1 THEN "AND" ELSE "OR" END,
                        "refTypeId", mc.RefTypeId,
                        "refTypeCode", rt.Code,
                        "refTypeName", rt.Name,
                        "refTypeValue", mc.RefTypeValue,
                        "refTypeValueDisplay", mc.RefTypeValue
                    )
                )
                FROM compl_master_conditions mc
                JOIN compl_reference_types rt ON mc.RefTypeId = rt.Id
                WHERE mc.MasterId = cd.Id
            ) AS ConditionsJson
    ';
    
    -- Thêm relevance score nếu dùng Full-Text Search
    IF v_use_fulltext THEN
        SET @sql = CONCAT(@sql, ',
            MATCH(cd.Name, cd.Code, cd.Description) AGAINST (''', 
            v_search_escaped, 
            ''' IN BOOLEAN MODE) AS relevance_score');
    END IF;
    
    SET @sql = CONCAT(@sql, '
        FROM compl_masters cd                
        WHERE 1=1
    ');

    -- ========== CONDITION FILTERING ==========
    
    -- Option 1: Single condition filter (contains this condition)
    IF v_has_single_condition THEN
        SET @sql = CONCAT(@sql, '
            AND EXISTS (
                SELECT 1 
                FROM compl_master_conditions mc_filter
                WHERE mc_filter.MasterId = cd.Id
                AND mc_filter.RefTypeId = ', p_ref_type_id, '
                AND mc_filter.RefTypeValue = ''', REPLACE(p_ref_type_value, '''', ''''''), '''
            )
        ');
    END IF;
    
    -- Option 2: Multiple conditions filter (ALL must match)
    IF v_has_multiple_conditions THEN
        -- Parse JSON và build condition
        DROP TEMPORARY TABLE IF EXISTS tmp_filter_conditions;
        CREATE TEMPORARY TABLE tmp_filter_conditions (
            RefTypeId BIGINT,
            RefTypeValue VARCHAR(255),
            INDEX idx_ref (RefTypeId, RefTypeValue)
        );
        
        -- Insert conditions từ JSON
        SET @insert_sql = 'INSERT INTO tmp_filter_conditions (RefTypeId, RefTypeValue)
            SELECT 
                JSON_UNQUOTE(JSON_EXTRACT(jt.value, ''$.refTypeId'')) AS RefTypeId,
                JSON_UNQUOTE(JSON_EXTRACT(jt.value, ''$.refTypeValue'')) AS RefTypeValue
            FROM JSON_TABLE(
                ?, ''$[*]''
                COLUMNS(value JSON PATH ''$'')
            ) AS jt';
        
        PREPARE stmt_insert FROM @insert_sql;
        SET @json_param = p_conditions_json;
        EXECUTE stmt_insert USING @json_param;
        DEALLOCATE PREPARE stmt_insert;
        
        -- Đếm số conditions cần match
        SELECT COUNT(*) INTO @condition_count FROM tmp_filter_conditions;
        
        -- Thêm điều kiện: Master phải có TẤT CẢ conditions trong filter
        SET @sql = CONCAT(@sql, '
            AND (
                SELECT COUNT(DISTINCT CONCAT(mc.RefTypeId, ''|'', mc.RefTypeValue))
                FROM compl_master_conditions mc
                INNER JOIN tmp_filter_conditions tfc 
                    ON mc.RefTypeId = tfc.RefTypeId 
                    AND mc.RefTypeValue = tfc.RefTypeValue
                WHERE mc.MasterId = cd.Id
            ) = ', @condition_count, '
        ');
    END IF;

    -- ========== OTHER FILTERS ==========
    
    -- SEARCH LOGIC
    IF p_search_text IS NOT NULL AND p_search_text <> '' THEN
        IF v_use_fulltext THEN
            SET @sql = CONCAT(@sql, ' AND MATCH(cd.Name, cd.Code, cd.Description) AGAINST (''', 
                             v_search_escaped, 
                             ''' IN BOOLEAN MODE)');
        ELSE
            SET v_search_escaped = REPLACE(REPLACE(p_search_text, '\\', '\\\\'), '''', '''''');
            SET @sql = CONCAT(@sql, ' AND (cd.Code LIKE ''%', 
                             v_search_escaped, '%'' ',
                             'OR cd.Name LIKE ''%', 
                             v_search_escaped, '%'' ',
                             'OR cd.Description LIKE ''%', 
                             v_search_escaped, '%'')');
        END IF;
    END IF;

    -- DUE DAYS FILTER
    IF p_due_days IS NOT NULL THEN
        SET @sql = CONCAT(@sql, ' AND cd.ValidTo IS NOT NULL AND cd.ValidTo <= DATE_ADD(UTC_TIMESTAMP(), INTERVAL ', 
                         p_due_days, ' DAY)');
    END IF;
    
    -- USER EMAIL FILTER
    IF p_user_email IS NOT NULL AND p_user_email <> '' THEN
        SET @sql = CONCAT(@sql, ' AND (
            cd.CreatedBy = ''', REPLACE(p_user_email, '''', ''''''), '''
            OR EXISTS (
                SELECT 1 
                FROM compl_master_group_email cmge
                INNER JOIN compl_group_email_detail cged 
                    ON cged.GroupEmailId = cmge.GroupEmailId
                WHERE cmge.MasterId = cd.Id
                  AND cged.IsActive = TRUE
                  AND cged.ResponseEmail = ''', REPLACE(p_user_email, '''', ''''''), '''
            )
        )');
    END IF;
            
    -- GROUP BY
    SET @sql = CONCAT(@sql, '
        GROUP BY 
            cd.Id, cd.Name, cd.Code, cd.NumDayAlert,
            cd.ValidFrom, cd.ValidTo, cd.Description,
            cd.CreatedDate, cd.CreatedBy
    ');

    -- ORDER BY
    IF v_use_fulltext THEN
        SET @sql = CONCAT(@sql, ' ORDER BY relevance_score DESC, cd.Id DESC');
    ELSEIF p_order_column IS NOT NULL AND p_order_direction IS NOT NULL THEN
        SET @sql = CONCAT(@sql, ' ORDER BY ', p_order_column, ' ', 
                          CASE UPPER(p_order_direction) 
                               WHEN 'ASC' THEN 'ASC' 
                               WHEN 'DESC' THEN 'DESC' 
                               ELSE 'ASC' END);
    ELSE
        SET @sql = CONCAT(@sql, ' ORDER BY cd.Id DESC');
    END IF;

    -- LIMIT & OFFSET
    IF p_limit IS NOT NULL AND p_offset IS NOT NULL THEN
        SET @sql = CONCAT(@sql, ' LIMIT ', p_limit, ' OFFSET ', p_offset);
    END IF;

    -- Execute
    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
    
    -- Cleanup
    DROP TEMPORARY TABLE IF EXISTS tmp_filter_conditions;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `compl_sp_get_next_code` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `compl_sp_get_next_code`(IN p_prefix VARCHAR(20),  IN p_user_email VARCHAR(50), OUT p_code VARCHAR(50))
BEGIN
    DECLARE v_number INT;
    DECLARE v_separator CHAR(1);
    DECLARE v_paddingLength INT;

    START TRANSACTION;

    -- Khóa dòng tương ứng prefix
    SELECT Number, `Separator`, PaddingLength
    INTO v_number, v_separator, v_paddingLength
    FROM compl_code_sequences
    WHERE Prefix = p_prefix
    FOR UPDATE;

    -- Nếu không có prefix thì tạo mới
    IF v_number IS NULL THEN
        SET v_number = 1;
        SET v_separator = '-';
        SET v_paddingLength = 5;
        INSERT INTO compl_code_sequences(Prefix, `Separator`, Number, PaddingLength)
        VALUES (p_prefix, v_separator, v_number, v_paddingLength);
    ELSE
        -- Nếu có rồi thì tăng số lên
        SET v_number = v_number + 1;
        UPDATE compl_code_sequences
        SET Number = v_number
        WHERE Prefix = p_prefix;
    END IF;

    COMMIT;

    -- Sinh code hoàn chỉnh
    SET p_code = CONCAT(p_prefix, v_separator, LPAD(v_number, v_paddingLength, '0'));
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `compl_sp_get_pie_chart_dashboard` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `compl_sp_get_pie_chart_dashboard`(
    IN p_user_email VARCHAR(50)
)
BEGIN
    SELECT JSON_ARRAYAGG(
        JSON_OBJECT(
            'code', t.Code,
            'name', t.Name,
            'total', total_count,
            'compliant', active_count,
            'percentage',
                ROUND((active_count * 100.0) / NULLIF(total_count, 0), 1),
            'color',
                CASE t.Code
                    WHEN 'COUNTRY'      THEN '#7c92ff'
                    WHEN 'FACTORY'      THEN '#2196f3'
                    WHEN 'CUSTOMER'     THEN '#4caf50'
                    WHEN 'PRODUCT'      THEN '#ff9800'
                    WHEN 'MATERIAL'     THEN '#9c27b0'
                    WHEN 'PRODUCT_TYPE' THEN '#00bcd4'
                    WHEN 'VARIANT'      THEN '#795548'
                    WHEN 'ATTRIBUTE'    THEN '#607d8b'
                    WHEN 'COST_GROUP'   THEN '#e91e63'
                    ELSE '#9e9e9e'
                END
        )
    ) AS compliance_by_reference_type
    FROM
    (
        SELECT
            rt.Id            AS RefTypeId,
            rt.Code,
            rt.Name,
            COUNT(DISTINCT c.Id) AS total_count,
            SUM(
                CASE
                    WHEN c.ValidFrom <= NOW()
                     AND (c.ValidTo IS NULL OR c.ValidTo >= NOW())
                    THEN 1 ELSE 0
                END
            ) AS active_count
        FROM compl_reference_types rt
        JOIN compl_master_conditions mc
            ON mc.RefTypeId = rt.Id
        JOIN compl_masters m
            ON m.Id = mc.MasterId
        JOIN compl_references r
            ON r.MasterId = m.Id
        JOIN compl_compliances c
            ON c.Id = r.ComplianceId
        WHERE rt.IsActive = 1
          /* =========================
             USER PERMISSION FILTER
             ========================= */
          AND (
                p_user_email IS NULL
                OR c.CreatedBy = p_user_email
                OR EXISTS (
                    SELECT 1
                    FROM compl_compliance_group_email cge
                    JOIN compl_group_email_detail ged
                        ON ged.GroupEmailId = cge.GroupEmailId
                       AND ged.IsActive = 1
                    WHERE cge.ComplianceId = c.Id
                      AND cge.GroupType = 1 -- RespGroup
                      AND ged.ResponseEmail = p_user_email
                )
          )
        GROUP BY rt.Id, rt.Code, rt.Name
    ) t;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_audit_all_duplicate_conditions` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_audit_all_duplicate_conditions`()
BEGIN
    /*
        Quét toàn bộ các cặp master (A, B) và phát hiện conflict.
        Chỉ trả về cặp A.Id < B.Id để tránh hiển thị 2 lần.
    */

    SELECT
        cm_a.Id                 AS MasterA_Id,
        cm_a.Code               AS MasterA_Code,
        cm_a.Name               AS MasterA_Name,
        cm_b.Id                 AS MasterB_Id,
        cm_b.Code               AS MasterB_Code,
        cm_b.Name               AS MasterB_Name,
        crt.Code                AS RefTypeCode,
        crt.Name                AS RefTypeName,
        cmc_a.ComplType,
        GROUP_CONCAT(
            DISTINCT cmcv_a.RefTypeValue
            ORDER BY cmcv_a.RefTypeValue
            SEPARATOR ', '
        )                       AS ConflictValues,
        COUNT(DISTINCT cmcv_a.RefTypeValue) AS ConflictValueCount
    FROM compl_master_conditions  cmc_a
    JOIN compl_master_condition_values cmcv_a  ON cmc_a.Id        = cmcv_a.ConditionId
    JOIN compl_master_conditions       cmc_b   ON cmc_b.RefTypeId = cmc_a.RefTypeId
                                               AND cmc_b.ComplType = cmc_a.ComplType
                                               AND cmc_b.MasterId  > cmc_a.MasterId  -- tránh dup pair
    JOIN compl_master_condition_values cmcv_b  ON cmc_b.Id        = cmcv_b.ConditionId
                                               AND cmcv_b.RefTypeValue = cmcv_a.RefTypeValue
    JOIN compl_reference_types         crt     ON crt.Id           = cmc_a.RefTypeId
    JOIN compl_masters                 cm_a    ON cm_a.Id          = cmc_a.MasterId
                                               AND cm_a.IsDelete   = 0
    JOIN compl_masters                 cm_b    ON cm_b.Id          = cmc_b.MasterId
                                               AND cm_b.IsDelete   = 0
    GROUP BY
        cm_a.Id, cm_a.Code, cm_a.Name,
        cm_b.Id, cm_b.Code, cm_b.Name,
        crt.Code, crt.Name, cmc_a.ComplType
    ORDER BY
        cm_a.Id, cm_b.Id, crt.Code;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_get_unmapped_files_by_creator` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_get_unmapped_files_by_creator`(
    IN p_limit INT,
    IN p_offset INT,
    IN p_created_by VARCHAR(255)    
)
BEGIN
    SELECT 
        sf.FileId,
        sf.Name,
        sf.Size,
        CASE 
			WHEN ParentPath LIKE '%root:/%' 
			THEN SUBSTRING(ParentPath, LOCATE('root:/', ParentPath) + 6)
			ELSE ParentPath
		 END AS FolderSharePoint
    FROM compl_sharepoint_files sf
    WHERE (sf.CreatedBy = p_created_by OR p_created_by IS NULL)
      AND sf.IsMapped = 0
      AND NOT EXISTS (
          SELECT 1
          FROM compl_compliances c
          WHERE c.FileId = sf.FileId
            AND c.IsDelete = 0
      )
    ORDER BY sf.CreatedDate DESC
    LIMIT p_limit OFFSET p_offset;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_get_unmapped_files_by_creator_count` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_get_unmapped_files_by_creator_count`(
    IN p_created_by VARCHAR(255)  
)
BEGIN
    SELECT 
        COUNT(*) AS TotalCount
    FROM compl_sharepoint_files sf
    WHERE (sf.CreatedBy = p_created_by OR p_created_by IS NULL)
      AND sf.IsMapped = 0
      AND NOT EXISTS (
          SELECT 1
          FROM compl_compliances c
          WHERE c.FileId = sf.FileId
            AND c.IsDelete = 0
      );
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_load_compl_by_conditions` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_load_compl_by_conditions`(
    IN p_json_data JSON,
    IN p_check_date DATE
)
BEGIN
    SET p_check_date = COALESCE(p_check_date, CURDATE());

    -- ================================================================
    -- CLEANUP: Drop tất cả temp tables trước khi bắt đầu
    -- ================================================================
    DROP TEMPORARY TABLE IF EXISTS tmp_input_data;
    DROP TEMPORARY TABLE IF EXISTS tmp_input_eav;
    DROP TEMPORARY TABLE IF EXISTS tmp_input_country_groups;
    DROP TEMPORARY TABLE IF EXISTS tmp_cmcv_group;
    DROP TEMPORARY TABLE IF EXISTS tmp_var_group;
    DROP TEMPORARY TABLE IF EXISTS tmp_not_in_excluded;           -- [NOT IN]

    DROP TEMPORARY TABLE IF EXISTS tmp_valid_masters;
    DROP TEMPORARY TABLE IF EXISTS tmp_condition_group_match;
    DROP TEMPORARY TABLE IF EXISTS tmp_master_condition_counts;
    DROP TEMPORARY TABLE IF EXISTS tmp_master_input_match;
    DROP TEMPORARY TABLE IF EXISTS tmp_matched_masters;
    DROP TEMPORARY TABLE IF EXISTS tmp_all_references;
    DROP TEMPORARY TABLE IF EXISTS tmp_valid_references;
    DROP TEMPORARY TABLE IF EXISTS tmp_applied_rows;
    DROP TEMPORARY TABLE IF EXISTS tmp_expired_compliances;
    DROP TEMPORARY TABLE IF EXISTS tmp_expired_compliances_2;
    DROP TEMPORARY TABLE IF EXISTS tmp_distinct_input_values;
    DROP TEMPORARY TABLE IF EXISTS tmp_valid_applied_refs;
    DROP TEMPORARY TABLE IF EXISTS tmp_cmc_has_all;
    DROP TEMPORARY TABLE IF EXISTS tmp_missing_rows;
    DROP TEMPORARY TABLE IF EXISTS tmp_master_has_refs;
    DROP TEMPORARY TABLE IF EXISTS tmp_master_has_specific_cond;
    DROP TEMPORARY TABLE IF EXISTS tmp_master_has_applied;
    DROP TEMPORARY TABLE IF EXISTS tmp_master_missing_rows;
    DROP TEMPORARY TABLE IF EXISTS tmp_master_conditions_json;
    DROP TEMPORARY TABLE IF EXISTS tmp_group_email_detail_agg;
    DROP TEMPORARY TABLE IF EXISTS tmp_master_email_alert_json;
    DROP TEMPORARY TABLE IF EXISTS tmp_master_email_resp_json;
    DROP TEMPORARY TABLE IF EXISTS tmp_compliance_email_alert_json;
    DROP TEMPORARY TABLE IF EXISTS tmp_compliance_email_resp_json;
    DROP TEMPORARY TABLE IF EXISTS tmp_result;
    DROP TEMPORARY TABLE IF EXISTS tmp_hierarchy_descendants;
    DROP TEMPORARY TABLE IF EXISTS tmp_hierarchy_root_matches;

    -- ================================================================
    -- STEP 1: Parse JSON → tmp_input_data
    -- ================================================================
    CREATE TEMPORARY TABLE tmp_input_data AS
    SELECT
        ROW_NUMBER() OVER () AS LineNo,
        jt.*,
        jt.Country        AS COUNTRY_v,
        jt.Customer       AS CUSTOMER_v,
        jt.Factory        AS FACTORY_v,
        jt.Product        AS PRODUCT_v,
        jt.ProductType    AS PRODUCT_TYPE_v,
        jt.Variant        AS VARIANT_v,
        jt.Material       AS MATERIAL_v,
        jt.CostGroup      AS COST_GROUP_v,
        jt.Attribute      AS ATTRIBUTE_v,
        jt.MaterialType   AS MATERIAL_TYPE_v,
        jt.AttributeGroup AS ATTRIBUTE_GROUP_v
    FROM JSON_TABLE(
        p_json_data,
        '$[*]' COLUMNS(
            Country        VARCHAR(50)  PATH '$.Country',
            Customer       VARCHAR(50)  PATH '$.Customer',
            Factory        VARCHAR(50)  PATH '$.Factory',
            Product        VARCHAR(50)  PATH '$.Product',
            ProductType    VARCHAR(100) PATH '$.ProductType',
            Variant        VARCHAR(50)  PATH '$.Variant',
            Material       VARCHAR(50)  PATH '$.Material',
            CostGroup      VARCHAR(50)  PATH '$.CostGroup',
            Attribute      VARCHAR(100) PATH '$.Attribute',
            MaterialType   VARCHAR(50)  PATH '$.MaterialType',
            AttributeGroup VARCHAR(100) PATH '$.AttributeGroup'
        )
    ) AS jt;

    ALTER TABLE tmp_input_data
        ADD INDEX idx_pvc (Product, Variant, Customer);

    -- ================================================================
    -- STEP 1b: EAV — pivot input fields thành dạng (FieldCode, FieldValue)
    -- ================================================================
    CREATE TEMPORARY TABLE tmp_input_eav (
        Product        VARCHAR(50),
        Variant        VARCHAR(50),
        Customer       VARCHAR(50),
        FieldCode      VARCHAR(50),
        FieldValue     VARCHAR(100)
    );

    INSERT INTO tmp_input_eav SELECT DISTINCT Product, Variant, Customer, 'COUNTRY',         COUNTRY_v         FROM tmp_input_data WHERE COUNTRY_v         IS NOT NULL AND COUNTRY_v         != '';
    INSERT INTO tmp_input_eav SELECT DISTINCT Product, Variant, Customer, 'CUSTOMER',        CUSTOMER_v        FROM tmp_input_data WHERE CUSTOMER_v        IS NOT NULL AND CUSTOMER_v        != '';
    INSERT INTO tmp_input_eav SELECT DISTINCT Product, Variant, Customer, 'FACTORY',         FACTORY_v         FROM tmp_input_data WHERE FACTORY_v         IS NOT NULL AND FACTORY_v         != '';
    INSERT INTO tmp_input_eav SELECT DISTINCT Product, Variant, Customer, 'PRODUCT',         PRODUCT_v         FROM tmp_input_data WHERE PRODUCT_v         IS NOT NULL AND PRODUCT_v         != '';
    INSERT INTO tmp_input_eav SELECT DISTINCT Product, Variant, Customer, 'PRODUCT_TYPE',    PRODUCT_TYPE_v    FROM tmp_input_data WHERE PRODUCT_TYPE_v    IS NOT NULL AND PRODUCT_TYPE_v    != '';
    INSERT INTO tmp_input_eav SELECT DISTINCT Product, Variant, Customer, 'VARIANT',         VARIANT_v         FROM tmp_input_data WHERE VARIANT_v         IS NOT NULL AND VARIANT_v         != '';
    INSERT INTO tmp_input_eav SELECT DISTINCT Product, Variant, Customer, 'MATERIAL',        MATERIAL_v        FROM tmp_input_data WHERE MATERIAL_v        IS NOT NULL AND MATERIAL_v        != '';
    INSERT INTO tmp_input_eav SELECT DISTINCT Product, Variant, Customer, 'COST_GROUP',      COST_GROUP_v      FROM tmp_input_data WHERE COST_GROUP_v      IS NOT NULL AND COST_GROUP_v      != '';
    INSERT INTO tmp_input_eav SELECT DISTINCT Product, Variant, Customer, 'ATTRIBUTE',       ATTRIBUTE_v       FROM tmp_input_data WHERE ATTRIBUTE_v       IS NOT NULL AND ATTRIBUTE_v       != '';
    INSERT INTO tmp_input_eav SELECT DISTINCT Product, Variant, Customer, 'MATERIAL_TYPE',   MATERIAL_TYPE_v   FROM tmp_input_data WHERE MATERIAL_TYPE_v   IS NOT NULL AND MATERIAL_TYPE_v   != '';
    INSERT INTO tmp_input_eav SELECT DISTINCT Product, Variant, Customer, 'ATTRIBUTE_GROUP', ATTRIBUTE_GROUP_v FROM tmp_input_data WHERE ATTRIBUTE_GROUP_v  IS NOT NULL AND ATTRIBUTE_GROUP_v != '';

    ALTER TABLE tmp_input_eav
        ADD INDEX idx_field (FieldCode, FieldValue(100)),
        ADD INDEX idx_pvc   (Product, Variant, Customer);

    -- ================================================================
    -- STEP 2: Latest valid masters
    -- ================================================================
    CREATE TEMPORARY TABLE tmp_valid_masters AS
    SELECT *
    FROM (
        SELECT
            cm.*,
            ROW_NUMBER() OVER (
                PARTITION BY cm.Code
                ORDER BY cm.ValidFrom DESC, cm.Id DESC
            ) AS rn
        FROM compl_masters cm
        WHERE cm.IsDelete = 0
          AND p_check_date BETWEEN cm.ValidFrom AND COALESCE(cm.ValidTo, '2099-12-31')
    ) t
    WHERE rn = 1;

    ALTER TABLE tmp_valid_masters
        ADD PRIMARY KEY (Id),
        ADD INDEX idx_code (Code);

    -- ================================================================
    -- STEP 2b: Build country → group code lookup từ input
    -- ================================================================
    CREATE TEMPORARY TABLE tmp_input_country_groups AS
    SELECT DISTINCT
        eav.FieldValue   AS CountryCode,
        cg.Code          AS GroupCode
    FROM tmp_input_eav eav
    INNER JOIN compl_country_group_members cgm
            ON cgm.CountryCode = eav.FieldValue
    INNER JOIN compl_country_groups cg
            ON cg.Id       = cgm.GroupId
           AND cg.IsActive = 1
    WHERE eav.FieldCode = 'COUNTRY';

    ALTER TABLE tmp_input_country_groups
        ADD INDEX idx_country (CountryCode),
        ADD INDEX idx_group   (GroupCode);

    -- ================================================================
    -- STEP 2c [NOT IN]: Materialize các tổ hợp (ConditionId, Product,
    --   Variant, Customer) bị LOẠI TRỪ bởi NOT IN conditions.
    --
    --   Tại sao cần bước này?
    --     NOT IN condition khớp khi input value KHÔNG nằm trong list.
    --     Không thể dùng NOT EXISTS trên temp table trong CREATE TEMPORARY
    --     TABLE khác (MySQL Error 1137) → phải materialize trước.
    --
    --   Hai nguồn loại trừ:
    --     1. Exact value : cmcv.RefTypeValue = eav.FieldValue
    --     2. Group match : chỉ áp dụng cho COUNTRY
    --                      (eav.FieldValue thuộc group trong cmcv.RefTypeValue)
    -- ================================================================
    CREATE TEMPORARY TABLE tmp_not_in_excluded (          -- [NOT IN]
        ConditionId BIGINT,
        MasterId    BIGINT,
        Product     VARCHAR(50),
        Variant     VARCHAR(50),
        Customer    VARCHAR(50)
    );

    -- [NOT IN] Nguồn 1: Loại trừ theo exact value
    --   VD: Country NOT IN ('AGO','ANT') → loại (P,V,C) có Country = 'AGO' hoặc 'ANT'
    INSERT INTO tmp_not_in_excluded
    SELECT DISTINCT
        cmc.Id   AS ConditionId,
        cmc.MasterId,
        eav.Product,
        eav.Variant,
        eav.Customer
    FROM compl_master_condition_values cmcv
    INNER JOIN compl_master_conditions cmc
            ON cmc.Id       = cmcv.ConditionId
           AND cmc.Operator = 'NOT IN'
           AND cmc.ComplType IN (0, 1)
    INNER JOIN tmp_valid_masters vm ON vm.Id = cmc.MasterId
    INNER JOIN compl_reference_types crt ON crt.Id = cmc.RefTypeId
    INNER JOIN tmp_input_eav eav
            ON eav.FieldCode  = crt.Code
           AND eav.FieldValue = cmcv.RefTypeValue;

    -- [NOT IN] Nguồn 2: Loại trừ theo group code (chỉ COUNTRY)
    --   VD: Country NOT IN ('EU') → loại (P,V,C) có Country thuộc group EU
    INSERT INTO tmp_not_in_excluded
    SELECT DISTINCT
        cmc.Id   AS ConditionId,
        cmc.MasterId,
        eav.Product,
        eav.Variant,
        eav.Customer
    FROM compl_master_condition_values cmcv
    INNER JOIN compl_master_conditions cmc
            ON cmc.Id       = cmcv.ConditionId
           AND cmc.Operator = 'NOT IN'
           AND cmc.ComplType IN (0, 1)
    INNER JOIN tmp_valid_masters vm ON vm.Id = cmc.MasterId
    INNER JOIN compl_reference_types crt
            ON crt.Id   = cmc.RefTypeId
           AND crt.Code = 'COUNTRY'
    INNER JOIN tmp_input_country_groups icg ON icg.GroupCode = cmcv.RefTypeValue
    INNER JOIN tmp_input_eav eav
            ON eav.FieldCode  = 'COUNTRY'
           AND eav.FieldValue = icg.CountryCode;

    ALTER TABLE tmp_not_in_excluded                       -- [NOT IN]
        ADD INDEX idx_cond_pvc (ConditionId, Product, Variant, Customer);

    -- ================================================================
    -- STEP 3: Condition match — EAV JOIN
    --   [NOT IN FIX] Không dùng UNION trong CREATE TEMPORARY TABLE vì
    --   MySQL Error 1137 khi tmp_input_eav (alias 'eav') bị mở 2 lần.
    --   Giải pháp: CREATE từ nhánh IN/= trước, sau đó INSERT nhánh NOT IN.
    --
    --   Nhánh 1 — CREATE (IN / = / mặc định): giữ nguyên logic cũ.
    --     Thêm AND cmc.Operator != 'NOT IN' để loại NOT IN ra khỏi nhánh này.
    --
    --   Nhánh 2 — INSERT [NOT IN]: condition được coi là KHỚP khi tổ hợp
    --     (ConditionId, Product, Variant, Customer) KHÔNG có trong
    --     tmp_not_in_excluded (input value không nằm trong danh sách loại trừ).
    -- ================================================================

    -- ── Nhánh 1: CREATE từ IN / = operators (giữ nguyên logic) ─────
    CREATE TEMPORARY TABLE tmp_condition_group_match AS
    SELECT DISTINCT
        eav.Product,
        eav.Variant,
        eav.Customer,
        cmc.MasterId,
        cmc.Id AS ConditionId
    FROM tmp_input_eav eav
    INNER JOIN compl_reference_types crt
            ON crt.Code = eav.FieldCode
    INNER JOIN compl_master_conditions cmc
            ON cmc.RefTypeId = crt.Id
           AND cmc.ComplType IN (0, 1)
           AND cmc.Operator != 'NOT IN'                   -- [NOT IN] Loại NOT IN ra khỏi nhánh này
    INNER JOIN tmp_valid_masters vm
            ON vm.Id = cmc.MasterId
    INNER JOIN compl_master_condition_values cmcv
            ON cmcv.ConditionId = cmc.Id
           AND (
                   cmcv.RefTypeValue = eav.FieldValue
                OR cmcv.RefTypeValue = 'ALL'
                OR (
                       crt.Code = 'COUNTRY'
                   AND EXISTS (
                           SELECT 1
                           FROM tmp_input_country_groups icg
                           WHERE icg.CountryCode = eav.FieldValue
                             AND icg.GroupCode   = cmcv.RefTypeValue
                       )
                   )
               );

    -- ── Nhánh 2: INSERT NOT IN operator [MỚI] ───────────────────────
    -- Tách INSERT riêng để tránh Error 1137 (tmp_input_eav mở 2 lần).
    -- Condition NOT IN khớp khi (ConditionId, P, V, C) KHÔNG bị loại trừ.
    INSERT INTO tmp_condition_group_match
    SELECT DISTINCT
        eav.Product,
        eav.Variant,
        eav.Customer,
        cmc.MasterId,
        cmc.Id AS ConditionId
    FROM tmp_input_eav eav
    INNER JOIN compl_reference_types crt
            ON crt.Code = eav.FieldCode
    INNER JOIN compl_master_conditions cmc
            ON cmc.RefTypeId = crt.Id
           AND cmc.Operator  = 'NOT IN'                   -- [NOT IN] Chỉ xử lý NOT IN
           AND cmc.ComplType IN (0, 1)
    INNER JOIN tmp_valid_masters vm
            ON vm.Id = cmc.MasterId
    LEFT JOIN tmp_not_in_excluded nie                     -- [NOT IN] Check bị loại trừ không?
           ON nie.ConditionId = cmc.Id
          AND nie.Product     = eav.Product
          AND nie.Variant     = eav.Variant
          AND nie.Customer    = eav.Customer
    WHERE nie.ConditionId IS NULL;                        -- [NOT IN] Không bị loại trừ → khớp

    ALTER TABLE tmp_condition_group_match
        ADD INDEX idx_lookup  (MasterId, Product, Variant, Customer, ConditionId),
        ADD INDEX idx_lookup2 (Product, Variant, Customer, MasterId);

    -- ================================================================
    -- STEP 4: Count AND / OR conditions per master
    -- (giữ nguyên — NOT IN vẫn tính vào total_and / total_or bình thường)
    -- ================================================================
    CREATE TEMPORARY TABLE tmp_master_condition_counts AS
    SELECT
        cmc.MasterId,
        SUM(cmc.Logical = 1) AS total_and,
        SUM(cmc.Logical = 2) AS total_or
    FROM compl_master_conditions cmc
    INNER JOIN tmp_valid_masters vm ON vm.Id = cmc.MasterId
    GROUP BY cmc.MasterId;

    ALTER TABLE tmp_master_condition_counts
        ADD PRIMARY KEY (MasterId);

    -- ================================================================
    -- STEP 5: Count AND / OR matched per (master, product, variant, customer)
    -- (giữ nguyên)
    -- ================================================================
    CREATE TEMPORARY TABLE tmp_master_input_match AS
    SELECT
        cgm.MasterId,
        cgm.Product,
        cgm.Variant,
        cgm.Customer,
        SUM(cmc.Logical = 1) AS and_matched,
        SUM(cmc.Logical = 2) AS or_matched
    FROM tmp_condition_group_match cgm
    INNER JOIN compl_master_conditions cmc
           ON cmc.Id       = cgm.ConditionId
          AND cmc.MasterId = cgm.MasterId
    GROUP BY cgm.MasterId, cgm.Product, cgm.Variant, cgm.Customer;

    ALTER TABLE tmp_master_input_match
        ADD INDEX idx_match (MasterId, Product, Variant, Customer);

    -- ================================================================
    -- STEP 6: Final match — logic AND / OR / no-condition giữ nguyên
    -- ================================================================
    CREATE TEMPORARY TABLE tmp_matched_masters AS
    SELECT DISTINCT
        inp.*,
        vm.Id          AS MasterId,
        vm.Code        AS MasterCode,
        vm.Name        AS MasterName,
        vm.IsIndividual
    FROM tmp_input_data inp
    INNER JOIN tmp_master_input_match mim
           ON mim.Product  = inp.Product
          AND mim.Variant  = inp.Variant
          AND mim.Customer = inp.Customer
    INNER JOIN tmp_valid_masters vm
           ON vm.Id = mim.MasterId
    LEFT JOIN tmp_master_condition_counts mcc
           ON mcc.MasterId = vm.Id
    WHERE
        (mcc.total_and > 0 AND mim.and_matched = mcc.total_and)
        OR (mcc.total_or  > 0 AND mim.or_matched  > 0)
        OR  mcc.MasterId IS NULL;

    -- ================================================================
    -- STEP 7: All references + tính sẵn ResolvedFieldValue
    -- (giữ nguyên)
    -- ================================================================
    CREATE TEMPORARY TABLE tmp_all_references AS
    SELECT
        mm.*,
        cr.Id            AS RefId,
        cr.ComplianceId,
        cr.ComplType,
        cr.RefTypeId,
        cr.RefTypeValue,
        CASE crt.Code
            WHEN 'COUNTRY'         THEN mm.COUNTRY_v
            WHEN 'CUSTOMER'        THEN mm.CUSTOMER_v
            WHEN 'FACTORY'         THEN mm.FACTORY_v
            WHEN 'PRODUCT'         THEN mm.PRODUCT_v
            WHEN 'PRODUCT_TYPE'    THEN mm.PRODUCT_TYPE_v
            WHEN 'VARIANT'         THEN mm.VARIANT_v
            WHEN 'MATERIAL'        THEN mm.MATERIAL_v
            WHEN 'COST_GROUP'      THEN mm.COST_GROUP_v
            WHEN 'ATTRIBUTE'       THEN mm.ATTRIBUTE_v
            WHEN 'MATERIAL_TYPE'   THEN mm.MATERIAL_TYPE_v
            WHEN 'ATTRIBUTE_GROUP' THEN mm.ATTRIBUTE_GROUP_v
        END AS ResolvedFieldValue,
        crt.Code AS RefTypeCode
    FROM tmp_matched_masters mm
    LEFT JOIN compl_references cr
           ON cr.MasterId = mm.MasterId
    LEFT JOIN compl_reference_types crt
           ON crt.Id = cr.RefTypeId;

    ALTER TABLE tmp_all_references
        ADD INDEX idx_master   (MasterId),
        ADD INDEX idx_ref      (RefId),
        ADD INDEX idx_compl    (ComplianceId);

    -- ================================================================
    -- STEP 8: Validate references
    -- (giữ nguyên — references không bị ảnh hưởng bởi NOT IN condition
    --  vì NOT IN là điều kiện loại trừ ở tầng master matching, không phải
    --  reference matching)
    -- ================================================================
    CREATE TEMPORARY TABLE tmp_valid_references AS
    SELECT
        ar.*,
        CASE
            WHEN ar.RefId IS NULL THEN 0
            WHEN ar.ComplType = 0 THEN 1
            WHEN ar.ComplType = 1 AND ar.RefTypeId IS NOT NULL AND ar.RefTypeValue IS NOT NULL THEN
                CASE
                    WHEN ar.RefTypeValue = 'ALL'
                         AND ar.ResolvedFieldValue IS NOT NULL
                         AND ar.ResolvedFieldValue != ''            THEN 1
                    WHEN ar.ResolvedFieldValue = ar.RefTypeValue    THEN 1
                    WHEN ar.RefTypeCode = 'COUNTRY'
                         AND ar.ResolvedFieldValue IS NOT NULL
                         AND ar.ResolvedFieldValue != ''
                         AND EXISTS (
                                 SELECT 1
                                 FROM tmp_input_country_groups icg
                                 WHERE icg.CountryCode = ar.ResolvedFieldValue
                                   AND icg.GroupCode   = ar.RefTypeValue
                             )                                      THEN 1
                    ELSE 0
                END
            ELSE 0
        END AS IsValidReference,
        '' AS ConditionsJson
    FROM tmp_all_references ar;

    ALTER TABLE tmp_valid_references
        ADD INDEX idx_master_valid (MasterId, IsValidReference),
        ADD INDEX idx_compl_valid  (ComplianceId, IsValidReference);

    -- ================================================================
    -- STEP 9: Expired compliances
    -- (giữ nguyên)
    -- ================================================================
    CREATE TEMPORARY TABLE tmp_expired_compliances AS
    SELECT
        cr.MasterId,
        cr.RefTypeId,
        cr.RefTypeValue,
        cr.ComplType AS RefComplType,
        cc.Id        AS ExpiredComplianceId,
        ROW_NUMBER() OVER (
            PARTITION BY cr.MasterId, cr.RefTypeValue
            ORDER BY cc.ValidTo DESC
        ) AS rn
    FROM compl_references cr
    INNER JOIN compl_compliances cc
            ON cr.ComplianceId = cc.Id
           AND cc.IsDelete = 0
           AND DATE(cc.ValidTo) < p_check_date;

    CREATE TEMPORARY TABLE tmp_expired_compliances_2 AS
    SELECT * FROM tmp_expired_compliances;

    -- ================================================================
    -- STEP 10: Applied rows (compliance đang valid)
    -- (giữ nguyên)
    -- ================================================================
    CREATE TEMPORARY TABLE tmp_applied_rows AS
    SELECT
        vr.MasterId,
        cc.Id AS ComplianceId,
        ROW_NUMBER() OVER (
            PARTITION BY vr.MasterId, COALESCE(vr.RefTypeValue, '')
            ORDER BY cc.VersionNo DESC, cc.Id DESC
        ) AS rn,
        vr.RefTypeId    AS MappedRefTypeId,
        crt_map.Code    AS MappedRefTypeCode,
        crt_map.Name    AS MappedRefTypeName,
        vr.RefTypeValue AS MappedInputValue
    FROM tmp_valid_references vr
    INNER JOIN compl_compliances cc
            ON vr.ComplianceId = cc.Id
           AND cc.IsDelete = 0
           AND p_check_date >= DATE(cc.ValidFrom)
           AND p_check_date <= DATE(COALESCE(cc.ValidTo, '2099-12-31'))
    LEFT JOIN compl_reference_types crt_map
           ON crt_map.Id = vr.RefTypeId
    WHERE vr.IsValidReference = 1;

    ALTER TABLE tmp_applied_rows
        ADD INDEX idx_master_rn (MasterId, rn);

    -- ================================================================
    -- STEP 11: Distinct input values per (master, refType) — IsIndividual=1
    -- (giữ nguyên)
    -- ================================================================
    CREATE TEMPORARY TABLE tmp_distinct_input_values AS
    SELECT DISTINCT
        mm.MasterId,
        cmc.RefTypeId,
        CASE crt.Code
            WHEN 'COUNTRY'         THEN mm.COUNTRY_v
            WHEN 'CUSTOMER'        THEN mm.CUSTOMER_v
            WHEN 'FACTORY'         THEN mm.FACTORY_v
            WHEN 'PRODUCT'         THEN mm.PRODUCT_v
            WHEN 'PRODUCT_TYPE'    THEN mm.PRODUCT_TYPE_v
            WHEN 'VARIANT'         THEN mm.VARIANT_v
            WHEN 'MATERIAL'        THEN mm.MATERIAL_v
            WHEN 'COST_GROUP'      THEN mm.COST_GROUP_v
            WHEN 'ATTRIBUTE'       THEN mm.ATTRIBUTE_v
            WHEN 'MATERIAL_TYPE'   THEN mm.MATERIAL_TYPE_v
            WHEN 'ATTRIBUTE_GROUP' THEN mm.ATTRIBUTE_GROUP_v
        END AS InputValue
    FROM tmp_matched_masters mm
    INNER JOIN compl_master_conditions cmc
            ON cmc.MasterId = mm.MasterId AND cmc.ComplType = 1
    INNER JOIN compl_reference_types crt
            ON crt.Id = cmc.RefTypeId
    WHERE mm.IsIndividual = 1
      AND CASE crt.Code
              WHEN 'COUNTRY'         THEN mm.COUNTRY_v
              WHEN 'CUSTOMER'        THEN mm.CUSTOMER_v
              WHEN 'FACTORY'         THEN mm.FACTORY_v
              WHEN 'PRODUCT'         THEN mm.PRODUCT_v
              WHEN 'PRODUCT_TYPE'    THEN mm.PRODUCT_TYPE_v
              WHEN 'VARIANT'         THEN mm.VARIANT_v
              WHEN 'MATERIAL'        THEN mm.MATERIAL_v
              WHEN 'COST_GROUP'      THEN mm.COST_GROUP_v
              WHEN 'ATTRIBUTE'       THEN mm.ATTRIBUTE_v
              WHEN 'MATERIAL_TYPE'   THEN mm.MATERIAL_TYPE_v
              WHEN 'ATTRIBUTE_GROUP' THEN mm.ATTRIBUTE_GROUP_v
          END IS NOT NULL
      AND CASE crt.Code
              WHEN 'COUNTRY'         THEN mm.COUNTRY_v
              WHEN 'CUSTOMER'        THEN mm.CUSTOMER_v
              WHEN 'FACTORY'         THEN mm.FACTORY_v
              WHEN 'PRODUCT'         THEN mm.PRODUCT_v
              WHEN 'PRODUCT_TYPE'    THEN mm.PRODUCT_TYPE_v
              WHEN 'VARIANT'         THEN mm.VARIANT_v
              WHEN 'MATERIAL'        THEN mm.MATERIAL_v
              WHEN 'COST_GROUP'      THEN mm.COST_GROUP_v
              WHEN 'ATTRIBUTE'       THEN mm.ATTRIBUTE_v
              WHEN 'MATERIAL_TYPE'   THEN mm.MATERIAL_TYPE_v
              WHEN 'ATTRIBUTE_GROUP' THEN mm.ATTRIBUTE_GROUP_v
          END != '';

    ALTER TABLE tmp_distinct_input_values
        ADD INDEX idx_master_ref (MasterId, RefTypeId);

    -- ================================================================
    -- STEP 12: Pre-aggregate lookups
    -- ================================================================

    -- 12a. Conditions có RefTypeValue = 'ALL' (giữ nguyên)
    CREATE TEMPORARY TABLE tmp_cmc_has_all AS
    SELECT DISTINCT ConditionId
    FROM compl_master_condition_values
    WHERE RefTypeValue = 'ALL';

    ALTER TABLE tmp_cmc_has_all ADD PRIMARY KEY (ConditionId);

    -- 12b. Compliance đang valid (giữ nguyên)
    CREATE TEMPORARY TABLE tmp_valid_applied_refs AS
    SELECT DISTINCT
        cr.MasterId,
        cr.RefTypeId,
        cr.RefTypeValue
    FROM compl_references cr
    INNER JOIN compl_compliances cc
            ON cc.Id = cr.ComplianceId
           AND cc.IsDelete = 0
           AND p_check_date BETWEEN DATE(cc.ValidFrom)
                                AND DATE(COALESCE(cc.ValidTo, '2099-12-31'));

    ALTER TABLE tmp_valid_applied_refs
        ADD INDEX idx_lookup (MasterId, RefTypeId, RefTypeValue(100));

    -- 12c: Condition value khớp qua group (giữ nguyên)
    DROP TEMPORARY TABLE IF EXISTS tmp_cmcv_group;
    CREATE TEMPORARY TABLE tmp_cmcv_group AS
    SELECT
        cmcv_g.ConditionId,
        icg.CountryCode
    FROM compl_master_condition_values cmcv_g
    INNER JOIN tmp_input_country_groups icg
            ON icg.GroupCode = cmcv_g.RefTypeValue;

    ALTER TABLE tmp_cmcv_group
        ADD INDEX idx_cond_country (ConditionId, CountryCode(20));

    -- 12d: Compliance đang valid khớp qua group (giữ nguyên)
    DROP TEMPORARY TABLE IF EXISTS tmp_var_group;
    CREATE TEMPORARY TABLE tmp_var_group AS
    SELECT
        var_g.MasterId,
        var_g.RefTypeId,
        icg.CountryCode
    FROM tmp_valid_applied_refs var_g
    INNER JOIN tmp_input_country_groups icg
            ON icg.GroupCode = var_g.RefTypeValue;

    ALTER TABLE tmp_var_group
        ADD INDEX idx_lookup (MasterId, RefTypeId, CountryCode(20));

    -- ================================================================
    -- STEP 13: Missing rows per input value (IsIndividual = 1)
    -- (giữ nguyên)
    -- ================================================================
    CREATE TEMPORARY TABLE tmp_missing_rows AS
    SELECT
        mm.MasterId,
        dv.InputValue AS missing_input_value,
        cmc.RefTypeId AS MappedRefTypeId,
        crt.Code      AS MappedRefTypeCode,
        crt.Name      AS MappedRefTypeName
    FROM tmp_matched_masters mm
    INNER JOIN compl_master_conditions cmc
            ON cmc.MasterId = mm.MasterId AND cmc.ComplType = 1
    INNER JOIN compl_reference_types crt
            ON crt.Id = cmc.RefTypeId
    INNER JOIN tmp_distinct_input_values dv
            ON dv.MasterId  = mm.MasterId
           AND dv.RefTypeId = cmc.RefTypeId
    LEFT JOIN tmp_cmc_has_all ha
           ON ha.ConditionId = cmc.Id
    LEFT JOIN compl_master_condition_values cmcv_exact
           ON cmcv_exact.ConditionId  = cmc.Id
          AND cmcv_exact.RefTypeValue = dv.InputValue
    LEFT JOIN tmp_cmcv_group cmcv_grp
           ON cmcv_grp.ConditionId = cmc.Id
          AND cmcv_grp.CountryCode = dv.InputValue
          AND crt.Code             = 'COUNTRY'
    LEFT JOIN tmp_valid_applied_refs var_exact
           ON var_exact.MasterId     = mm.MasterId
          AND var_exact.RefTypeId    = cmc.RefTypeId
          AND var_exact.RefTypeValue = dv.InputValue
    LEFT JOIN tmp_var_group var_grp
           ON var_grp.MasterId    = mm.MasterId
          AND var_grp.RefTypeId   = cmc.RefTypeId
          AND var_grp.CountryCode = dv.InputValue
          AND crt.Code            = 'COUNTRY'
    WHERE mm.IsIndividual = 1
      AND (
              ha.ConditionId        IS NOT NULL
          OR  cmcv_exact.ConditionId IS NOT NULL
          OR  cmcv_grp.ConditionId   IS NOT NULL
          )
      AND var_exact.MasterId IS NULL
      AND var_grp.MasterId   IS NULL
    GROUP BY
        mm.MasterId,
        dv.InputValue,
        cmc.RefTypeId,
        crt.Code,
        crt.Name;

    -- ================================================================
    -- STEP 14: Pre-aggregate lookups để thay EXISTS / NOT EXISTS
    -- (giữ nguyên)
    -- ================================================================
    CREATE TEMPORARY TABLE tmp_master_has_refs AS
    SELECT DISTINCT MasterId FROM compl_references;

    ALTER TABLE tmp_master_has_refs ADD PRIMARY KEY (MasterId);

    CREATE TEMPORARY TABLE tmp_master_has_specific_cond AS
    SELECT DISTINCT MasterId FROM compl_master_conditions WHERE ComplType = 1;

    ALTER TABLE tmp_master_has_specific_cond ADD PRIMARY KEY (MasterId);

    CREATE TEMPORARY TABLE tmp_master_has_applied AS
    SELECT DISTINCT MasterId FROM tmp_applied_rows WHERE rn = 1;

    ALTER TABLE tmp_master_has_applied ADD PRIMARY KEY (MasterId);

    -- ================================================================
    -- STEP 15: Master-level missing rows (IsIndividual = 0)
    -- (giữ nguyên)
    -- ================================================================
    -- Ép kiểu tường minh cho các cột NULL (thay vì để bare NULL) vì MySQL suy
    -- ra kiểu binary(0) cho cột NULL trần khi CREATE TABLE AS SELECT. Khi
    -- UNION ALL với tmp_applied_rows/tmp_missing_rows (bigint/varchar) ở
    -- STEP 20, kiểu binary(0) làm cột UNION bị ép về binary(20), gây lỗi
    -- 1292 "Truncated incorrect INTEGER value" khi CAST lại về UNSIGNED.
    CREATE TEMPORARY TABLE tmp_master_missing_rows AS
    SELECT
        mm.MasterId,
        CAST(NULL AS SIGNED)    AS MappedRefTypeId,
        CAST(NULL AS CHAR(20))  AS MappedRefTypeCode,
        CAST(NULL AS CHAR(100)) AS MappedRefTypeName,
        CAST(NULL AS CHAR(255)) AS MappedInputValue
    FROM tmp_matched_masters mm
    LEFT JOIN tmp_master_has_refs          hr  ON hr.MasterId  = mm.MasterId
    LEFT JOIN tmp_master_has_specific_cond sc  ON sc.MasterId  = mm.MasterId
    LEFT JOIN tmp_master_has_applied       ha  ON ha.MasterId  = mm.MasterId
    WHERE mm.IsIndividual = 0
      AND sc.MasterId IS NULL
      AND (
          hr.MasterId IS NULL
          OR
          (hr.MasterId IS NOT NULL AND ha.MasterId IS NULL)
      )
    GROUP BY mm.MasterId;

    -- ================================================================
    -- STEP 16: ConditionsJson per master
    -- (giữ nguyên)
    -- ================================================================
    DROP TEMPORARY TABLE IF EXISTS tmp_master_conditions_json;
    CREATE TEMPORARY TABLE tmp_master_conditions_json AS
    SELECT
        cmc.MasterId,
        JSON_ARRAYAGG(
            JSON_OBJECT(
                'id',           cmc.Id,
                'logical',      cmc.Logical,
                'operator',     cmc.Operator,
                'complType',    cmc.ComplType,
                'refTypeId',    cmc.RefTypeId,
                'displayType',    cmc.DisplayType,
                'logicalName',
                    CASE cmc.Logical
                        WHEN 1 THEN 'AND'
                        WHEN 2 THEN 'OR'
                        ELSE 'UNKNOWN'
                    END,
                'refTypeCode',     crt.Code,
                'refTypeName',     crt.Name,
                'conditionValues', cv.ConditionValuesJson
            )
        ) AS ConditionsJson
    FROM compl_master_conditions cmc
    LEFT JOIN compl_reference_types crt ON crt.Id = cmc.RefTypeId
    LEFT JOIN (
        SELECT
            cmcv.ConditionId,
            JSON_ARRAYAGG(
                JSON_OBJECT(
                    'id',                  cmcv.Id,
                    'ConditionId',         cmcv.ConditionId,
                    'refTypeValue',        cmcv.RefTypeValue,
                    'refTypeValueDisplay', cmcv.RefTypeValue
                )
            ) AS ConditionValuesJson
        FROM compl_master_condition_values cmcv
        GROUP BY cmcv.ConditionId
    ) cv ON cv.ConditionId = cmc.Id
    GROUP BY cmc.MasterId;

    -- ================================================================
    -- STEP 17: Pre-aggregate email detail
    -- (giữ nguyên)
    -- ================================================================
    CREATE TEMPORARY TABLE tmp_group_email_detail_agg AS
    SELECT
        GroupEmailId,
        JSON_ARRAYAGG(ResponseEmail) AS EmailsJson
    FROM compl_group_email_detail
    WHERE IsActive = TRUE
    GROUP BY GroupEmailId;

    ALTER TABLE tmp_group_email_detail_agg ADD PRIMARY KEY (GroupEmailId);

    -- ================================================================
    -- STEP 18: Email JSON per master
    -- (giữ nguyên)
    -- ================================================================
    DROP TEMPORARY TABLE IF EXISTS tmp_master_email_alert_json;
    CREATE TEMPORARY TABLE tmp_master_email_alert_json AS
    SELECT
        cmge.MasterId,
        cmge.GroupType,
        JSON_ARRAYAGG(
            JSON_OBJECT(
                'groupName', ge.Name,
                'emails',    ged_agg.EmailsJson
            )
        ) AS EmailJson
    FROM compl_master_group_email cmge
    JOIN compl_group_email ge ON ge.Id = cmge.GroupEmailId
    LEFT JOIN tmp_group_email_detail_agg ged_agg ON ged_agg.GroupEmailId = ge.Id
    WHERE cmge.GroupType = 2
    GROUP BY cmge.MasterId, cmge.GroupType;

    DROP TEMPORARY TABLE IF EXISTS tmp_master_email_resp_json;
    CREATE TEMPORARY TABLE tmp_master_email_resp_json AS
    SELECT
        cmge.MasterId,
        cmge.GroupType,
        JSON_ARRAYAGG(
            JSON_OBJECT(
                'groupName', ge.Name,
                'emails',    ged_agg.EmailsJson
            )
        ) AS EmailJson
    FROM compl_master_group_email cmge
    JOIN compl_group_email ge ON ge.Id = cmge.GroupEmailId
    LEFT JOIN tmp_group_email_detail_agg ged_agg ON ged_agg.GroupEmailId = ge.Id
    WHERE cmge.GroupType = 1
    GROUP BY cmge.MasterId, cmge.GroupType;

    -- ================================================================
    -- STEP 19: Email JSON per compliance
    -- (giữ nguyên)
    -- ================================================================
    DROP TEMPORARY TABLE IF EXISTS tmp_compliance_email_alert_json;
    CREATE TEMPORARY TABLE tmp_compliance_email_alert_json AS
    SELECT
        cmge.ComplianceId,
        cmge.GroupType,
        JSON_ARRAYAGG(
            JSON_OBJECT(
                'groupName', ge.Name,
                'emails',    ged_agg.EmailsJson
            )
        ) AS EmailJson
    FROM compl_compliance_group_email cmge
    JOIN compl_group_email ge ON ge.Id = cmge.GroupEmailId
    LEFT JOIN tmp_group_email_detail_agg ged_agg ON ged_agg.GroupEmailId = ge.Id
    WHERE cmge.GroupType = 2
    GROUP BY cmge.ComplianceId, cmge.GroupType;

    DROP TEMPORARY TABLE IF EXISTS tmp_compliance_email_resp_json;
    CREATE TEMPORARY TABLE tmp_compliance_email_resp_json AS
    SELECT
        cmge.ComplianceId,
        cmge.GroupType,
        JSON_ARRAYAGG(
            JSON_OBJECT(
                'groupName', ge.Name,
                'emails',    ged_agg.EmailsJson
            )
        ) AS EmailJson
    FROM compl_compliance_group_email cmge
    JOIN compl_group_email ge ON ge.Id = cmge.GroupEmailId
    LEFT JOIN tmp_group_email_detail_agg ged_agg ON ged_agg.GroupEmailId = ge.Id
    WHERE cmge.GroupType = 1
    GROUP BY cmge.ComplianceId, cmge.GroupType;

    -- ================================================================
    -- STEP 20: Materialize kết quả UNION 3 streams vào tmp_result
    --   (trước đây SELECT thẳng ra client — nay cần giữ lại trong bảng
    --   tạm để STEP 20b có thể lọc bớt dòng theo cây phân cấp Master
    --   trước khi trả kết quả cuối cùng ở STEP 21)
    -- ================================================================
	DROP TEMPORARY TABLE IF EXISTS tmp_result;

    CREATE TEMPORARY TABLE tmp_result AS
    SELECT
        final_output.MasterId,
        MasterCode,
        CAST('' AS CHAR(50))                                   AS ParentMaster,
        MasterName,
        MasterValidFrom,
        MasterValidTo,
        NumDayAlert                                             AS MasterNumDayAlert,
        MasterDescription,
        MasterVersionNo,
        CAST(Status AS CHAR(20))                               AS Status,
        COALESCE(Id, 0)                                        AS Id,
        COALESCE(Code, '')                                     AS Code,
        COALESCE(Name, '')                                     AS Name,
        COALESCE(FileId, '')                                   AS FileId,
        ValidFrom,
        ValidTo,
        ComplianceNumDayAlert                                   AS NumDayAlert,
        VersionNo,
        ReplacedById,
        COALESCE(Description, '')                              AS Description,
        COALESCE(alert.EmailJson, alert_c.EmailJson)           AS AlertGroupsJson,
        COALESCE(resp.EmailJson,  resp_c.EmailJson)            AS ResponsibleGroupsJson,
        cj.ConditionsJson,
        CAST(MappedRefTypeId   AS UNSIGNED)                    AS MappedRefTypeId,
        CAST(MappedRefTypeCode AS CHAR(150))                   AS MappedRefTypeCode,
        CAST(MappedRefTypeName AS CHAR(300))                   AS MappedRefTypeName,
        CAST(MappedInputValue  AS CHAR(255))                   AS MappedInputValue
    FROM (

        -- ── Stream 1: APPLIED ─────────────────────────────────────
        SELECT
            ar.MasterId,
            mt.Code        AS MasterCode,
            mt.Name        AS MasterName,
            mt.ValidFrom   AS MasterValidFrom,
            mt.ValidTo     AS MasterValidTo,
            mt.NumDayAlert,
            mt.Description AS MasterDescription,
            mt.VersionNo   AS MasterVersionNo,
            'APPLIED'      AS Status,
            ar.ComplianceId AS Id,
            cm.Code        AS Code,
            CONCAT(mt.Name, ' ', cm.Name) AS Name,
            cm.FileId      AS FileId,
            cm.ValidFrom   AS ValidFrom,
            cm.ValidTo     AS ValidTo,
            cm.NumDayAlert AS ComplianceNumDayAlert,
            cm.VersionNo   AS VersionNo,
            cm.ReplacedById AS ReplacedById,
            cm.Description AS Description,
            ar.MappedRefTypeId,
            ar.MappedRefTypeCode,
            ar.MappedRefTypeName,
            ar.MappedInputValue
        FROM tmp_applied_rows ar
        LEFT JOIN compl_masters     mt ON mt.Id = ar.MasterId
        LEFT JOIN compl_compliances cm ON cm.Id = ar.ComplianceId
        WHERE ar.rn = 1

        UNION ALL

        -- ── Stream 2: MISSING per input value (IsIndividual = 1) ──
        SELECT
            mr.MasterId,
            mt.Code        AS MasterCode,
            mt.Name        AS MasterName,
            mt.ValidFrom   AS MasterValidFrom,
            mt.ValidTo     AS MasterValidTo,
            mt.NumDayAlert,
            mt.Description AS MasterDescription,
            mt.VersionNo   AS MasterVersionNo,
            'MISSING'      AS Status,
            ec.ExpiredComplianceId AS Id,
            cm.Code        AS Code,
            CONCAT(mt.Name, cm.Name) AS Name,
            cm.FileId      AS FileId,
            cm.ValidFrom   AS ValidFrom,
            cm.ValidTo     AS ValidTo,
            cm.NumDayAlert AS ComplianceNumDayAlert,
            cm.VersionNo   AS VersionNo,
            cm.ReplacedById AS ReplacedById,
            cm.Description AS Description,
            mr.MappedRefTypeId,
            mr.MappedRefTypeCode,
            mr.MappedRefTypeName,
            mr.missing_input_value AS MappedInputValue
        FROM tmp_missing_rows mr
        LEFT JOIN tmp_expired_compliances ec
               ON ec.MasterId    = mr.MasterId
              AND ec.RefTypeValue = mr.missing_input_value
              AND ec.rn = 1
        LEFT JOIN compl_masters     mt ON mt.Id = mr.MasterId
        LEFT JOIN compl_compliances cm ON cm.Id = ec.ExpiredComplianceId

        UNION ALL

        -- ── Stream 3: MISSING master-level (IsIndividual = 0) ─────
        SELECT
            mmr.MasterId,
            mt.Code        AS MasterCode,
            mt.Name        AS MasterName,
            mt.ValidFrom   AS MasterValidFrom,
            mt.ValidTo     AS MasterValidTo,
            mt.NumDayAlert,
            mt.Description AS MasterDescription,
            mt.VersionNo   AS MasterVersionNo,
            'MISSING'      AS Status,
            ec.ExpiredComplianceId AS Id,
            cm.Code        AS Code,
            CONCAT(mt.Name, cm.Name) AS Name,
            cm.FileId      AS FileId,
            cm.ValidFrom   AS ValidFrom,
            cm.ValidTo     AS ValidTo,
            cm.NumDayAlert AS ComplianceNumDayAlert,
            cm.VersionNo   AS VersionNo,
            cm.ReplacedById AS ReplacedById,
            cm.Description AS Description,
            mmr.MappedRefTypeId,
            mmr.MappedRefTypeCode,
            mmr.MappedRefTypeName,
            mmr.MappedInputValue
        FROM tmp_master_missing_rows mmr
        LEFT JOIN tmp_expired_compliances_2 ec
               ON ec.MasterId    = mmr.MasterId
              AND ec.RefComplType = 0
              AND ec.rn = 1
        LEFT JOIN compl_masters     mt ON mt.Id = mmr.MasterId
        LEFT JOIN compl_compliances cm ON cm.Id = ec.ExpiredComplianceId

    ) final_output
    LEFT JOIN tmp_master_conditions_json    cj      ON cj.MasterId      = final_output.MasterId
    LEFT JOIN tmp_master_email_alert_json   alert   ON alert.MasterId   = final_output.MasterId
    LEFT JOIN tmp_master_email_resp_json    resp    ON resp.MasterId    = final_output.MasterId
    LEFT JOIN tmp_compliance_email_alert_json alert_c ON alert_c.ComplianceId = final_output.Id
    LEFT JOIN tmp_compliance_email_resp_json  resp_c  ON resp_c.ComplianceId  = final_output.Id;

    ALTER TABLE tmp_result
        ADD INDEX idx_mastercode      (MasterCode),
        ADD INDEX idx_code_mappedval  (Code, MappedInputValue(191));

    -- ================================================================
    -- STEP 20b: Đánh dấu các dòng bị "phủ" bởi compliance của Master cha
    --   (Root) trong cây phân cấp compl_master_hierarchies — KHÔNG xoá,
    --   chỉ cập nhật ParentMaster (luôn gán) và Status (chỉ đổi thành
    --   'UseParent' nếu dòng con đang là 'MISSING').
    --
    --   Quy tắc (giữ nguyên điều kiện xác định "bị phủ" như trước đây):
    --   - Với mỗi dòng root_row trong tmp_result có Code <> '' và
    --     root_row.MasterCode là 1 Root (ParentCode = '') trong
    --     compl_master_hierarchies:
    --       + Lấy đệ quy toàn bộ MasterCode con/cháu của Root này theo
    --         ParentCode (KHÔNG gồm chính Root).
    --       + Với các dòng khác (tr) có tr.MasterCode = <1 MasterCode
    --         con/cháu> VÀ tr.MappedInputValue = root_row.MappedInputValue
    --         — vì compliance đó coi như đã được đáp ứng qua Master cha,
    --         không cần liệt kê độc lập cho Master con — GIỮ LẠI dòng đó
    --         trong tmp_result, gán:
    --           tr.ParentMaster = root_row.MasterCode (mã Master cha/Root)
    --             — gán cho MỌI dòng con bị phủ, bất kể Status hiện tại.
    --           tr.Status = 'UseParent' — CHỈ khi dòng con đang là
    --             'MISSING'; nếu dòng con đang 'APPLIED' (đã có compliance
    --             riêng) thì GIỮ NGUYÊN Status 'APPLIED', không đổi thành
    --             'UseParent'.
    --   - Dòng root_row dùng để xác định điều kiện luôn được giữ nguyên
    --     Status ban đầu (không tự đổi thành 'UseParent' cho chính nó).
    -- ================================================================
    DROP TEMPORARY TABLE IF EXISTS tmp_hierarchy_descendants;
    CREATE TEMPORARY TABLE tmp_hierarchy_descendants AS
    WITH RECURSIVE cte_hierarchy AS (
        SELECT
            h.MasterCode AS RootMasterCode,
            h.MasterCode AS DescendantMasterCode
        FROM compl_master_hierarchies h
        WHERE h.ParentCode = ''

        UNION ALL

        SELECT
            c.RootMasterCode,
            h.MasterCode AS DescendantMasterCode
        FROM compl_master_hierarchies h
        INNER JOIN cte_hierarchy c
                ON h.ParentCode = c.DescendantMasterCode
    )
    SELECT DISTINCT RootMasterCode, DescendantMasterCode
    FROM cte_hierarchy
    WHERE DescendantMasterCode <> RootMasterCode;   -- loại chính Root khỏi danh sách con cháu

    ALTER TABLE tmp_hierarchy_descendants
        ADD INDEX idx_root (RootMasterCode),
        ADD INDEX idx_desc (DescendantMasterCode);

    -- MySQL không cho phép mở lại cùng 1 TEMPORARY TABLE nhiều lần trong 1
    -- câu lệnh (lỗi 1137 "Can't reopen table") — không thể tự self-join
    -- tmp_result. Vì vậy tách các dòng "root" (Code <> '') ra 1 bảng tạm
    -- riêng trước, rồi mới UPDATE trên tmp_result (chỉ mở 1 lần).
    DROP TEMPORARY TABLE IF EXISTS tmp_hierarchy_root_matches;
    CREATE TEMPORARY TABLE tmp_hierarchy_root_matches AS
    SELECT DISTINCT
        tr.MasterCode       AS RootMasterCode,
        tr.MappedInputValue AS MappedInputValue
    FROM tmp_result tr
    WHERE tr.Code <> '';

    ALTER TABLE tmp_hierarchy_root_matches
        ADD INDEX idx_root_miv (RootMasterCode, MappedInputValue(191));

    UPDATE tmp_result tr
    INNER JOIN tmp_hierarchy_root_matches rm
            ON rm.MappedInputValue = tr.MappedInputValue
    INNER JOIN tmp_hierarchy_descendants hd
            ON hd.RootMasterCode       = rm.RootMasterCode
           AND hd.DescendantMasterCode = tr.MasterCode
    SET tr.ParentMaster = rm.RootMasterCode,
        tr.Status       = CASE WHEN tr.Status = 'MISSING' THEN 'UseParent' ELSE tr.Status END
        -- chỉ đổi Status thành 'UseParent' khi dòng con đang là MISSING; nếu dòng con đang
        -- APPLIED (đã có compliance riêng) thì GIỮ NGUYÊN Status, chỉ gán ParentMaster để
        -- biết dòng này còn được Master cha phủ, không đổi Status của nó.
    WHERE tr.MasterCode <> rm.RootMasterCode;       -- không tự đánh dấu dòng root đang dùng để so khớp

    DROP TEMPORARY TABLE IF EXISTS tmp_hierarchy_descendants;
    DROP TEMPORARY TABLE IF EXISTS tmp_hierarchy_root_matches;

    -- ================================================================
    -- STEP 21: Trả kết quả cuối cùng từ tmp_result
    -- ================================================================
    SELECT *
    FROM tmp_result
    ORDER BY
        MasterCode,
        Status DESC;

    -- ================================================================
    -- CLEANUP: Dọn toàn bộ temp tables sau khi xong
    -- ================================================================
    DROP TEMPORARY TABLE IF EXISTS tmp_input_data;
    DROP TEMPORARY TABLE IF EXISTS tmp_input_eav;
    DROP TEMPORARY TABLE IF EXISTS tmp_input_country_groups;
    DROP TEMPORARY TABLE IF EXISTS tmp_cmcv_group;
    DROP TEMPORARY TABLE IF EXISTS tmp_var_group;
    DROP TEMPORARY TABLE IF EXISTS tmp_not_in_excluded;           -- [NOT IN]

    DROP TEMPORARY TABLE IF EXISTS tmp_valid_masters;
    DROP TEMPORARY TABLE IF EXISTS tmp_condition_group_match;
    DROP TEMPORARY TABLE IF EXISTS tmp_master_condition_counts;
    DROP TEMPORARY TABLE IF EXISTS tmp_master_input_match;
    DROP TEMPORARY TABLE IF EXISTS tmp_matched_masters;
    DROP TEMPORARY TABLE IF EXISTS tmp_all_references;
    DROP TEMPORARY TABLE IF EXISTS tmp_valid_references;
    DROP TEMPORARY TABLE IF EXISTS tmp_applied_rows;
    DROP TEMPORARY TABLE IF EXISTS tmp_expired_compliances;
    DROP TEMPORARY TABLE IF EXISTS tmp_expired_compliances_2;
    DROP TEMPORARY TABLE IF EXISTS tmp_distinct_input_values;
    DROP TEMPORARY TABLE IF EXISTS tmp_valid_applied_refs;
    DROP TEMPORARY TABLE IF EXISTS tmp_cmc_has_all;
    DROP TEMPORARY TABLE IF EXISTS tmp_missing_rows;
    DROP TEMPORARY TABLE IF EXISTS tmp_master_has_refs;
    DROP TEMPORARY TABLE IF EXISTS tmp_master_has_specific_cond;
    DROP TEMPORARY TABLE IF EXISTS tmp_master_has_applied;
    DROP TEMPORARY TABLE IF EXISTS tmp_master_missing_rows;
    DROP TEMPORARY TABLE IF EXISTS tmp_master_conditions_json;
    DROP TEMPORARY TABLE IF EXISTS tmp_group_email_detail_agg;
    DROP TEMPORARY TABLE IF EXISTS tmp_master_email_alert_json;
    DROP TEMPORARY TABLE IF EXISTS tmp_master_email_resp_json;
    DROP TEMPORARY TABLE IF EXISTS tmp_compliance_email_alert_json;
    DROP TEMPORARY TABLE IF EXISTS tmp_compliance_email_resp_json;
    DROP TEMPORARY TABLE IF EXISTS tmp_result;
    DROP TEMPORARY TABLE IF EXISTS tmp_hierarchy_descendants;
    DROP TEMPORARY TABLE IF EXISTS tmp_hierarchy_root_matches;

END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_load_compl_by_conditions_count` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_load_compl_by_conditions_count`(
    IN p_json_data JSON,
    IN p_check_date DATE
)
BEGIN
    SET p_check_date = COALESCE(p_check_date, CURDATE());

    -- ================================================================
    -- CLEANUP
    -- ================================================================
    DROP TEMPORARY TABLE IF EXISTS tmp_input_data;
    DROP TEMPORARY TABLE IF EXISTS tmp_input_eav;                 -- [NOT IN]
    DROP TEMPORARY TABLE IF EXISTS tmp_input_country_groups;      -- [NOT IN]
    DROP TEMPORARY TABLE IF EXISTS tmp_cmcv_group;                -- [COUNTRY GROUP]
    DROP TEMPORARY TABLE IF EXISTS tmp_var_group;                 -- [COUNTRY GROUP]
    DROP TEMPORARY TABLE IF EXISTS tmp_not_in_excluded;           -- [NOT IN]
    DROP TEMPORARY TABLE IF EXISTS tmp_valid_masters;
    DROP TEMPORARY TABLE IF EXISTS tmp_condition_group_match;
    DROP TEMPORARY TABLE IF EXISTS tmp_master_condition_counts;
    DROP TEMPORARY TABLE IF EXISTS tmp_master_input_match;
    DROP TEMPORARY TABLE IF EXISTS tmp_matched_masters;
    DROP TEMPORARY TABLE IF EXISTS tmp_all_references;
    DROP TEMPORARY TABLE IF EXISTS tmp_valid_references;
    DROP TEMPORARY TABLE IF EXISTS tmp_applied_rows;
    DROP TEMPORARY TABLE IF EXISTS tmp_expired_compliances;
    DROP TEMPORARY TABLE IF EXISTS tmp_distinct_input_values;
    DROP TEMPORARY TABLE IF EXISTS tmp_cmc_has_all;               -- [PERF]
    DROP TEMPORARY TABLE IF EXISTS tmp_valid_applied_refs;        -- [PERF]
    DROP TEMPORARY TABLE IF EXISTS tmp_master_has_refs;           -- [PERF]
    DROP TEMPORARY TABLE IF EXISTS tmp_master_has_specific_cond;  -- [PERF]
    DROP TEMPORARY TABLE IF EXISTS tmp_master_has_applied;        -- [PERF]
    DROP TEMPORARY TABLE IF EXISTS tmp_missing_rows;
    DROP TEMPORARY TABLE IF EXISTS tmp_master_missing_rows;
    DROP TEMPORARY TABLE IF EXISTS tmp_all_master_ids;

    -- ================================================================
    -- STEP 1: Parse JSON  ← giống hệt SP chính
    -- ================================================================
    CREATE TEMPORARY TABLE tmp_input_data AS
    SELECT
        ROW_NUMBER() OVER () AS LineNo,
        jt.*,
        jt.Country        AS COUNTRY_v,
        jt.Customer       AS CUSTOMER_v,
        jt.Factory        AS FACTORY_v,
        jt.Product        AS PRODUCT_v,
        jt.ProductType    AS PRODUCT_TYPE_v,
        jt.Variant        AS VARIANT_v,
        jt.Material       AS MATERIAL_v,
        jt.CostGroup      AS COST_GROUP_v,
        jt.Attribute      AS ATTRIBUTE_v,
        jt.MaterialType   AS MATERIAL_TYPE_v,
        jt.AttributeGroup AS ATTRIBUTE_GROUP_v
    FROM JSON_TABLE(
        p_json_data,
        '$[*]' COLUMNS(
            Country        VARCHAR(50)  PATH '$.Country',
            Customer       VARCHAR(50)  PATH '$.Customer',
            Factory        VARCHAR(50)  PATH '$.Factory',
            Product        VARCHAR(50)  PATH '$.Product',
            ProductType    VARCHAR(100) PATH '$.ProductType',
            Variant        VARCHAR(50)  PATH '$.Variant',
            Material       VARCHAR(50)  PATH '$.Material',
            CostGroup      VARCHAR(50)  PATH '$.CostGroup',
            Attribute      VARCHAR(100) PATH '$.Attribute',
            MaterialType   VARCHAR(50)  PATH '$.MaterialType',
            AttributeGroup VARCHAR(100) PATH '$.AttributeGroup'
        )
    ) AS jt;

    ALTER TABLE tmp_input_data
        ADD INDEX idx_pvc (Product, Variant, Customer);

    -- ================================================================
    -- STEP 1b [NOT IN]: EAV — pivot input fields thành (FieldCode, FieldValue)
    --   Dùng nhiều INSERT riêng để tránh Error 1137
    -- ================================================================
    CREATE TEMPORARY TABLE tmp_input_eav (
        Product        VARCHAR(50),
        Variant        VARCHAR(50),
        Customer       VARCHAR(50),
        FieldCode      VARCHAR(50),
        FieldValue     VARCHAR(100)
    );

    INSERT INTO tmp_input_eav SELECT DISTINCT Product, Variant, Customer, 'COUNTRY',         COUNTRY_v         FROM tmp_input_data WHERE COUNTRY_v         IS NOT NULL AND COUNTRY_v         != '';
    INSERT INTO tmp_input_eav SELECT DISTINCT Product, Variant, Customer, 'CUSTOMER',        CUSTOMER_v        FROM tmp_input_data WHERE CUSTOMER_v        IS NOT NULL AND CUSTOMER_v        != '';
    INSERT INTO tmp_input_eav SELECT DISTINCT Product, Variant, Customer, 'FACTORY',         FACTORY_v         FROM tmp_input_data WHERE FACTORY_v         IS NOT NULL AND FACTORY_v         != '';
    INSERT INTO tmp_input_eav SELECT DISTINCT Product, Variant, Customer, 'PRODUCT',         PRODUCT_v         FROM tmp_input_data WHERE PRODUCT_v         IS NOT NULL AND PRODUCT_v         != '';
    INSERT INTO tmp_input_eav SELECT DISTINCT Product, Variant, Customer, 'PRODUCT_TYPE',    PRODUCT_TYPE_v    FROM tmp_input_data WHERE PRODUCT_TYPE_v    IS NOT NULL AND PRODUCT_TYPE_v    != '';
    INSERT INTO tmp_input_eav SELECT DISTINCT Product, Variant, Customer, 'VARIANT',         VARIANT_v         FROM tmp_input_data WHERE VARIANT_v         IS NOT NULL AND VARIANT_v         != '';
    INSERT INTO tmp_input_eav SELECT DISTINCT Product, Variant, Customer, 'MATERIAL',        MATERIAL_v        FROM tmp_input_data WHERE MATERIAL_v        IS NOT NULL AND MATERIAL_v        != '';
    INSERT INTO tmp_input_eav SELECT DISTINCT Product, Variant, Customer, 'COST_GROUP',      COST_GROUP_v      FROM tmp_input_data WHERE COST_GROUP_v      IS NOT NULL AND COST_GROUP_v      != '';
    INSERT INTO tmp_input_eav SELECT DISTINCT Product, Variant, Customer, 'ATTRIBUTE',       ATTRIBUTE_v       FROM tmp_input_data WHERE ATTRIBUTE_v       IS NOT NULL AND ATTRIBUTE_v       != '';
    INSERT INTO tmp_input_eav SELECT DISTINCT Product, Variant, Customer, 'MATERIAL_TYPE',   MATERIAL_TYPE_v   FROM tmp_input_data WHERE MATERIAL_TYPE_v   IS NOT NULL AND MATERIAL_TYPE_v   != '';
    INSERT INTO tmp_input_eav SELECT DISTINCT Product, Variant, Customer, 'ATTRIBUTE_GROUP', ATTRIBUTE_GROUP_v FROM tmp_input_data WHERE ATTRIBUTE_GROUP_v  IS NOT NULL AND ATTRIBUTE_GROUP_v != '';

    ALTER TABLE tmp_input_eav
        ADD INDEX idx_field (FieldCode, FieldValue(100)),
        ADD INDEX idx_pvc   (Product, Variant, Customer);

    -- ================================================================
    -- STEP 2: Latest valid masters  ← giống hệt SP chính
    -- ================================================================
    CREATE TEMPORARY TABLE tmp_valid_masters AS
    SELECT *
    FROM (
        SELECT
            cm.*,
            ROW_NUMBER() OVER (
                PARTITION BY cm.Code
                ORDER BY cm.ValidFrom DESC, cm.Id DESC
            ) AS rn
        FROM compl_masters cm
        WHERE cm.IsDelete = 0
          AND p_check_date BETWEEN cm.ValidFrom AND COALESCE(cm.ValidTo, '2099-12-31')
    ) t
    WHERE rn = 1;

    ALTER TABLE tmp_valid_masters
        ADD PRIMARY KEY (Id),
        ADD INDEX idx_code (Code);

    -- ================================================================
    -- STEP 2b [NOT IN]: Build country → group code lookup từ input
    -- ================================================================
    CREATE TEMPORARY TABLE tmp_input_country_groups AS
    SELECT DISTINCT
        eav.FieldValue   AS CountryCode,
        cg.Code          AS GroupCode
    FROM tmp_input_eav eav
    INNER JOIN compl_country_group_members cgm
            ON cgm.CountryCode = eav.FieldValue
    INNER JOIN compl_country_groups cg
            ON cg.Id       = cgm.GroupId
           AND cg.IsActive = 1
    WHERE eav.FieldCode = 'COUNTRY';

    ALTER TABLE tmp_input_country_groups
        ADD INDEX idx_country (CountryCode),
        ADD INDEX idx_group   (GroupCode);

    -- ================================================================
    -- STEP 2c [NOT IN]: Materialize các tổ hợp (ConditionId, Product,
    --   Variant, Customer) bị LOẠI TRỪ bởi NOT IN conditions.
    --   Hai nguồn: exact value + group match (chỉ COUNTRY)
    -- ================================================================
    CREATE TEMPORARY TABLE tmp_not_in_excluded (
        ConditionId BIGINT,
        MasterId    BIGINT,
        Product     VARCHAR(50),
        Variant     VARCHAR(50),
        Customer    VARCHAR(50)
    );

    -- Nguồn 1: Loại trừ theo exact value
    INSERT INTO tmp_not_in_excluded
    SELECT DISTINCT
        cmc.Id   AS ConditionId,
        cmc.MasterId,
        eav.Product,
        eav.Variant,
        eav.Customer
    FROM compl_master_condition_values cmcv
    INNER JOIN compl_master_conditions cmc
            ON cmc.Id       = cmcv.ConditionId
           AND cmc.Operator = 'NOT IN'
           AND cmc.ComplType IN (0, 1)
    INNER JOIN tmp_valid_masters vm ON vm.Id = cmc.MasterId
    INNER JOIN compl_reference_types crt ON crt.Id = cmc.RefTypeId
    INNER JOIN tmp_input_eav eav
            ON eav.FieldCode  = crt.Code
           AND eav.FieldValue = cmcv.RefTypeValue;

    -- Nguồn 2: Loại trừ theo group code (chỉ COUNTRY)
    INSERT INTO tmp_not_in_excluded
    SELECT DISTINCT
        cmc.Id   AS ConditionId,
        cmc.MasterId,
        eav.Product,
        eav.Variant,
        eav.Customer
    FROM compl_master_condition_values cmcv
    INNER JOIN compl_master_conditions cmc
            ON cmc.Id       = cmcv.ConditionId
           AND cmc.Operator = 'NOT IN'
           AND cmc.ComplType IN (0, 1)
    INNER JOIN tmp_valid_masters vm ON vm.Id = cmc.MasterId
    INNER JOIN compl_reference_types crt
            ON crt.Id   = cmc.RefTypeId
           AND crt.Code = 'COUNTRY'
    INNER JOIN tmp_input_country_groups icg ON icg.GroupCode = cmcv.RefTypeValue
    INNER JOIN tmp_input_eav eav
            ON eav.FieldCode  = 'COUNTRY'
           AND eav.FieldValue = icg.CountryCode;

    ALTER TABLE tmp_not_in_excluded
        ADD INDEX idx_cond_pvc (ConditionId, Product, Variant, Customer);

    -- ================================================================
    -- STEP 3: Condition match
    --   [NOT IN] Thay CASE/WHERE trực tiếp bằng EAV JOIN (đồng bộ SP chính)
    --   Tách thành CREATE (nhánh IN/=) + INSERT riêng (nhánh NOT IN)
    --   để tránh Error 1137 khi tmp_input_eav bị mở 2 lần.
    --
    --   Nhánh 1 — IN/= (giữ nguyên logic ALL + EXACT + GROUP):
    --     cmc.Operator != 'NOT IN'
    --
    --   Nhánh 2 — NOT IN: khớp khi (ConditionId, P, V, C) KHÔNG bị loại trừ
    --     LEFT JOIN tmp_not_in_excluded ... WHERE nie.ConditionId IS NULL
    -- ================================================================

    -- ── Nhánh 1: IN / = operators ───────────────────────────────────
    CREATE TEMPORARY TABLE tmp_condition_group_match AS
    SELECT DISTINCT
        eav.Product,
        eav.Variant,
        eav.Customer,
        cmc.MasterId,
        cmc.Id AS ConditionId
    FROM tmp_input_eav eav
    INNER JOIN compl_reference_types crt
            ON crt.Code = eav.FieldCode
    INNER JOIN compl_master_conditions cmc
            ON cmc.RefTypeId = crt.Id
           AND cmc.ComplType IN (0, 1)
           AND cmc.Operator != 'NOT IN'                   -- [NOT IN] Loại NOT IN ra khỏi nhánh này
    INNER JOIN tmp_valid_masters vm
            ON vm.Id = cmc.MasterId
    INNER JOIN compl_master_condition_values cmcv
            ON cmcv.ConditionId = cmc.Id
           AND (
                   cmcv.RefTypeValue = eav.FieldValue
                OR cmcv.RefTypeValue = 'ALL'
                OR (
                       crt.Code = 'COUNTRY'
                   AND EXISTS (
                           SELECT 1
                           FROM tmp_input_country_groups icg
                           WHERE icg.CountryCode = eav.FieldValue
                             AND icg.GroupCode   = cmcv.RefTypeValue
                       )
                   )
               );

    -- ── Nhánh 2: NOT IN operator ─────────────────────────────────────
    -- Tách INSERT riêng để tránh Error 1137 (tmp_input_eav mở 2 lần).
    -- Condition NOT IN khớp khi (ConditionId, P, V, C) KHÔNG bị loại trừ.
    INSERT INTO tmp_condition_group_match
    SELECT DISTINCT
        eav.Product,
        eav.Variant,
        eav.Customer,
        cmc.MasterId,
        cmc.Id AS ConditionId
    FROM tmp_input_eav eav
    INNER JOIN compl_reference_types crt
            ON crt.Code = eav.FieldCode
    INNER JOIN compl_master_conditions cmc
            ON cmc.RefTypeId = crt.Id
           AND cmc.Operator  = 'NOT IN'                   -- [NOT IN] Chỉ xử lý NOT IN
           AND cmc.ComplType IN (0, 1)
    INNER JOIN tmp_valid_masters vm
            ON vm.Id = cmc.MasterId
    LEFT JOIN tmp_not_in_excluded nie
           ON nie.ConditionId = cmc.Id
          AND nie.Product     = eav.Product
          AND nie.Variant     = eav.Variant
          AND nie.Customer    = eav.Customer
    WHERE nie.ConditionId IS NULL;                        -- [NOT IN] Không bị loại trừ → khớp

    ALTER TABLE tmp_condition_group_match
        ADD INDEX idx_lookup  (MasterId, Product, Variant, Customer, ConditionId),
        ADD INDEX idx_lookup2 (Product, Variant, Customer, MasterId);

    -- ================================================================
    -- STEP 4: Count AND / OR  ← giống hệt SP chính
    -- ================================================================
    CREATE TEMPORARY TABLE tmp_master_condition_counts AS
    SELECT
        cmc.MasterId,
        SUM(cmc.Logical = 1) AS total_and,
        SUM(cmc.Logical = 2) AS total_or
    FROM compl_master_conditions cmc
    INNER JOIN tmp_valid_masters vm ON vm.Id = cmc.MasterId
    GROUP BY cmc.MasterId;

    ALTER TABLE tmp_master_condition_counts
        ADD PRIMARY KEY (MasterId);

    -- ================================================================
    -- STEP 5: Matched count  ← giống hệt SP chính
    -- ================================================================
    CREATE TEMPORARY TABLE tmp_master_input_match AS
    SELECT
        cgm.MasterId,
        cgm.Product,
        cgm.Variant,
        cgm.Customer,
        SUM(cmc.Logical = 1) AS and_matched,
        SUM(cmc.Logical = 2) AS or_matched
    FROM tmp_condition_group_match cgm
    INNER JOIN compl_master_conditions cmc
           ON cmc.Id       = cgm.ConditionId
          AND cmc.MasterId = cgm.MasterId
    GROUP BY cgm.MasterId, cgm.Product, cgm.Variant, cgm.Customer;

    ALTER TABLE tmp_master_input_match
        ADD INDEX idx_match (MasterId, Product, Variant, Customer);

    -- ================================================================
    -- STEP 6: Final match  ← giống hệt SP chính
    -- ================================================================
    CREATE TEMPORARY TABLE tmp_matched_masters AS
    SELECT DISTINCT
        inp.*,
        vm.Id          AS MasterId,
        vm.IsIndividual
    FROM tmp_input_data inp
    INNER JOIN tmp_master_input_match mim
           ON mim.Product  = inp.Product
          AND mim.Variant  = inp.Variant
          AND mim.Customer = inp.Customer
    INNER JOIN tmp_valid_masters vm
           ON vm.Id = mim.MasterId
    LEFT JOIN tmp_master_condition_counts mcc
           ON mcc.MasterId = vm.Id
    WHERE
        (mcc.total_and > 0 AND mim.and_matched = mcc.total_and)
        OR (mcc.total_or > 0 AND mim.or_matched > 0)
        OR mcc.MasterId IS NULL;

    -- ================================================================
    -- STEP 7: All references + tính sẵn ResolvedFieldValue
    --   Đồng bộ với SP chính để validate được cả exact, ALL và COUNTRY group.
    -- ================================================================
    CREATE TEMPORARY TABLE tmp_all_references AS
    SELECT
        mm.*,
        cr.Id          AS RefId,
        cr.ComplianceId,
        cr.ComplType,
        cr.RefTypeId,
        cr.RefTypeValue,
        CASE crt.Code
            WHEN 'COUNTRY'         THEN mm.COUNTRY_v
            WHEN 'CUSTOMER'        THEN mm.CUSTOMER_v
            WHEN 'FACTORY'         THEN mm.FACTORY_v
            WHEN 'PRODUCT'         THEN mm.PRODUCT_v
            WHEN 'PRODUCT_TYPE'    THEN mm.PRODUCT_TYPE_v
            WHEN 'VARIANT'         THEN mm.VARIANT_v
            WHEN 'MATERIAL'        THEN mm.MATERIAL_v
            WHEN 'COST_GROUP'      THEN mm.COST_GROUP_v
            WHEN 'ATTRIBUTE'       THEN mm.ATTRIBUTE_v
            WHEN 'MATERIAL_TYPE'   THEN mm.MATERIAL_TYPE_v
            WHEN 'ATTRIBUTE_GROUP' THEN mm.ATTRIBUTE_GROUP_v
        END AS ResolvedFieldValue,
        crt.Code AS RefTypeCode
    FROM tmp_matched_masters mm
    LEFT JOIN compl_references cr
           ON cr.MasterId = mm.MasterId
    LEFT JOIN compl_reference_types crt
           ON crt.Id = cr.RefTypeId;

    ALTER TABLE tmp_all_references
        ADD INDEX idx_master (MasterId),
        ADD INDEX idx_compl  (ComplianceId);

    -- ================================================================
    -- STEP 8: Validate references
    --   Đồng bộ với SP chính: có xử lý COUNTRY group.
    -- ================================================================
    CREATE TEMPORARY TABLE tmp_valid_references AS
    SELECT
        ar.*,
        CASE
            WHEN ar.RefId IS NULL THEN 0
            WHEN ar.ComplType = 0 THEN 1
            WHEN ar.ComplType = 1 AND ar.RefTypeId IS NOT NULL AND ar.RefTypeValue IS NOT NULL THEN
                CASE
                    WHEN ar.RefTypeValue = 'ALL'
                         AND ar.ResolvedFieldValue IS NOT NULL
                         AND ar.ResolvedFieldValue != ''         THEN 1
                    WHEN ar.ResolvedFieldValue = ar.RefTypeValue THEN 1
                    WHEN ar.RefTypeCode = 'COUNTRY'
                         AND ar.ResolvedFieldValue IS NOT NULL
                         AND ar.ResolvedFieldValue != ''
                         AND EXISTS (
                             SELECT 1
                             FROM tmp_input_country_groups icg
                             WHERE icg.CountryCode = ar.ResolvedFieldValue
                               AND icg.GroupCode   = ar.RefTypeValue
                         )                                      THEN 1
                    ELSE 0
                END
            ELSE 0
        END AS IsValidReference
    FROM tmp_all_references ar;

    ALTER TABLE tmp_valid_references
        ADD INDEX idx_master_valid (MasterId, IsValidReference),
        ADD INDEX idx_compl_valid  (ComplianceId, IsValidReference);

    -- ================================================================
    -- STEP 9: Applied rows  ← giống hệt SP chính (bỏ các cột không cần)
    -- ================================================================
    CREATE TEMPORARY TABLE tmp_applied_rows AS
    SELECT
        vr.MasterId,
        cc.Id AS ComplianceId,
        vr.RefTypeValue AS MappedInputValue,
        ROW_NUMBER() OVER (
            PARTITION BY vr.MasterId, COALESCE(vr.RefTypeValue, '')
            ORDER BY cc.VersionNo DESC, cc.Id DESC
        ) AS rn
    FROM tmp_valid_references vr
    INNER JOIN compl_compliances cc
        ON  vr.ComplianceId = cc.Id
        AND cc.IsDelete     = 0
        AND p_check_date >= DATE(cc.ValidFrom)
        AND p_check_date <= DATE(COALESCE(cc.ValidTo, '2099-12-31'))
    WHERE vr.IsValidReference = 1;

    -- ================================================================
    -- STEP 10: Expired compliances  ← giống hệt SP chính
    -- ================================================================
    CREATE TEMPORARY TABLE tmp_expired_compliances AS
    SELECT
        cr.MasterId,
        cr.RefTypeId,
        cr.RefTypeValue,
        cr.ComplType AS RefComplType,
        cc.Id        AS ExpiredComplianceId,
        ROW_NUMBER() OVER (
            PARTITION BY cr.MasterId, cr.RefTypeValue
            ORDER BY cc.ValidTo DESC
        ) AS rn
    FROM compl_references cr
    INNER JOIN compl_compliances cc
        ON  cr.ComplianceId = cc.Id
        AND cc.IsDelete     = 0
        AND DATE(cc.ValidTo) < p_check_date;

    -- ================================================================
    -- STEP 11: Distinct input values (IsIndividual = 1)
    --   [NOT IN] Giữ NOT IN giống SP chính. Trường hợp NOT IN + ALL vẫn có thể
    --   phát sinh missing/applied theo input value nếu chưa có compliance.
    -- ================================================================
    CREATE TEMPORARY TABLE tmp_distinct_input_values AS
    SELECT DISTINCT
        mm.MasterId,
        cmc.RefTypeId,
        CASE crt.Code
            WHEN 'COUNTRY'         THEN mm.COUNTRY_v
            WHEN 'CUSTOMER'        THEN mm.CUSTOMER_v
            WHEN 'FACTORY'         THEN mm.FACTORY_v
            WHEN 'PRODUCT'         THEN mm.PRODUCT_v
            WHEN 'PRODUCT_TYPE'    THEN mm.PRODUCT_TYPE_v
            WHEN 'VARIANT'         THEN mm.VARIANT_v
            WHEN 'MATERIAL'        THEN mm.MATERIAL_v
            WHEN 'COST_GROUP'      THEN mm.COST_GROUP_v
            WHEN 'ATTRIBUTE'       THEN mm.ATTRIBUTE_v
            WHEN 'MATERIAL_TYPE'   THEN mm.MATERIAL_TYPE_v
            WHEN 'ATTRIBUTE_GROUP' THEN mm.ATTRIBUTE_GROUP_v
        END AS InputValue
    FROM tmp_matched_masters mm
    INNER JOIN compl_master_conditions cmc
            ON cmc.MasterId  = mm.MasterId
           AND cmc.ComplType = 1
    INNER JOIN compl_reference_types crt ON crt.Id = cmc.RefTypeId
    WHERE mm.IsIndividual = 1
      AND CASE crt.Code
              WHEN 'COUNTRY'         THEN mm.COUNTRY_v
              WHEN 'CUSTOMER'        THEN mm.CUSTOMER_v
              WHEN 'FACTORY'         THEN mm.FACTORY_v
              WHEN 'PRODUCT'         THEN mm.PRODUCT_v
              WHEN 'PRODUCT_TYPE'    THEN mm.PRODUCT_TYPE_v
              WHEN 'VARIANT'         THEN mm.VARIANT_v
              WHEN 'MATERIAL'        THEN mm.MATERIAL_v
              WHEN 'COST_GROUP'      THEN mm.COST_GROUP_v
              WHEN 'ATTRIBUTE'       THEN mm.ATTRIBUTE_v
              WHEN 'MATERIAL_TYPE'   THEN mm.MATERIAL_TYPE_v
              WHEN 'ATTRIBUTE_GROUP' THEN mm.ATTRIBUTE_GROUP_v
          END IS NOT NULL
      AND CASE crt.Code
              WHEN 'COUNTRY'         THEN mm.COUNTRY_v
              WHEN 'CUSTOMER'        THEN mm.CUSTOMER_v
              WHEN 'FACTORY'         THEN mm.FACTORY_v
              WHEN 'PRODUCT'         THEN mm.PRODUCT_v
              WHEN 'PRODUCT_TYPE'    THEN mm.PRODUCT_TYPE_v
              WHEN 'VARIANT'         THEN mm.VARIANT_v
              WHEN 'MATERIAL'        THEN mm.MATERIAL_v
              WHEN 'COST_GROUP'      THEN mm.COST_GROUP_v
              WHEN 'ATTRIBUTE'       THEN mm.ATTRIBUTE_v
              WHEN 'MATERIAL_TYPE'   THEN mm.MATERIAL_TYPE_v
              WHEN 'ATTRIBUTE_GROUP' THEN mm.ATTRIBUTE_GROUP_v
          END != '';

    ALTER TABLE tmp_distinct_input_values
        ADD INDEX idx_master_ref (MasterId, RefTypeId);

    -- ================================================================
    -- STEP 11a: Pre-aggregate — conditions có RefTypeValue = 'ALL'
    --   Thay thế EXISTS(SELECT 1 FROM compl_master_condition_values WHERE RefTypeValue='ALL')
    --   chạy inline cho từng dòng → pre-compute 1 lần, dùng LEFT JOIN
    -- ================================================================
    CREATE TEMPORARY TABLE tmp_cmc_has_all AS
    SELECT DISTINCT ConditionId
    FROM compl_master_condition_values
    WHERE RefTypeValue = 'ALL';

    ALTER TABLE tmp_cmc_has_all ADD PRIMARY KEY (ConditionId);

    -- ================================================================
    -- STEP 11b: Pre-aggregate — compliance đang valid
    --   Thay thế NOT EXISTS(SELECT 1 FROM compl_references cr INNER JOIN compl_compliances cc ...)
    --   chạy inline cho từng dòng → pre-compute 1 lần, dùng LEFT JOIN
    -- ================================================================
    CREATE TEMPORARY TABLE tmp_valid_applied_refs AS
    SELECT DISTINCT
        cr.MasterId,
        cr.RefTypeId,
        cr.RefTypeValue
    FROM compl_references cr
    INNER JOIN compl_compliances cc
            ON cc.Id = cr.ComplianceId
           AND cc.IsDelete = 0
           AND p_check_date BETWEEN DATE(cc.ValidFrom)
                                AND DATE(COALESCE(cc.ValidTo, '2099-12-31'));

    ALTER TABLE tmp_valid_applied_refs
        ADD INDEX idx_lookup (MasterId, RefTypeId, RefTypeValue(100));

    -- ================================================================
    -- STEP 11c: Condition value khớp qua COUNTRY group
    --   Dùng cho missing individual giống SP chính.
    -- ================================================================
    CREATE TEMPORARY TABLE tmp_cmcv_group AS
    SELECT
        cmcv_g.ConditionId,
        icg.CountryCode
    FROM compl_master_condition_values cmcv_g
    INNER JOIN tmp_input_country_groups icg
            ON icg.GroupCode = cmcv_g.RefTypeValue;

    ALTER TABLE tmp_cmcv_group
        ADD INDEX idx_cond_country (ConditionId, CountryCode(20));

    -- ================================================================
    -- STEP 11d: Compliance đang valid khớp qua COUNTRY group
    --   Dùng để không đếm thiếu nếu đã có compliance valid theo group.
    -- ================================================================
    CREATE TEMPORARY TABLE tmp_var_group AS
    SELECT
        var_g.MasterId,
        var_g.RefTypeId,
        icg.CountryCode
    FROM tmp_valid_applied_refs var_g
    INNER JOIN tmp_input_country_groups icg
            ON icg.GroupCode = var_g.RefTypeValue;

    ALTER TABLE tmp_var_group
        ADD INDEX idx_lookup (MasterId, RefTypeId, CountryCode(20));

    -- ================================================================
    -- STEP 12: Missing rows (IsIndividual = 1)
    --   [PERF FIX] Thay 3 correlated subqueries inline bằng LEFT JOIN
    --   vào pre-aggregated tables (tmp_cmc_has_all, tmp_valid_applied_refs).
    --   Lý do chậm cũ: EXISTS/NOT EXISTS chạy lại mỗi dòng của
    --   (tmp_matched_masters × cmc × dv) → O(n³) scan.
    -- ================================================================
    CREATE TEMPORARY TABLE tmp_missing_rows AS
    SELECT
        mm.MasterId,
        dv.InputValue AS missing_input_value
    FROM tmp_matched_masters mm
    INNER JOIN compl_master_conditions cmc
            ON cmc.MasterId  = mm.MasterId
           AND cmc.ComplType = 1
    INNER JOIN compl_reference_types crt ON crt.Id = cmc.RefTypeId
    INNER JOIN tmp_distinct_input_values dv
            ON dv.MasterId  = mm.MasterId
           AND dv.RefTypeId = cmc.RefTypeId
    -- [PERF] Thay EXISTS('ALL') → LEFT JOIN
    LEFT JOIN tmp_cmc_has_all ha
           ON ha.ConditionId = cmc.Id
    -- [PERF] Thay EXISTS(exact value) → LEFT JOIN
    LEFT JOIN compl_master_condition_values cmcv_exact
           ON cmcv_exact.ConditionId  = cmc.Id
          AND cmcv_exact.RefTypeValue = dv.InputValue
    -- [COUNTRY GROUP] Condition value khớp qua group
    LEFT JOIN tmp_cmcv_group cmcv_grp
           ON cmcv_grp.ConditionId = cmc.Id
          AND cmcv_grp.CountryCode = dv.InputValue
          AND crt.Code             = 'COUNTRY'
    -- [PERF] Thay NOT EXISTS(valid compliance exact) → LEFT JOIN
    LEFT JOIN tmp_valid_applied_refs var_exact
           ON var_exact.MasterId     = mm.MasterId
          AND var_exact.RefTypeId    = cmc.RefTypeId
          AND var_exact.RefTypeValue = dv.InputValue
    -- [COUNTRY GROUP] Không đếm thiếu nếu đã có compliance valid theo group
    LEFT JOIN tmp_var_group var_grp
           ON var_grp.MasterId    = mm.MasterId
          AND var_grp.RefTypeId   = cmc.RefTypeId
          AND var_grp.CountryCode = dv.InputValue
          AND crt.Code            = 'COUNTRY'
    WHERE mm.IsIndividual = 1
      AND (
              ha.ConditionId         IS NOT NULL   -- khớp ALL
          OR  cmcv_exact.ConditionId IS NOT NULL   -- khớp exact value
          OR  cmcv_grp.ConditionId   IS NOT NULL   -- khớp COUNTRY group
          )
      AND var_exact.MasterId IS NULL                -- chưa có compliance valid exact
      AND var_grp.MasterId   IS NULL                -- chưa có compliance valid group
    GROUP BY mm.MasterId, dv.InputValue;

    -- ================================================================
    -- STEP 12a: Pre-aggregate cho master-level missing
    --   Thay thế 4 correlated EXISTS/NOT EXISTS trong STEP 13.
    -- ================================================================
    CREATE TEMPORARY TABLE tmp_master_has_refs AS
    SELECT DISTINCT MasterId FROM compl_references;

    ALTER TABLE tmp_master_has_refs ADD PRIMARY KEY (MasterId);

    CREATE TEMPORARY TABLE tmp_master_has_specific_cond AS
    SELECT DISTINCT MasterId FROM compl_master_conditions WHERE ComplType = 1;

    ALTER TABLE tmp_master_has_specific_cond ADD PRIMARY KEY (MasterId);

    CREATE TEMPORARY TABLE tmp_master_has_applied AS
    SELECT DISTINCT MasterId FROM tmp_applied_rows WHERE rn = 1;

    ALTER TABLE tmp_master_has_applied ADD PRIMARY KEY (MasterId);

    -- ================================================================
    -- STEP 13: Master-level missing rows (IsIndividual = 0)
    --   [PERF FIX] Thay 4 correlated EXISTS/NOT EXISTS bằng LEFT JOIN
    --   vào pre-aggregated tables — cùng pattern với SP chính STEP 15.
    -- ================================================================
    CREATE TEMPORARY TABLE tmp_master_missing_rows AS
    SELECT mm.MasterId
    FROM tmp_matched_masters mm
    LEFT JOIN tmp_master_has_refs          hr ON hr.MasterId = mm.MasterId
    LEFT JOIN tmp_master_has_specific_cond sc ON sc.MasterId = mm.MasterId
    LEFT JOIN tmp_master_has_applied       ha ON ha.MasterId = mm.MasterId
    WHERE mm.IsIndividual = 0
      AND sc.MasterId IS NULL                        -- không có specific condition (ComplType=1)
      AND (
          hr.MasterId IS NULL                        -- case 1: không có reference nào
          OR
          (hr.MasterId IS NOT NULL AND ha.MasterId IS NULL)  -- case 2: có ref nhưng chưa applied
      )
    GROUP BY mm.MasterId;

    -- ================================================================
    -- STEP 14: Tính toán và trả về kết quả  ← giống hệt SP chính
    -- ================================================================

    -- Applied
    SET @total_applied = (
        SELECT COUNT(*) FROM tmp_applied_rows WHERE rn = 1
    );

    -- Overdue: individual missing + has expired compliance
    SELECT
        COUNT(*) AS total,
        GROUP_CONCAT(DISTINCT mr.MasterId ORDER BY mr.MasterId SEPARATOR ',') AS Ids
    INTO
        @overdue_individual,
        @overdue_individual_master_ids
    FROM tmp_missing_rows mr
    WHERE EXISTS (
        SELECT 1 FROM tmp_expired_compliances ec
        WHERE ec.MasterId    = mr.MasterId
          AND ec.RefTypeValue = mr.missing_input_value
          AND ec.rn           = 1
    );

    -- Overdue: master-level missing + has expired compliance
    SELECT
        COUNT(*) AS total,
        GROUP_CONCAT(DISTINCT mmr.MasterId ORDER BY mmr.MasterId SEPARATOR ',') AS Ids
    INTO
        @overdue_master,
        @overdue_master_ids
    FROM tmp_master_missing_rows mmr
    WHERE EXISTS (
        SELECT 1 FROM tmp_expired_compliances ec
        WHERE ec.MasterId    = mmr.MasterId
          AND ec.RefComplType = 0
          AND ec.rn           = 1
    );

    SET @total_overdue = @overdue_individual + @overdue_master;

    -- Missing: individual missing + không có expired compliance
    SELECT
        COUNT(*) AS total,
        GROUP_CONCAT(DISTINCT mr.MasterId ORDER BY mr.MasterId SEPARATOR ',') AS Ids
    INTO
        @missing_individual,
        @missing_individual_master_ids
    FROM tmp_missing_rows mr
    WHERE NOT EXISTS (
        SELECT 1 FROM tmp_expired_compliances ec
        WHERE ec.MasterId    = mr.MasterId
          AND ec.RefTypeValue = mr.missing_input_value
          AND ec.rn           = 1
    );

    -- Missing: master-level missing + không có expired compliance
    SELECT
        COUNT(*) AS total,
        GROUP_CONCAT(DISTINCT mmr.MasterId ORDER BY mmr.MasterId SEPARATOR ',') AS Ids
    INTO
        @missing_master,
        @missing_master_ids
    FROM tmp_master_missing_rows mmr
    WHERE NOT EXISTS (
        SELECT 1
        FROM tmp_expired_compliances ec
        WHERE ec.MasterId    = mmr.MasterId
          AND ec.RefComplType = 0
          AND ec.rn           = 1
    );

    -- Tạo bảng để lấy mail
    CREATE TEMPORARY TABLE tmp_all_master_ids (MasterId BIGINT PRIMARY KEY);

    -- Overdue: individual
    INSERT IGNORE INTO tmp_all_master_ids (MasterId)
    SELECT DISTINCT mr.MasterId
    FROM tmp_missing_rows mr
    WHERE EXISTS (
        SELECT 1 FROM tmp_expired_compliances ec
        WHERE ec.MasterId    = mr.MasterId
          AND ec.RefTypeValue = mr.missing_input_value
          AND ec.rn           = 1
    );

    -- Overdue: master-level
    INSERT IGNORE INTO tmp_all_master_ids (MasterId)
    SELECT DISTINCT mmr.MasterId
    FROM tmp_master_missing_rows mmr
    WHERE EXISTS (
        SELECT 1 FROM tmp_expired_compliances ec
        WHERE ec.MasterId    = mmr.MasterId
          AND ec.RefComplType = 0
          AND ec.rn           = 1
    );

    -- Missing: individual
    INSERT IGNORE INTO tmp_all_master_ids (MasterId)
    SELECT DISTINCT mr.MasterId
    FROM tmp_missing_rows mr
    WHERE NOT EXISTS (
        SELECT 1 FROM tmp_expired_compliances ec
        WHERE ec.MasterId    = mr.MasterId
          AND ec.RefTypeValue = mr.missing_input_value
          AND ec.rn           = 1
    );

    -- Missing: master-level
    INSERT IGNORE INTO tmp_all_master_ids (MasterId)
    SELECT DISTINCT mmr.MasterId
    FROM tmp_master_missing_rows mmr
    WHERE NOT EXISTS (
        SELECT 1
        FROM tmp_expired_compliances ec
        WHERE ec.MasterId    = mmr.MasterId
          AND ec.RefComplType = 0
          AND ec.rn           = 1
    );

    SELECT
        GROUP_CONCAT(DISTINCT CASE WHEN ccge.GroupType = 1 THEN cged.ResponseEmail END),
        GROUP_CONCAT(DISTINCT CASE WHEN ccge.GroupType = 2 THEN cged.ResponseEmail END)
    INTO
        @ResponsibleEmails,
        @AlertEmails
    FROM tmp_all_master_ids ids
    JOIN compl_master_group_email ccge ON ccge.MasterId = ids.MasterId
    LEFT JOIN compl_group_email_detail cged
        ON cged.GroupEmailId = ccge.GroupEmailId
       AND cged.IsActive = TRUE;

    SET @total_missing = @missing_individual + @missing_master;

    SELECT
        @total_applied  AS TotalApplied,
        @total_overdue  AS TotalOverdue,
        ROUND(@total_missing) AS TotalMissing,
        CONCAT(@missing_individual_master_ids, ',', @missing_master_ids) AS MissingMasterIds,
        CONCAT(@overdue_individual_master_ids, ',', @overdue_master_ids) AS OverdueMasterIds,
        @ResponsibleEmails AS ResponsibleEmails,
        @AlertEmails       AS AlertEmails;

    -- ================================================================
    -- CLEANUP
    -- ================================================================
    DROP TEMPORARY TABLE IF EXISTS tmp_input_data;
    DROP TEMPORARY TABLE IF EXISTS tmp_input_eav;                 -- [NOT IN]
    DROP TEMPORARY TABLE IF EXISTS tmp_input_country_groups;      -- [NOT IN]
    DROP TEMPORARY TABLE IF EXISTS tmp_cmcv_group;                -- [COUNTRY GROUP]
    DROP TEMPORARY TABLE IF EXISTS tmp_var_group;                 -- [COUNTRY GROUP]
    DROP TEMPORARY TABLE IF EXISTS tmp_not_in_excluded;           -- [NOT IN]
    DROP TEMPORARY TABLE IF EXISTS tmp_valid_masters;
    DROP TEMPORARY TABLE IF EXISTS tmp_condition_group_match;
    DROP TEMPORARY TABLE IF EXISTS tmp_master_condition_counts;
    DROP TEMPORARY TABLE IF EXISTS tmp_master_input_match;
    DROP TEMPORARY TABLE IF EXISTS tmp_matched_masters;
    DROP TEMPORARY TABLE IF EXISTS tmp_all_references;
    DROP TEMPORARY TABLE IF EXISTS tmp_valid_references;
    DROP TEMPORARY TABLE IF EXISTS tmp_applied_rows;
    DROP TEMPORARY TABLE IF EXISTS tmp_expired_compliances;
    DROP TEMPORARY TABLE IF EXISTS tmp_distinct_input_values;
    DROP TEMPORARY TABLE IF EXISTS tmp_cmc_has_all;               -- [PERF]
    DROP TEMPORARY TABLE IF EXISTS tmp_valid_applied_refs;        -- [PERF]
    DROP TEMPORARY TABLE IF EXISTS tmp_master_has_refs;           -- [PERF]
    DROP TEMPORARY TABLE IF EXISTS tmp_master_has_specific_cond;  -- [PERF]
    DROP TEMPORARY TABLE IF EXISTS tmp_master_has_applied;        -- [PERF]
    DROP TEMPORARY TABLE IF EXISTS tmp_missing_rows;
    DROP TEMPORARY TABLE IF EXISTS tmp_master_missing_rows;
    DROP TEMPORARY TABLE IF EXISTS tmp_all_master_ids;

END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_load_compl_by_conditions_show` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_load_compl_by_conditions_show`(
    IN p_json_data JSON,
    IN p_check_date DATE
)
BEGIN
	SET p_check_date = COALESCE(p_check_date, CURDATE());

    -- ================================================================
    -- CLEANUP
    -- ================================================================
    DROP TEMPORARY TABLE IF EXISTS tmp_input_data;
    DROP TEMPORARY TABLE IF EXISTS tmp_input_eav;                 -- [NOT IN]
    DROP TEMPORARY TABLE IF EXISTS tmp_input_country_groups;      -- [NOT IN]
    DROP TEMPORARY TABLE IF EXISTS tmp_cmcv_group;                -- [COUNTRY GROUP]
    DROP TEMPORARY TABLE IF EXISTS tmp_var_group;                 -- [COUNTRY GROUP]
    DROP TEMPORARY TABLE IF EXISTS tmp_not_in_excluded;           -- [NOT IN]
    DROP TEMPORARY TABLE IF EXISTS tmp_valid_masters;
    DROP TEMPORARY TABLE IF EXISTS tmp_condition_group_match;
    DROP TEMPORARY TABLE IF EXISTS tmp_master_condition_counts;
    DROP TEMPORARY TABLE IF EXISTS tmp_master_input_match;
    DROP TEMPORARY TABLE IF EXISTS tmp_matched_masters;
    DROP TEMPORARY TABLE IF EXISTS tmp_all_references;
    DROP TEMPORARY TABLE IF EXISTS tmp_valid_references;
    DROP TEMPORARY TABLE IF EXISTS tmp_applied_rows;
    DROP TEMPORARY TABLE IF EXISTS tmp_expired_compliances;
    DROP TEMPORARY TABLE IF EXISTS tmp_distinct_input_values;
    DROP TEMPORARY TABLE IF EXISTS tmp_cmc_has_all;               -- [PERF]
    DROP TEMPORARY TABLE IF EXISTS tmp_valid_applied_refs;        -- [PERF]
    DROP TEMPORARY TABLE IF EXISTS tmp_master_has_refs;           -- [PERF]
    DROP TEMPORARY TABLE IF EXISTS tmp_master_has_specific_cond;  -- [PERF]
    DROP TEMPORARY TABLE IF EXISTS tmp_master_has_applied;        -- [PERF]
    DROP TEMPORARY TABLE IF EXISTS tmp_missing_rows;
    DROP TEMPORARY TABLE IF EXISTS tmp_master_missing_rows;
    DROP TEMPORARY TABLE IF EXISTS tmp_all_master_ids;

    -- ================================================================
    -- STEP 1: Parse JSON  ← giống hệt SP chính
    -- ================================================================
    CREATE TEMPORARY TABLE tmp_input_data AS
    SELECT
        ROW_NUMBER() OVER () AS LineNo,
        jt.*,
        jt.Country        AS COUNTRY_v,
        jt.Customer       AS CUSTOMER_v,
        jt.Factory        AS FACTORY_v,
        jt.Product        AS PRODUCT_v,
        jt.ProductType    AS PRODUCT_TYPE_v,
        jt.Variant        AS VARIANT_v,
        jt.Material       AS MATERIAL_v,
        jt.CostGroup      AS COST_GROUP_v,
        jt.Attribute      AS ATTRIBUTE_v,
        jt.MaterialType   AS MATERIAL_TYPE_v,
        jt.AttributeGroup AS ATTRIBUTE_GROUP_v
    FROM JSON_TABLE(
        p_json_data,
        '$[*]' COLUMNS(
            Country        VARCHAR(50)  PATH '$.Country',
            Customer       VARCHAR(50)  PATH '$.Customer',
            Factory        VARCHAR(50)  PATH '$.Factory',
            Product        VARCHAR(50)  PATH '$.Product',
            ProductType    VARCHAR(100) PATH '$.ProductType',
            Variant        VARCHAR(50)  PATH '$.Variant',
            Material       VARCHAR(50)  PATH '$.Material',
            CostGroup      VARCHAR(50)  PATH '$.CostGroup',
            Attribute      VARCHAR(100) PATH '$.Attribute',
            MaterialType   VARCHAR(50)  PATH '$.MaterialType',
            AttributeGroup VARCHAR(100) PATH '$.AttributeGroup'
        )
    ) AS jt;

    ALTER TABLE tmp_input_data
        ADD INDEX idx_pvc (Product, Variant, Customer);

    -- ================================================================
    -- STEP 1b [NOT IN]: EAV — pivot input fields thành (FieldCode, FieldValue)
    --   Dùng nhiều INSERT riêng để tránh Error 1137
    -- ================================================================
    CREATE TEMPORARY TABLE tmp_input_eav (
        Product        VARCHAR(50),
        Variant        VARCHAR(50),
        Customer       VARCHAR(50),
        FieldCode      VARCHAR(50),
        FieldValue     VARCHAR(100)
    );

    INSERT INTO tmp_input_eav SELECT DISTINCT Product, Variant, Customer, 'COUNTRY',         COUNTRY_v         FROM tmp_input_data WHERE COUNTRY_v         IS NOT NULL AND COUNTRY_v         != '';
    INSERT INTO tmp_input_eav SELECT DISTINCT Product, Variant, Customer, 'CUSTOMER',        CUSTOMER_v        FROM tmp_input_data WHERE CUSTOMER_v        IS NOT NULL AND CUSTOMER_v        != '';
    INSERT INTO tmp_input_eav SELECT DISTINCT Product, Variant, Customer, 'FACTORY',         FACTORY_v         FROM tmp_input_data WHERE FACTORY_v         IS NOT NULL AND FACTORY_v         != '';
    INSERT INTO tmp_input_eav SELECT DISTINCT Product, Variant, Customer, 'PRODUCT',         PRODUCT_v         FROM tmp_input_data WHERE PRODUCT_v         IS NOT NULL AND PRODUCT_v         != '';
    INSERT INTO tmp_input_eav SELECT DISTINCT Product, Variant, Customer, 'PRODUCT_TYPE',    PRODUCT_TYPE_v    FROM tmp_input_data WHERE PRODUCT_TYPE_v    IS NOT NULL AND PRODUCT_TYPE_v    != '';
    INSERT INTO tmp_input_eav SELECT DISTINCT Product, Variant, Customer, 'VARIANT',         VARIANT_v         FROM tmp_input_data WHERE VARIANT_v         IS NOT NULL AND VARIANT_v         != '';
    INSERT INTO tmp_input_eav SELECT DISTINCT Product, Variant, Customer, 'MATERIAL',        MATERIAL_v        FROM tmp_input_data WHERE MATERIAL_v        IS NOT NULL AND MATERIAL_v        != '';
    INSERT INTO tmp_input_eav SELECT DISTINCT Product, Variant, Customer, 'COST_GROUP',      COST_GROUP_v      FROM tmp_input_data WHERE COST_GROUP_v      IS NOT NULL AND COST_GROUP_v      != '';
    INSERT INTO tmp_input_eav SELECT DISTINCT Product, Variant, Customer, 'ATTRIBUTE',       ATTRIBUTE_v       FROM tmp_input_data WHERE ATTRIBUTE_v       IS NOT NULL AND ATTRIBUTE_v       != '';
    INSERT INTO tmp_input_eav SELECT DISTINCT Product, Variant, Customer, 'MATERIAL_TYPE',   MATERIAL_TYPE_v   FROM tmp_input_data WHERE MATERIAL_TYPE_v   IS NOT NULL AND MATERIAL_TYPE_v   != '';
    INSERT INTO tmp_input_eav SELECT DISTINCT Product, Variant, Customer, 'ATTRIBUTE_GROUP', ATTRIBUTE_GROUP_v FROM tmp_input_data WHERE ATTRIBUTE_GROUP_v  IS NOT NULL AND ATTRIBUTE_GROUP_v != '';

    ALTER TABLE tmp_input_eav
        ADD INDEX idx_field (FieldCode, FieldValue(100)),
        ADD INDEX idx_pvc   (Product, Variant, Customer);

    -- ================================================================
    -- STEP 2: Latest valid masters  ← giống hệt SP chính
    -- ================================================================
    CREATE TEMPORARY TABLE tmp_valid_masters AS
    SELECT *
    FROM (
        SELECT
            cm.*,
            ROW_NUMBER() OVER (
                PARTITION BY cm.Code
                ORDER BY cm.ValidFrom DESC, cm.Id DESC
            ) AS rn
        FROM compl_masters cm
        WHERE cm.IsDelete = 0
          AND p_check_date BETWEEN cm.ValidFrom AND COALESCE(cm.ValidTo, '2099-12-31')
    ) t
    WHERE rn = 1;

    ALTER TABLE tmp_valid_masters
        ADD PRIMARY KEY (Id),
        ADD INDEX idx_code (Code);

    -- ================================================================
    -- STEP 2b [NOT IN]: Build country → group code lookup từ input
    -- ================================================================
    CREATE TEMPORARY TABLE tmp_input_country_groups AS
    SELECT DISTINCT
        eav.FieldValue   AS CountryCode,
        cg.Code          AS GroupCode
    FROM tmp_input_eav eav
    INNER JOIN compl_country_group_members cgm
            ON cgm.CountryCode = eav.FieldValue
    INNER JOIN compl_country_groups cg
            ON cg.Id       = cgm.GroupId
           AND cg.IsActive = 1
    WHERE eav.FieldCode = 'COUNTRY';

    ALTER TABLE tmp_input_country_groups
        ADD INDEX idx_country (CountryCode),
        ADD INDEX idx_group   (GroupCode);

    -- ================================================================
    -- STEP 2c [NOT IN]: Materialize các tổ hợp (ConditionId, Product,
    --   Variant, Customer) bị LOẠI TRỪ bởi NOT IN conditions.
    --   Hai nguồn: exact value + group match (chỉ COUNTRY)
    -- ================================================================
    CREATE TEMPORARY TABLE tmp_not_in_excluded (
        ConditionId BIGINT,
        MasterId    BIGINT,
        Product     VARCHAR(50),
        Variant     VARCHAR(50),
        Customer    VARCHAR(50)
    );

    -- Nguồn 1: Loại trừ theo exact value
    INSERT INTO tmp_not_in_excluded
    SELECT DISTINCT
        cmc.Id   AS ConditionId,
        cmc.MasterId,
        eav.Product,
        eav.Variant,
        eav.Customer
    FROM compl_master_condition_values cmcv
    INNER JOIN compl_master_conditions cmc
            ON cmc.Id       = cmcv.ConditionId
           AND cmc.Operator = 'NOT IN'
           AND cmc.ComplType IN (0, 1)
    INNER JOIN tmp_valid_masters vm ON vm.Id = cmc.MasterId
    INNER JOIN compl_reference_types crt ON crt.Id = cmc.RefTypeId
    INNER JOIN tmp_input_eav eav
            ON eav.FieldCode  = crt.Code
           AND eav.FieldValue = cmcv.RefTypeValue;

    -- Nguồn 2: Loại trừ theo group code (chỉ COUNTRY)
    INSERT INTO tmp_not_in_excluded
    SELECT DISTINCT
        cmc.Id   AS ConditionId,
        cmc.MasterId,
        eav.Product,
        eav.Variant,
        eav.Customer
    FROM compl_master_condition_values cmcv
    INNER JOIN compl_master_conditions cmc
            ON cmc.Id       = cmcv.ConditionId
           AND cmc.Operator = 'NOT IN'
           AND cmc.ComplType IN (0, 1)
    INNER JOIN tmp_valid_masters vm ON vm.Id = cmc.MasterId
    INNER JOIN compl_reference_types crt
            ON crt.Id   = cmc.RefTypeId
           AND crt.Code = 'COUNTRY'
    INNER JOIN tmp_input_country_groups icg ON icg.GroupCode = cmcv.RefTypeValue
    INNER JOIN tmp_input_eav eav
            ON eav.FieldCode  = 'COUNTRY'
           AND eav.FieldValue = icg.CountryCode;

    ALTER TABLE tmp_not_in_excluded
        ADD INDEX idx_cond_pvc (ConditionId, Product, Variant, Customer);

    -- ================================================================
    -- STEP 3: Condition match
    --   [NOT IN] Thay CASE/WHERE trực tiếp bằng EAV JOIN (đồng bộ SP chính)
    --   Tách thành CREATE (nhánh IN/=) + INSERT riêng (nhánh NOT IN)
    --   để tránh Error 1137 khi tmp_input_eav bị mở 2 lần.
    --
    --   Nhánh 1 — IN/= (giữ nguyên logic ALL + EXACT + GROUP):
    --     cmc.Operator != 'NOT IN'
    --
    --   Nhánh 2 — NOT IN: khớp khi (ConditionId, P, V, C) KHÔNG bị loại trừ
    --     LEFT JOIN tmp_not_in_excluded ... WHERE nie.ConditionId IS NULL
    -- ================================================================

    -- ── Nhánh 1: IN / = operators ───────────────────────────────────
    CREATE TEMPORARY TABLE tmp_condition_group_match AS
    SELECT DISTINCT
        eav.Product,
        eav.Variant,
        eav.Customer,
        cmc.MasterId,
        cmc.Id AS ConditionId
    FROM tmp_input_eav eav
    INNER JOIN compl_reference_types crt
            ON crt.Code = eav.FieldCode
    INNER JOIN compl_master_conditions cmc
            ON cmc.RefTypeId = crt.Id
           AND cmc.ComplType IN (0, 1)
           AND cmc.Operator != 'NOT IN'                   -- [NOT IN] Loại NOT IN ra khỏi nhánh này
    INNER JOIN tmp_valid_masters vm
            ON vm.Id = cmc.MasterId
    INNER JOIN compl_master_condition_values cmcv
            ON cmcv.ConditionId = cmc.Id
           AND (
                   cmcv.RefTypeValue = eav.FieldValue
                OR cmcv.RefTypeValue = 'ALL'
                OR (
                       crt.Code = 'COUNTRY'
                   AND EXISTS (
                           SELECT 1
                           FROM tmp_input_country_groups icg
                           WHERE icg.CountryCode = eav.FieldValue
                             AND icg.GroupCode   = cmcv.RefTypeValue
                       )
                   )
               );

    -- ── Nhánh 2: NOT IN operator ─────────────────────────────────────
    -- Tách INSERT riêng để tránh Error 1137 (tmp_input_eav mở 2 lần).
    -- Condition NOT IN khớp khi (ConditionId, P, V, C) KHÔNG bị loại trừ.
    INSERT INTO tmp_condition_group_match
    SELECT DISTINCT
        eav.Product,
        eav.Variant,
        eav.Customer,
        cmc.MasterId,
        cmc.Id AS ConditionId
    FROM tmp_input_eav eav
    INNER JOIN compl_reference_types crt
            ON crt.Code = eav.FieldCode
    INNER JOIN compl_master_conditions cmc
            ON cmc.RefTypeId = crt.Id
           AND cmc.Operator  = 'NOT IN'                   -- [NOT IN] Chỉ xử lý NOT IN
           AND cmc.ComplType IN (0, 1)
    INNER JOIN tmp_valid_masters vm
            ON vm.Id = cmc.MasterId
    LEFT JOIN tmp_not_in_excluded nie
           ON nie.ConditionId = cmc.Id
          AND nie.Product     = eav.Product
          AND nie.Variant     = eav.Variant
          AND nie.Customer    = eav.Customer
    WHERE nie.ConditionId IS NULL;                        -- [NOT IN] Không bị loại trừ → khớp

    ALTER TABLE tmp_condition_group_match
        ADD INDEX idx_lookup  (MasterId, Product, Variant, Customer, ConditionId),
        ADD INDEX idx_lookup2 (Product, Variant, Customer, MasterId);

    -- ================================================================
    -- STEP 4: Count AND / OR  ← giống hệt SP chính
    -- ================================================================
    CREATE TEMPORARY TABLE tmp_master_condition_counts AS
    SELECT
        cmc.MasterId,
        SUM(cmc.Logical = 1) AS total_and,
        SUM(cmc.Logical = 2) AS total_or
    FROM compl_master_conditions cmc
    INNER JOIN tmp_valid_masters vm ON vm.Id = cmc.MasterId
    GROUP BY cmc.MasterId;

    ALTER TABLE tmp_master_condition_counts
        ADD PRIMARY KEY (MasterId);

    -- ================================================================
    -- STEP 5: Matched count  ← giống hệt SP chính
    -- ================================================================
    CREATE TEMPORARY TABLE tmp_master_input_match AS
    SELECT
        cgm.MasterId,
        cgm.Product,
        cgm.Variant,
        cgm.Customer,
        SUM(cmc.Logical = 1) AS and_matched,
        SUM(cmc.Logical = 2) AS or_matched
    FROM tmp_condition_group_match cgm
    INNER JOIN compl_master_conditions cmc
           ON cmc.Id       = cgm.ConditionId
          AND cmc.MasterId = cgm.MasterId
    GROUP BY cgm.MasterId, cgm.Product, cgm.Variant, cgm.Customer;

    ALTER TABLE tmp_master_input_match
        ADD INDEX idx_match (MasterId, Product, Variant, Customer);

    -- ================================================================
    -- STEP 6: Final match  ← giống hệt SP chính
    -- ================================================================
    CREATE TEMPORARY TABLE tmp_matched_masters AS
    SELECT DISTINCT
        inp.*,
        vm.Id          AS MasterId,
        vm.IsIndividual
    FROM tmp_input_data inp
    INNER JOIN tmp_master_input_match mim
           ON mim.Product  = inp.Product
          AND mim.Variant  = inp.Variant
          AND mim.Customer = inp.Customer
    INNER JOIN tmp_valid_masters vm
           ON vm.Id = mim.MasterId
    LEFT JOIN tmp_master_condition_counts mcc
           ON mcc.MasterId = vm.Id
    WHERE
        (mcc.total_and > 0 AND mim.and_matched = mcc.total_and)
        OR (mcc.total_or > 0 AND mim.or_matched > 0)
        OR mcc.MasterId IS NULL;

    -- ================================================================
    -- STEP 7: All references + tính sẵn ResolvedFieldValue
    --   Đồng bộ với SP chính để validate được cả exact, ALL và COUNTRY group.
    -- ================================================================
    CREATE TEMPORARY TABLE tmp_all_references AS
    SELECT
        mm.*,
        cr.Id          AS RefId,
        cr.ComplianceId,
        cr.ComplType,
        cr.RefTypeId,
        cr.RefTypeValue,
        CASE crt.Code
            WHEN 'COUNTRY'         THEN mm.COUNTRY_v
            WHEN 'CUSTOMER'        THEN mm.CUSTOMER_v
            WHEN 'FACTORY'         THEN mm.FACTORY_v
            WHEN 'PRODUCT'         THEN mm.PRODUCT_v
            WHEN 'PRODUCT_TYPE'    THEN mm.PRODUCT_TYPE_v
            WHEN 'VARIANT'         THEN mm.VARIANT_v
            WHEN 'MATERIAL'        THEN mm.MATERIAL_v
            WHEN 'COST_GROUP'      THEN mm.COST_GROUP_v
            WHEN 'ATTRIBUTE'       THEN mm.ATTRIBUTE_v
            WHEN 'MATERIAL_TYPE'   THEN mm.MATERIAL_TYPE_v
            WHEN 'ATTRIBUTE_GROUP' THEN mm.ATTRIBUTE_GROUP_v
        END AS ResolvedFieldValue,
        crt.Code AS RefTypeCode
    FROM tmp_matched_masters mm
    LEFT JOIN compl_references cr
           ON cr.MasterId = mm.MasterId
    LEFT JOIN compl_reference_types crt
           ON crt.Id = cr.RefTypeId;

    ALTER TABLE tmp_all_references
        ADD INDEX idx_master (MasterId),
        ADD INDEX idx_compl  (ComplianceId);

    -- ================================================================
    -- STEP 8: Validate references
    --   Đồng bộ với SP chính: có xử lý COUNTRY group.
    -- ================================================================
    CREATE TEMPORARY TABLE tmp_valid_references AS
    SELECT
        ar.*,
        CASE
            WHEN ar.RefId IS NULL THEN 0
            WHEN ar.ComplType = 0 THEN 1
            WHEN ar.ComplType = 1 AND ar.RefTypeId IS NOT NULL AND ar.RefTypeValue IS NOT NULL THEN
                CASE
                    WHEN ar.RefTypeValue = 'ALL'
                         AND ar.ResolvedFieldValue IS NOT NULL
                         AND ar.ResolvedFieldValue != ''         THEN 1
                    WHEN ar.ResolvedFieldValue = ar.RefTypeValue THEN 1
                    WHEN ar.RefTypeCode = 'COUNTRY'
                         AND ar.ResolvedFieldValue IS NOT NULL
                         AND ar.ResolvedFieldValue != ''
                         AND EXISTS (
                             SELECT 1
                             FROM tmp_input_country_groups icg
                             WHERE icg.CountryCode = ar.ResolvedFieldValue
                               AND icg.GroupCode   = ar.RefTypeValue
                         )                                      THEN 1
                    ELSE 0
                END
            ELSE 0
        END AS IsValidReference
    FROM tmp_all_references ar;

    ALTER TABLE tmp_valid_references
        ADD INDEX idx_master_valid (MasterId, IsValidReference),
        ADD INDEX idx_compl_valid  (ComplianceId, IsValidReference);

    -- ================================================================
    -- STEP 9: Applied rows  ← giống hệt SP chính (bỏ các cột không cần)
    -- ================================================================
    CREATE TEMPORARY TABLE tmp_applied_rows AS
    SELECT
        vr.MasterId,
        cc.Id AS ComplianceId,
        vr.RefTypeValue AS MappedInputValue,
        ROW_NUMBER() OVER (
            PARTITION BY vr.MasterId, COALESCE(vr.RefTypeValue, '')
            ORDER BY cc.VersionNo DESC, cc.Id DESC
        ) AS rn
    FROM tmp_valid_references vr
    INNER JOIN compl_compliances cc
        ON  vr.ComplianceId = cc.Id
        AND cc.IsDelete     = 0
        AND p_check_date >= DATE(cc.ValidFrom)
        AND p_check_date <= DATE(COALESCE(cc.ValidTo, '2099-12-31'))
    WHERE vr.IsValidReference = 1;

    -- ================================================================
    -- STEP 10: Expired compliances  ← giống hệt SP chính
    -- ================================================================
    CREATE TEMPORARY TABLE tmp_expired_compliances AS
    SELECT
        cr.MasterId,
        cr.RefTypeId,
        cr.RefTypeValue,
        cr.ComplType AS RefComplType,
        cc.Id        AS ExpiredComplianceId,
        ROW_NUMBER() OVER (
            PARTITION BY cr.MasterId, cr.RefTypeValue
            ORDER BY cc.ValidTo DESC
        ) AS rn
    FROM compl_references cr
    INNER JOIN compl_compliances cc
        ON  cr.ComplianceId = cc.Id
        AND cc.IsDelete     = 0
        AND DATE(cc.ValidTo) < p_check_date;

    -- ================================================================
    -- STEP 11: Distinct input values (IsIndividual = 1)
    --   [NOT IN] Loại bỏ NOT IN conditions — không phát sinh yêu cầu
    --   compliance riêng lẻ cho từng input value.
    -- ================================================================
    CREATE TEMPORARY TABLE tmp_distinct_input_values AS
    SELECT DISTINCT
        mm.MasterId,
        cmc.RefTypeId,
        CASE crt.Code
            WHEN 'COUNTRY'         THEN mm.COUNTRY_v
            WHEN 'CUSTOMER'        THEN mm.CUSTOMER_v
            WHEN 'FACTORY'         THEN mm.FACTORY_v
            WHEN 'PRODUCT'         THEN mm.PRODUCT_v
            WHEN 'PRODUCT_TYPE'    THEN mm.PRODUCT_TYPE_v
            WHEN 'VARIANT'         THEN mm.VARIANT_v
            WHEN 'MATERIAL'        THEN mm.MATERIAL_v
            WHEN 'COST_GROUP'      THEN mm.COST_GROUP_v
            WHEN 'ATTRIBUTE'       THEN mm.ATTRIBUTE_v
            WHEN 'MATERIAL_TYPE'   THEN mm.MATERIAL_TYPE_v
            WHEN 'ATTRIBUTE_GROUP' THEN mm.ATTRIBUTE_GROUP_v
        END AS InputValue
    FROM tmp_matched_masters mm
    INNER JOIN compl_master_conditions cmc
            ON cmc.MasterId  = mm.MasterId
           AND cmc.ComplType = 1
           AND cmc.Operator != 'NOT IN'                   -- [NOT IN] Bỏ NOT IN
    INNER JOIN compl_reference_types crt ON crt.Id = cmc.RefTypeId
    WHERE mm.IsIndividual = 1
      AND CASE crt.Code
              WHEN 'COUNTRY'         THEN mm.COUNTRY_v
              WHEN 'CUSTOMER'        THEN mm.CUSTOMER_v
              WHEN 'FACTORY'         THEN mm.FACTORY_v
              WHEN 'PRODUCT'         THEN mm.PRODUCT_v
              WHEN 'PRODUCT_TYPE'    THEN mm.PRODUCT_TYPE_v
              WHEN 'VARIANT'         THEN mm.VARIANT_v
              WHEN 'MATERIAL'        THEN mm.MATERIAL_v
              WHEN 'COST_GROUP'      THEN mm.COST_GROUP_v
              WHEN 'ATTRIBUTE'       THEN mm.ATTRIBUTE_v
              WHEN 'MATERIAL_TYPE'   THEN mm.MATERIAL_TYPE_v
              WHEN 'ATTRIBUTE_GROUP' THEN mm.ATTRIBUTE_GROUP_v
          END IS NOT NULL
      AND CASE crt.Code
              WHEN 'COUNTRY'         THEN mm.COUNTRY_v
              WHEN 'CUSTOMER'        THEN mm.CUSTOMER_v
              WHEN 'FACTORY'         THEN mm.FACTORY_v
              WHEN 'PRODUCT'         THEN mm.PRODUCT_v
              WHEN 'PRODUCT_TYPE'    THEN mm.PRODUCT_TYPE_v
              WHEN 'VARIANT'         THEN mm.VARIANT_v
              WHEN 'MATERIAL'        THEN mm.MATERIAL_v
              WHEN 'COST_GROUP'      THEN mm.COST_GROUP_v
              WHEN 'ATTRIBUTE'       THEN mm.ATTRIBUTE_v
              WHEN 'MATERIAL_TYPE'   THEN mm.MATERIAL_TYPE_v
              WHEN 'ATTRIBUTE_GROUP' THEN mm.ATTRIBUTE_GROUP_v
          END != '';

    ALTER TABLE tmp_distinct_input_values
        ADD INDEX idx_master_ref (MasterId, RefTypeId);

    -- ================================================================
    -- STEP 11a: Pre-aggregate — conditions có RefTypeValue = 'ALL'
    --   Thay thế EXISTS(SELECT 1 FROM compl_master_condition_values WHERE RefTypeValue='ALL')
    --   chạy inline cho từng dòng → pre-compute 1 lần, dùng LEFT JOIN
    -- ================================================================
    CREATE TEMPORARY TABLE tmp_cmc_has_all AS
    SELECT DISTINCT ConditionId
    FROM compl_master_condition_values
    WHERE RefTypeValue = 'ALL';

    ALTER TABLE tmp_cmc_has_all ADD PRIMARY KEY (ConditionId);

    -- ================================================================
    -- STEP 11b: Pre-aggregate — compliance đang valid
    --   Thay thế NOT EXISTS(SELECT 1 FROM compl_references cr INNER JOIN compl_compliances cc ...)
    --   chạy inline cho từng dòng → pre-compute 1 lần, dùng LEFT JOIN
    -- ================================================================
    CREATE TEMPORARY TABLE tmp_valid_applied_refs AS
    SELECT DISTINCT
        cr.MasterId,
        cr.RefTypeId,
        cr.RefTypeValue
    FROM compl_references cr
    INNER JOIN compl_compliances cc
            ON cc.Id = cr.ComplianceId
           AND cc.IsDelete = 0
           AND p_check_date BETWEEN DATE(cc.ValidFrom)
                                AND DATE(COALESCE(cc.ValidTo, '2099-12-31'));

    ALTER TABLE tmp_valid_applied_refs
        ADD INDEX idx_lookup (MasterId, RefTypeId, RefTypeValue(100));

    -- ================================================================
    -- STEP 11c: Condition value khớp qua COUNTRY group
    --   Dùng cho missing individual giống SP chính.
    -- ================================================================
    CREATE TEMPORARY TABLE tmp_cmcv_group AS
    SELECT
        cmcv_g.ConditionId,
        icg.CountryCode
    FROM compl_master_condition_values cmcv_g
    INNER JOIN tmp_input_country_groups icg
            ON icg.GroupCode = cmcv_g.RefTypeValue;

    ALTER TABLE tmp_cmcv_group
        ADD INDEX idx_cond_country (ConditionId, CountryCode(20));

    -- ================================================================
    -- STEP 11d: Compliance đang valid khớp qua COUNTRY group
    --   Dùng để không đếm thiếu nếu đã có compliance valid theo group.
    -- ================================================================
    CREATE TEMPORARY TABLE tmp_var_group AS
    SELECT
        var_g.MasterId,
        var_g.RefTypeId,
        icg.CountryCode
    FROM tmp_valid_applied_refs var_g
    INNER JOIN tmp_input_country_groups icg
            ON icg.GroupCode = var_g.RefTypeValue;

    ALTER TABLE tmp_var_group
        ADD INDEX idx_lookup (MasterId, RefTypeId, CountryCode(20));

    -- ================================================================
    -- STEP 12: Missing rows (IsIndividual = 1)
    --   [PERF FIX] Thay 3 correlated subqueries inline bằng LEFT JOIN
    --   vào pre-aggregated tables (tmp_cmc_has_all, tmp_valid_applied_refs).
    --   Lý do chậm cũ: EXISTS/NOT EXISTS chạy lại mỗi dòng của
    --   (tmp_matched_masters × cmc × dv) → O(n³) scan.
    -- ================================================================
    CREATE TEMPORARY TABLE tmp_missing_rows AS
    SELECT
        mm.MasterId,
        dv.InputValue AS missing_input_value
    FROM tmp_matched_masters mm
    INNER JOIN compl_master_conditions cmc
            ON cmc.MasterId  = mm.MasterId
           AND cmc.ComplType = 1
           AND cmc.Operator != 'NOT IN'                   -- [NOT IN] Bỏ NOT IN
    INNER JOIN compl_reference_types crt ON crt.Id = cmc.RefTypeId
    INNER JOIN tmp_distinct_input_values dv
            ON dv.MasterId  = mm.MasterId
           AND dv.RefTypeId = cmc.RefTypeId
    -- [PERF] Thay EXISTS('ALL') → LEFT JOIN
    LEFT JOIN tmp_cmc_has_all ha
           ON ha.ConditionId = cmc.Id
    -- [PERF] Thay EXISTS(exact value) → LEFT JOIN
    LEFT JOIN compl_master_condition_values cmcv_exact
           ON cmcv_exact.ConditionId  = cmc.Id
          AND cmcv_exact.RefTypeValue = dv.InputValue
    -- [COUNTRY GROUP] Condition value khớp qua group
    LEFT JOIN tmp_cmcv_group cmcv_grp
           ON cmcv_grp.ConditionId = cmc.Id
          AND cmcv_grp.CountryCode = dv.InputValue
          AND crt.Code             = 'COUNTRY'
    -- [PERF] Thay NOT EXISTS(valid compliance exact) → LEFT JOIN
    LEFT JOIN tmp_valid_applied_refs var_exact
           ON var_exact.MasterId     = mm.MasterId
          AND var_exact.RefTypeId    = cmc.RefTypeId
          AND var_exact.RefTypeValue = dv.InputValue
    -- [COUNTRY GROUP] Không đếm thiếu nếu đã có compliance valid theo group
    LEFT JOIN tmp_var_group var_grp
           ON var_grp.MasterId    = mm.MasterId
          AND var_grp.RefTypeId   = cmc.RefTypeId
          AND var_grp.CountryCode = dv.InputValue
          AND crt.Code            = 'COUNTRY'
    WHERE mm.IsIndividual = 1
      AND (
              ha.ConditionId         IS NOT NULL   -- khớp ALL
          OR  cmcv_exact.ConditionId IS NOT NULL   -- khớp exact value
          OR  cmcv_grp.ConditionId   IS NOT NULL   -- khớp COUNTRY group
          )
      AND var_exact.MasterId IS NULL                -- chưa có compliance valid exact
      AND var_grp.MasterId   IS NULL                -- chưa có compliance valid group
    GROUP BY mm.MasterId, dv.InputValue;

    -- ================================================================
    -- STEP 12a: Pre-aggregate cho master-level missing
    --   Thay thế 4 correlated EXISTS/NOT EXISTS trong STEP 13.
    -- ================================================================
    CREATE TEMPORARY TABLE tmp_master_has_refs AS
    SELECT DISTINCT MasterId FROM compl_references;

    ALTER TABLE tmp_master_has_refs ADD PRIMARY KEY (MasterId);

    CREATE TEMPORARY TABLE tmp_master_has_specific_cond AS
    SELECT DISTINCT MasterId FROM compl_master_conditions WHERE ComplType = 1;

    ALTER TABLE tmp_master_has_specific_cond ADD PRIMARY KEY (MasterId);

    CREATE TEMPORARY TABLE tmp_master_has_applied AS
    SELECT DISTINCT MasterId FROM tmp_applied_rows WHERE rn = 1;

    ALTER TABLE tmp_master_has_applied ADD PRIMARY KEY (MasterId);

    -- ================================================================
    -- STEP 13: Master-level missing rows (IsIndividual = 0)
    --   [PERF FIX] Thay 4 correlated EXISTS/NOT EXISTS bằng LEFT JOIN
    --   vào pre-aggregated tables — cùng pattern với SP chính STEP 15.
    -- ================================================================
    CREATE TEMPORARY TABLE tmp_master_missing_rows AS
    SELECT mm.MasterId
    FROM tmp_matched_masters mm
    LEFT JOIN tmp_master_has_refs          hr ON hr.MasterId = mm.MasterId
    LEFT JOIN tmp_master_has_specific_cond sc ON sc.MasterId = mm.MasterId
    LEFT JOIN tmp_master_has_applied       ha ON ha.MasterId = mm.MasterId
    WHERE mm.IsIndividual = 0
      AND sc.MasterId IS NULL                        -- không có specific condition (ComplType=1)
      AND (
          hr.MasterId IS NULL                        -- case 1: không có reference nào
          OR
          (hr.MasterId IS NOT NULL AND ha.MasterId IS NULL)  -- case 2: có ref nhưng chưa applied
      )
    GROUP BY mm.MasterId;

    -- ================================================================
    -- STEP 14: Tính toán và trả về kết quả  ← giống hệt SP chính
    -- ================================================================

    -- Applied
    SET @total_applied = (
        SELECT COUNT(*) FROM tmp_applied_rows WHERE rn = 1
    );

    -- Overdue: individual missing + has expired compliance
    SELECT
        COUNT(*) AS total,
        GROUP_CONCAT(DISTINCT mr.MasterId ORDER BY mr.MasterId SEPARATOR ',') AS Ids
    INTO
        @overdue_individual,
        @overdue_individual_master_ids
    FROM tmp_missing_rows mr
    WHERE EXISTS (
        SELECT 1 FROM tmp_expired_compliances ec
        WHERE ec.MasterId    = mr.MasterId
          AND ec.RefTypeValue = mr.missing_input_value
          AND ec.rn           = 1
    );

    -- Overdue: master-level missing + has expired compliance
    SELECT
        COUNT(*) AS total,
        GROUP_CONCAT(DISTINCT mmr.MasterId ORDER BY mmr.MasterId SEPARATOR ',') AS Ids
    INTO
        @overdue_master,
        @overdue_master_ids
    FROM tmp_master_missing_rows mmr
    WHERE EXISTS (
        SELECT 1 FROM tmp_expired_compliances ec
        WHERE ec.MasterId    = mmr.MasterId
          AND ec.RefComplType = 0
          AND ec.rn           = 1
    );

    SET @total_overdue = @overdue_individual + @overdue_master;

    -- Missing: individual missing + không có expired compliance
    SELECT
        COUNT(*) AS total,
        GROUP_CONCAT(DISTINCT mr.MasterId ORDER BY mr.MasterId SEPARATOR ',') AS Ids
    INTO
        @missing_individual,
        @missing_individual_master_ids
    FROM tmp_missing_rows mr
    WHERE NOT EXISTS (
        SELECT 1 FROM tmp_expired_compliances ec
        WHERE ec.MasterId    = mr.MasterId
          AND ec.RefTypeValue = mr.missing_input_value
          AND ec.rn           = 1
    );

    -- Missing: master-level missing + không có expired compliance
    SELECT
        COUNT(*) AS total,
        GROUP_CONCAT(DISTINCT mmr.MasterId ORDER BY mmr.MasterId SEPARATOR ',') AS Ids
    INTO
        @missing_master,
        @missing_master_ids
    FROM tmp_master_missing_rows mmr
    WHERE NOT EXISTS (
        SELECT 1
        FROM tmp_expired_compliances ec
        WHERE ec.MasterId    = mmr.MasterId
          AND ec.RefComplType = 0
          AND ec.rn           = 1
    );

    -- Tạo bảng để lấy mail
    CREATE TEMPORARY TABLE tmp_all_master_ids (MasterId BIGINT PRIMARY KEY);

    -- Overdue: individual
    INSERT IGNORE INTO tmp_all_master_ids (MasterId)
    SELECT DISTINCT mr.MasterId
    FROM tmp_missing_rows mr
    WHERE EXISTS (
        SELECT 1 FROM tmp_expired_compliances ec
        WHERE ec.MasterId    = mr.MasterId
          AND ec.RefTypeValue = mr.missing_input_value
          AND ec.rn           = 1
    );

    -- Overdue: master-level
    INSERT IGNORE INTO tmp_all_master_ids (MasterId)
    SELECT DISTINCT mmr.MasterId
    FROM tmp_master_missing_rows mmr
    WHERE EXISTS (
        SELECT 1 FROM tmp_expired_compliances ec
        WHERE ec.MasterId    = mmr.MasterId
          AND ec.RefComplType = 0
          AND ec.rn           = 1
    );

    -- Missing: individual
    INSERT IGNORE INTO tmp_all_master_ids (MasterId)
    SELECT DISTINCT mr.MasterId
    FROM tmp_missing_rows mr
    WHERE NOT EXISTS (
        SELECT 1 FROM tmp_expired_compliances ec
        WHERE ec.MasterId    = mr.MasterId
          AND ec.RefTypeValue = mr.missing_input_value
          AND ec.rn           = 1
    );

    -- Missing: master-level
    INSERT IGNORE INTO tmp_all_master_ids (MasterId)
    SELECT DISTINCT mmr.MasterId
    FROM tmp_master_missing_rows mmr
    WHERE NOT EXISTS (
        SELECT 1
        FROM tmp_expired_compliances ec
        WHERE ec.MasterId    = mmr.MasterId
          AND ec.RefComplType = 0
          AND ec.rn           = 1
    );

    SELECT
        GROUP_CONCAT(DISTINCT CASE WHEN ccge.GroupType = 1 THEN cged.ResponseEmail END),
        GROUP_CONCAT(DISTINCT CASE WHEN ccge.GroupType = 2 THEN cged.ResponseEmail END)
    INTO
        @ResponsibleEmails,
        @AlertEmails
    FROM tmp_all_master_ids ids
    JOIN compl_master_group_email ccge ON ccge.MasterId = ids.MasterId
    LEFT JOIN compl_group_email_detail cged
        ON cged.GroupEmailId = ccge.GroupEmailId
       AND cged.IsActive = TRUE;

    SET @total_missing = @missing_individual + @missing_master;

    SELECT
        @total_applied  AS TotalApplied,
        @total_overdue  AS TotalOverdue,
        ROUND(@total_missing) AS TotalMissing,
        CONCAT(@missing_individual_master_ids, ',', @missing_master_ids) AS MissingMasterIds,
        CONCAT(@overdue_individual_master_ids, ',', @overdue_master_ids) AS OverdueMasterIds,
        @ResponsibleEmails AS ResponsibleEmails,
        @AlertEmails       AS AlertEmails;

    -- ================================================================
    -- CLEANUP
    -- ================================================================
    DROP TEMPORARY TABLE IF EXISTS tmp_input_data;
    DROP TEMPORARY TABLE IF EXISTS tmp_input_eav;                 -- [NOT IN]
    DROP TEMPORARY TABLE IF EXISTS tmp_input_country_groups;      -- [NOT IN]
    DROP TEMPORARY TABLE IF EXISTS tmp_cmcv_group;                -- [COUNTRY GROUP]
    DROP TEMPORARY TABLE IF EXISTS tmp_var_group;                 -- [COUNTRY GROUP]
    DROP TEMPORARY TABLE IF EXISTS tmp_not_in_excluded;           -- [NOT IN]
    DROP TEMPORARY TABLE IF EXISTS tmp_valid_masters;
    DROP TEMPORARY TABLE IF EXISTS tmp_condition_group_match;
    DROP TEMPORARY TABLE IF EXISTS tmp_master_condition_counts;
    DROP TEMPORARY TABLE IF EXISTS tmp_master_input_match;
    DROP TEMPORARY TABLE IF EXISTS tmp_matched_masters;
    DROP TEMPORARY TABLE IF EXISTS tmp_all_references;
    DROP TEMPORARY TABLE IF EXISTS tmp_valid_references;
    DROP TEMPORARY TABLE IF EXISTS tmp_applied_rows;
    DROP TEMPORARY TABLE IF EXISTS tmp_expired_compliances;
    DROP TEMPORARY TABLE IF EXISTS tmp_distinct_input_values;
    DROP TEMPORARY TABLE IF EXISTS tmp_cmc_has_all;               -- [PERF]
    DROP TEMPORARY TABLE IF EXISTS tmp_valid_applied_refs;        -- [PERF]
    DROP TEMPORARY TABLE IF EXISTS tmp_master_has_refs;           -- [PERF]
    DROP TEMPORARY TABLE IF EXISTS tmp_master_has_specific_cond;  -- [PERF]
    DROP TEMPORARY TABLE IF EXISTS tmp_master_has_applied;        -- [PERF]
    DROP TEMPORARY TABLE IF EXISTS tmp_missing_rows;
    DROP TEMPORARY TABLE IF EXISTS tmp_master_missing_rows;
    DROP TEMPORARY TABLE IF EXISTS tmp_all_master_ids;

END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_mark_notifications_as_read` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_mark_notifications_as_read`(
    IN p_UserEmail VARCHAR(100),
    OUT p_RowsUpdated INT
)
BEGIN
    UPDATE compl_notifications
    SET 
        IsRead = 1,
        UpdatedDate = NOW(),
        UpdatedBy = p_UserEmail
    WHERE 
        UserEmail = p_UserEmail
        AND IsRead = 0;
    
    SET p_RowsUpdated = ROW_COUNT();
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_process_master_defaults` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_process_master_defaults`(
  IN p_job_user VARCHAR(50)
)
BEGIN
  DECLARE v_done_trk      INT DEFAULT FALSE;
  DECLARE v_trk_id        BIGINT;
  DECLARE v_trk_ref_type  BIGINT;
  DECLARE v_trk_trigger_id BIGINT;
  DECLARE v_trk_code        VARCHAR(100);
  DECLARE v_trk_name        VARCHAR(255);
  DECLARE v_trk_ref_value   TEXT;
  DECLARE v_trk_group_value VARCHAR(255);

  DECLARE v_done_cfg      INT DEFAULT FALSE;
  DECLARE v_cfg_id        BIGINT;

  DECLARE v_done_tmpl     INT DEFAULT FALSE;
  DECLARE v_tmpl_id       BIGINT;
  DECLARE v_tmpl_name     VARCHAR(255);
  DECLARE v_tmpl_valid_from DATETIME;
  DECLARE v_tmpl_valid_to   DATETIME;
  DECLARE v_tmpl_num_day_alert INT;
  DECLARE v_tmpl_description VARCHAR(500);

  DECLARE v_done_cond     INT DEFAULT FALSE;
  DECLARE v_cond_id       BIGINT;
  DECLARE v_cond_ref_type BIGINT;
  DECLARE v_cond_source   ENUM('NEW_VALUE','FIXED','NOT_IN');
  DECLARE v_cond_operator VARCHAR(10);
  DECLARE v_cond_logical  INT;
  DECLARE v_cond_compl_type INT;
  DECLARE v_cond_display_type INT;

  DECLARE v_new_master_id   BIGINT;
  DECLARE v_new_master_code VARCHAR(50);
  DECLARE v_now_utc         DATETIME;
  DECLARE v_mc_id           BIGINT;
  DECLARE v_seq_id          BIGINT;
  DECLARE v_dup_check       INT DEFAULT 0;
  DECLARE v_has_success     INT DEFAULT 0;
  DECLARE v_sql_state       CHAR(5) DEFAULT '';
  DECLARE v_sql_msg         TEXT    DEFAULT '';

  DECLARE v_remaining  TEXT;
  DECLARE v_cur_val    VARCHAR(255);
  DECLARE v_comma_pos  INT;

  DECLARE cur_trk CURSOR FOR
    SELECT Id, RefTypeId, TriggerId, Code, Name, RefValue, GroupValue
    FROM   compl_ref_tracked_objects
    WHERE  IsNew = 1
    ORDER  BY CreatedDate;

  DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done_trk = TRUE;

  CREATE TEMPORARY TABLE IF NOT EXISTS tmp_master_default_process_configs (
    ConfigId BIGINT NOT NULL PRIMARY KEY
  ) ENGINE=MEMORY;

  OPEN cur_trk;

  trk_loop: LOOP
    SET v_done_trk    = FALSE;
    SET v_has_success = 0;

    FETCH cur_trk INTO v_trk_id, v_trk_ref_type, v_trk_trigger_id, v_trk_code, v_trk_name, v_trk_ref_value, v_trk_group_value;
    IF v_done_trk THEN LEAVE trk_loop; END IF;

    SET v_trk_name = COALESCE(NULLIF(TRIM(v_trk_name), ''), v_trk_code);

    TRUNCATE TABLE tmp_master_default_process_configs;

    INSERT INTO tmp_master_default_process_configs (ConfigId)
    SELECT cfg.Id
    FROM   compl_master_default_configs cfg
    WHERE  cfg.IsActive = 1
      AND  EXISTS (
             SELECT 1
             FROM   compl_ref_tracked_objects main_gate
             WHERE  main_gate.Id = v_trk_id
               AND  main_gate.RefTypeId = cfg.TriggerRefTypeId
               AND  main_gate.TriggerId = cfg.TriggerId
               AND  main_gate.IsNew = 1
           )
      AND  NOT EXISTS (
             SELECT 1
             FROM   compl_master_default_trigger_conditions gate
             WHERE  gate.ConfigId = cfg.Id
               AND  NOT EXISTS (
                      -- Option A: another tracked object with matching RefTypeId has RefValue containing the condition value
                      SELECT 1
                      FROM   compl_master_default_trigger_condition_values gate_value
                      JOIN   compl_ref_tracked_objects gate_trk
                        ON   gate_trk.RefTypeId = gate.TriggerRefTypeId
                       AND   gate_trk.IsNew = 1
                       AND   gate_trk.RefValue LIKE CONCAT('%', gate_value.RefTypeValue, '%')
                      WHERE  gate_value.ConditionId = gate.Id
                    )
               AND  NOT EXISTS (
                      -- Option B: current tracked object's GroupValue matches the condition value
                      SELECT 1
                      FROM   compl_master_default_trigger_condition_values gate_value
                      WHERE  gate_value.ConditionId = gate.Id
                        AND  gate_value.RefTypeValue = v_trk_group_value
                    )
           );

    BEGIN
      DECLARE cur_cfg CURSOR FOR
        SELECT ConfigId
        FROM   tmp_master_default_process_configs
        ORDER  BY ConfigId;

      DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done_cfg = TRUE;

      OPEN cur_cfg;

      cfg_loop: LOOP
        SET v_done_cfg = FALSE;
        FETCH cur_cfg INTO v_cfg_id;
        IF v_done_cfg THEN LEAVE cfg_loop; END IF;

        BEGIN
          DECLARE cur_tmpl CURSOR FOR
            SELECT Id, Name, ValidFrom, ValidTo, NumDayAlert, Description
            FROM   compl_master_default_templates
            WHERE  ConfigId = v_cfg_id
            ORDER  BY SortOrder;

          DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done_tmpl = TRUE;

          OPEN cur_tmpl;

          tmpl_loop: LOOP
            SET v_done_tmpl     = FALSE;
            SET v_new_master_id = NULL;

            FETCH cur_tmpl INTO
              v_tmpl_id, v_tmpl_name, v_tmpl_valid_from,
              v_tmpl_valid_to, v_tmpl_num_day_alert, v_tmpl_description;
            IF v_done_tmpl THEN LEAVE tmpl_loop; END IF;

            SELECT COUNT(*) INTO v_dup_check
            FROM   compl_master_default_logs
            WHERE  TemplateId      = v_tmpl_id
              AND  TrackedObjectId = v_trk_id
              AND  Status          = 'SUCCESS';

            IF v_dup_check > 0 THEN
              INSERT INTO compl_master_default_logs
                (ConfigId, TemplateId, TrackedObjectId, Status, ErrorMessage)
              VALUES
                (v_cfg_id, v_tmpl_id, v_trk_id, 'SKIPPED',
                 CONCAT('Duplicate: TemplateId=', v_tmpl_id,
                        ' TrackedObjectId=', v_trk_id));
              ITERATE tmpl_loop;
            END IF;

            BEGIN
              DECLARE EXIT HANDLER FOR SQLEXCEPTION
              BEGIN
                GET DIAGNOSTICS CONDITION 1
                  v_sql_state = RETURNED_SQLSTATE,
                  v_sql_msg   = MESSAGE_TEXT;
                ROLLBACK;
                INSERT INTO compl_master_default_logs
                  (ConfigId, TemplateId, TrackedObjectId, Status, ErrorMessage)
                VALUES
                  (v_cfg_id, v_tmpl_id, v_trk_id, 'FAILED',
                   CONCAT('[', v_sql_state, '] ', v_sql_msg));
              END;

              START TRANSACTION;

              SELECT Id
              INTO   v_seq_id
              FROM   compl_code_sequences
              WHERE  Prefix = 'MAS'
              LIMIT  1;

              UPDATE compl_code_sequences
              SET    Number = LAST_INSERT_ID(Number + 1)
              WHERE  Id = v_seq_id
              LIMIT  1;

              SELECT CONCAT(Prefix, `Separator`, LPAD(LAST_INSERT_ID(), PaddingLength, '0'))
              INTO   v_new_master_code
              FROM   compl_code_sequences
              WHERE  Id = v_seq_id;

              SET v_now_utc = UTC_TIMESTAMP();

              INSERT INTO compl_masters
                (Code, Name, ValidFrom, ValidTo, NumDayAlert, Description,
                 CreatedDate, CreatedBy, UpdatedDate)
              VALUES
                (v_new_master_code,
                 CONCAT(v_tmpl_name, ' - ', v_trk_name),
                 v_tmpl_valid_from,
                 v_tmpl_valid_to,
                 v_tmpl_num_day_alert,
                 v_tmpl_description,
                 v_now_utc,
                 p_job_user,
                 v_now_utc);

              SET v_new_master_id = LAST_INSERT_ID();

              INSERT INTO compl_master_group_email
                (MasterId, GroupEmailId, GroupType, CreatedDate, CreatedBy)
              SELECT v_new_master_id, GroupEmailId, GroupType, NOW(), p_job_user
              FROM   compl_master_default_template_group_email
              WHERE  TemplateId = v_tmpl_id;

              BEGIN
                DECLARE cur_cond CURSOR FOR
                  SELECT Id, RefTypeId, ValueSource, Operator, Logical, ComplType, IFNULL(DisplayType, 0)
                  FROM   compl_master_default_template_conditions
                  WHERE  TemplateId = v_tmpl_id
                  ORDER  BY SortOrder;

                DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done_cond = TRUE;

                OPEN cur_cond;

                cond_loop: LOOP
                  SET v_done_cond = FALSE;
                  FETCH cur_cond INTO
                    v_cond_id, v_cond_ref_type,
                    v_cond_source, v_cond_operator, v_cond_logical,
                    v_cond_compl_type, v_cond_display_type;
                  IF v_done_cond THEN LEAVE cond_loop; END IF;

                  CASE v_cond_source
                    WHEN 'NEW_VALUE' THEN
                      SET v_remaining = TRIM(v_trk_ref_value);

                      new_val_loop: LOOP
                        IF v_remaining IS NULL OR LENGTH(v_remaining) = 0
                        THEN LEAVE new_val_loop; END IF;

                        SET v_comma_pos = LOCATE(',', v_remaining);

                        IF v_comma_pos > 0 THEN
                          SET v_cur_val   = TRIM(SUBSTRING(v_remaining, 1, v_comma_pos - 1));
                          SET v_remaining = TRIM(SUBSTRING(v_remaining, v_comma_pos + 1));
                        ELSE
                          SET v_cur_val   = TRIM(v_remaining);
                          SET v_remaining = '';
                        END IF;

                        IF LENGTH(v_cur_val) > 0 THEN
                          INSERT INTO compl_master_conditions
                            (MasterId, RefTypeId, Operator, Logical, ComplType, DisplayType)
                          VALUES
                            (v_new_master_id, v_cond_ref_type,
                             v_cond_operator, v_cond_logical,
                             v_cond_compl_type, v_cond_display_type);

                          INSERT INTO compl_master_condition_values (ConditionId, RefTypeValue)
                          VALUES (LAST_INSERT_ID(), v_cur_val);
                        END IF;
                      END LOOP new_val_loop;

                    WHEN 'FIXED' THEN
                      INSERT INTO compl_master_conditions
                        (MasterId, RefTypeId, Operator, Logical, ComplType, DisplayType)
                      VALUES
                        (v_new_master_id, v_cond_ref_type,
                         v_cond_operator, v_cond_logical,
                         v_cond_compl_type, v_cond_display_type);

                      SET v_mc_id = LAST_INSERT_ID();

                      INSERT INTO compl_master_condition_values (ConditionId, RefTypeValue)
                      SELECT v_mc_id, RefTypeValue
                      FROM   compl_master_default_template_condition_values
                      WHERE  ConditionId = v_cond_id
                      ORDER  BY SortOrder;

                    WHEN 'NOT_IN' THEN
                      INSERT INTO compl_master_conditions
                        (MasterId, RefTypeId, Operator, Logical, ComplType, DisplayType)
                      VALUES
                        (v_new_master_id, v_cond_ref_type,
                         v_cond_operator, v_cond_logical,
                         v_cond_compl_type, v_cond_display_type);

                      SET v_mc_id = LAST_INSERT_ID();

                      INSERT INTO compl_master_condition_values (ConditionId, RefTypeValue)
                      SELECT v_mc_id, RefTypeValue
                      FROM   compl_master_default_template_condition_values
                      WHERE  ConditionId = v_cond_id
                      ORDER  BY SortOrder;
                  END CASE;
                END LOOP cond_loop;
                CLOSE cur_cond;
              END;

              INSERT INTO compl_history
                (TableName, RecordId, RecordCode, Action, ActionDetail,
                 OldValue, NewValue, ActionDate, ActionBy, IsVersionChange)
              VALUES
                ('compl_masters',
                 v_new_master_id,
                 v_new_master_code,
                 'Created',
                 'Created new record',
                 NULL,
                 JSON_OBJECT(
                   'Id', v_new_master_id,
                   'Code', v_new_master_code,
                   'Name', CONCAT(v_tmpl_name, ' - ', v_trk_name),
                   'ValidFrom', v_tmpl_valid_from,
                   'ValidTo', v_tmpl_valid_to,
                   'NumDayAlert', v_tmpl_num_day_alert,
                   'Description', v_tmpl_description,
                   'IsDelete', 0,
                   'VersionNo', 1,
                   'ReplacedById', NULL,
                   'IsIndividual', 0,
                   'DuplicateId', NULL,
                   'CreatedDate', v_now_utc,
                   'CreatedBy', p_job_user,
                   'UpdatedDate', v_now_utc,
                   'UpdatedBy', NULL
                 ),
                 v_now_utc,
                 p_job_user,
                 0);

              COMMIT;

              SET v_has_success = 1;

              INSERT INTO compl_master_default_logs
                (ConfigId, TemplateId, TrackedObjectId, CreatedMasterId, Status)
              VALUES
                (v_cfg_id, v_tmpl_id, v_trk_id, v_new_master_id, 'SUCCESS');
            END;
          END LOOP tmpl_loop;
          CLOSE cur_tmpl;
        END;
      END LOOP cfg_loop;
      CLOSE cur_cfg;
    END;

    IF v_has_success > 0 THEN
      UPDATE compl_ref_tracked_objects
      SET    IsNew = 0, UpdatedDate = NOW(), UpdatedBy = p_job_user
      WHERE  IsNew = 1
             -- AND Id = v_trk_id
             ;
    END IF;
  END LOOP trk_loop;
  CLOSE cur_trk;

  DROP TEMPORARY TABLE IF EXISTS tmp_master_default_process_configs;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2026-08-25 14:50:31
