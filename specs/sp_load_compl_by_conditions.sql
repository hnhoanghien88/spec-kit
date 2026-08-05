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
        MasterName,
        MasterValidFrom,
        MasterValidTo,
        NumDayAlert                                             AS MasterNumDayAlert,
        MasterDescription,
        MasterVersionNo,
        Status,
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
    -- STEP 20b: Loại các dòng bị "phủ" bởi compliance của Master cha
    --   (Root) trong cây phân cấp compl_master_hierarchies.
    --
    --   Quy tắc:
    --   - Với mỗi dòng root_row trong tmp_result có Code <> '' và
    --     root_row.MasterCode là 1 Root (ParentCode = '') trong
    --     compl_master_hierarchies:
    --       + Lấy đệ quy toàn bộ MasterCode con/cháu của Root này theo
    --         ParentCode (KHÔNG gồm chính Root).
    --       + Xoá khỏi tmp_result các dòng khác (tr) có
    --         tr.MasterCode = <1 MasterCode con/cháu> VÀ
    --         tr.MappedInputValue = root_row.MappedInputValue
    --         — vì compliance đó coi như đã được đáp ứng qua Master cha,
    --         không cần liệt kê riêng cho Master con (bất kể dòng con là
    --         APPLIED hay MISSING, bất kể Code của dòng con là gì).
    --   - Dòng root_row dùng để xác định điều kiện xoá luôn được giữ lại
    --     (không tự xoá chính nó dù trùng điều kiện).
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
    -- riêng trước, rồi mới DELETE trên tmp_result (chỉ mở 1 lần).
    DROP TEMPORARY TABLE IF EXISTS tmp_hierarchy_root_matches;
    CREATE TEMPORARY TABLE tmp_hierarchy_root_matches AS
    SELECT DISTINCT
        tr.MasterCode       AS RootMasterCode,
        tr.MappedInputValue AS MappedInputValue
    FROM tmp_result tr
    WHERE tr.Code <> '';

    ALTER TABLE tmp_hierarchy_root_matches
        ADD INDEX idx_root_miv (RootMasterCode, MappedInputValue(191));

    DELETE tr
    FROM tmp_result tr
    INNER JOIN tmp_hierarchy_root_matches rm
            ON rm.MappedInputValue = tr.MappedInputValue
    INNER JOIN tmp_hierarchy_descendants hd
            ON hd.RootMasterCode       = rm.RootMasterCode
           AND hd.DescendantMasterCode = tr.MasterCode
    WHERE tr.MasterCode <> rm.RootMasterCode;       -- không tự xoá dòng root đang dùng để so khớp

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

END