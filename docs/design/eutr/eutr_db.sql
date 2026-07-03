CREATE TABLE `eutr_master_documents`(
    `Id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `StepId` BIGINT UNSIGNED NULL,
    `Prefix` VARCHAR(255) NULL,
    `CreatedBy` VARCHAR(50) NULL,
    `CreatedDate` DATETIME NULL,
    `UpdatedBy` VARCHAR(50) NULL,
    `UpdatedDate` DATETIME NULL
);
CREATE TABLE `eutr_steps`(
    `Id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `Name` VARCHAR(255) NULL,
    `CreatedBy` VARCHAR(50) NULL,
    `CreatedDate` DATETIME NULL,
    `UpdatedBy` VARCHAR(50) NULL,
    `UpdatedDate` DATETIME NULL
);
CREATE TABLE `eutr_templates`(
    `Id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `Code` VARCHAR(255) NOT NULL,
    `Name` VARCHAR(255) NULL,
    `VendorCode` VARCHAR(50) NULL,
    `IsDefault` TINYINT NULL DEFAULT 0,
    `VersionId` TINYINT NOT NULL DEFAULT 1,
    `CreatedBy` VARCHAR(50) NULL,
    `CreatedDate` DATETIME NULL,
    `UpdatedBy` VARCHAR(50) NULL,
    `UpdatedDate` DATETIME NULL,
    `AlertFor` VARCHAR(50) NOT NULL,
    `IsDeleted` TINYINT NULL DEFAULT 0,
    `IsHide` TINYINT NULL DEFAULT 0
);
CREATE TABLE `eutr_template_details`(
    `Id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `TemplateId` BIGINT UNSIGNED NULL,
    `ParentId` BIGINT NOT NULL,
    `StepId` BIGINT UNSIGNED NULL,
    `RequirementType` TINYINT NULL DEFAULT 0,
    `TakeFrom` TINYINT NOT NULL,
    `DisplayOrder` INT NULL DEFAULT 0,
    `CreatedBy` VARCHAR(50) NULL,
    `CreatedDate` DATETIME NULL,
    `UpdatedBy` VARCHAR(50) NULL,
    `UpdatedDate` DATETIME NULL
);

CREATE TABLE `eutr_references`(
    `Id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `RefId` BIGINT UNSIGNED NULL,
    `DocumentId` BIGINT UNSIGNED NULL,
    `RefType` TINYINT NULL DEFAULT 0,
    `RefValue` VARCHAR(255) NULL,
    `CreatedBy` VARCHAR(50) NULL,
    `CreatedDate` DATETIME NULL,
    `UpdatedBy` VARCHAR(50) NULL,
    `UpdatedDate` DATETIME NULL
);
CREATE TABLE `eutr_documents`(
    `Id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `Name` BIGINT NULL,
    `FileId` VARCHAR(255) NULL,
    `ValidFrom` DATE NULL,
    `ValidTo` DATE NULL,
    `CreatedBy` VARCHAR(50) NULL,
    `CreatedDate` DATETIME NULL,
    `UpdatedBy` VARCHAR(50) NULL,
    `UpdatedDate` DATETIME NULL
);
ALTER TABLE
    `eutr_template_details` ADD CONSTRAINT `eutr_template_details_templateid_foreign` FOREIGN KEY(`TemplateId`) REFERENCES `eutr_templates`(`Id`);
ALTER TABLE
    `eutr_references` ADD CONSTRAINT `eutr_references_documentid_foreign` FOREIGN KEY(`DocumentId`) REFERENCES `eutr_documents`(`Id`);
ALTER TABLE
    `eutr_template_details` ADD CONSTRAINT `eutr_template_details_stepid_foreign` FOREIGN KEY(`StepId`) REFERENCES `eutr_steps`(`Id`);
ALTER TABLE
    `eutr_references` ADD CONSTRAINT `eutr_references_refid_foreign` FOREIGN KEY(`RefId`) REFERENCES `eutr_template_details`(`Id`);
ALTER TABLE
    `eutr_master_documents` ADD CONSTRAINT `eutr_master_documents_stepid_foreign` FOREIGN KEY(`StepId`) REFERENCES `eutr_steps`(`Id`);