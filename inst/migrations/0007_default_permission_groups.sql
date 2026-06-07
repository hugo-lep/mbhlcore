-- Migration 0007: groupes de permissions par défaut et matrice initiale
-- 8 groupes standards MBHL. ON CONFLICT DO NOTHING = idempotent.
-- Seules les permissions TRUE sont insérées (default deny: absent = refusé).
--
-- Format des clés: {package}.{area}.{permission}
--   ex: mbhlMaintenance.work_orders.can_open_wo

INSERT INTO mbhlcore.permission_groups (group_name, group_description, is_active)
VALUES
    ('apprenti_ame',             'Apprenti AME',              TRUE),
    ('ame',                      'AME',                       TRUE),
    ('lead_ame',                 'Lead AME',                  TRUE),
    ('maintenance_control',      'Maintenance Control',       TRUE),
    ('gestionnaire_maintenance', 'Gestionnaire maintenance',  TRUE),
    ('magasinier_l1',            'Magasinier niveau 1',       TRUE),
    ('magasinier_l2',            'Magasinier niveau 2',       TRUE),
    ('flight_tech_dispatcher',   'Flight Tech / Dispatcher',  TRUE)
ON CONFLICT (group_name) DO NOTHING;

INSERT INTO mbhlcore.permission_group_items (group_id, permission_key, is_granted)
SELECT g.group_id, p.permission_key, TRUE
FROM mbhlcore.permission_groups g
JOIN (VALUES
    -- apprenti_ame
    ('apprenti_ame', 'mbhlMaintenance.work_orders.can_view_wo'),
    ('apprenti_ame', 'mbhlMaintenance.work_orders.can_add_task'),
    ('apprenti_ame', 'mbhlMaintenance.inspections.can_view_inspections'),
    ('apprenti_ame', 'mbhlMagasin.inventory.can_view_inventory'),

    -- ame
    ('ame', 'mbhlMaintenance.work_orders.can_view_wo'),
    ('ame', 'mbhlMaintenance.work_orders.can_open_wo'),
    ('ame', 'mbhlMaintenance.work_orders.can_add_task'),
    ('ame', 'mbhlMaintenance.work_orders.can_close_task'),
    ('ame', 'mbhlMaintenance.work_orders.can_close_wo'),
    ('ame', 'mbhlMaintenance.inspections.can_view_inspections'),
    ('ame', 'mbhlMaintenance.inspections.can_manage_deferrals'),
    ('ame', 'mbhlMagasin.inventory.can_view_inventory'),
    ('ame', 'mbhlMagasin.inventory.can_view_costs'),

    -- lead_ame
    ('lead_ame', 'mbhlMaintenance.work_orders.can_view_wo'),
    ('lead_ame', 'mbhlMaintenance.work_orders.can_open_wo'),
    ('lead_ame', 'mbhlMaintenance.work_orders.can_stage_wo'),
    ('lead_ame', 'mbhlMaintenance.work_orders.can_add_task'),
    ('lead_ame', 'mbhlMaintenance.work_orders.can_close_task'),
    ('lead_ame', 'mbhlMaintenance.work_orders.can_close_wo'),
    ('lead_ame', 'mbhlMaintenance.inspections.can_view_inspections'),
    ('lead_ame', 'mbhlMaintenance.inspections.can_create_inspection'),
    ('lead_ame', 'mbhlMaintenance.inspections.can_edit_inspection'),
    ('lead_ame', 'mbhlMaintenance.inspections.can_manage_packages'),
    ('lead_ame', 'mbhlMaintenance.inspections.can_manage_deferrals'),
    ('lead_ame', 'mbhlMagasin.inventory.can_view_inventory'),
    ('lead_ame', 'mbhlMagasin.inventory.can_view_costs'),

    -- maintenance_control
    ('maintenance_control', 'mbhlMaintenance.work_orders.can_view_wo'),
    ('maintenance_control', 'mbhlMaintenance.work_orders.can_stage_wo'),
    ('maintenance_control', 'mbhlMaintenance.work_orders.can_review_wo'),
    ('maintenance_control', 'mbhlMaintenance.work_orders.can_void_completion'),
    ('maintenance_control', 'mbhlMaintenance.inspections.can_view_inspections'),
    ('maintenance_control', 'mbhlMaintenance.inspections.can_create_inspection'),
    ('maintenance_control', 'mbhlMaintenance.inspections.can_edit_inspection'),
    ('maintenance_control', 'mbhlMaintenance.inspections.can_approve_extension'),
    ('maintenance_control', 'mbhlMaintenance.inspections.can_manage_packages'),
    ('maintenance_control', 'mbhlMaintenance.inspections.can_manage_deferrals'),
    ('maintenance_control', 'mbhlMagasin.inventory.can_view_costs'),
    ('maintenance_control', 'mbhlMagasin.inventory.can_adjust_inventory'),
    ('maintenance_control', 'mbhlMagasin.inventory.can_manage_catalog'),
    ('maintenance_control', 'mbhlComptable.accounting.can_view_acct_reports'),
    ('maintenance_control', 'mbhlComptable.accounting.can_reconcile'),
    ('maintenance_control', 'mbhlComptable.accounting.can_manage_asset_pools'),
    ('maintenance_control', 'mbhlComptable.accounting.can_view_maintenance_costs'),
    ('maintenance_control', 'mbhlCore.administration.can_manage_aircraft'),
    ('maintenance_control', 'mbhlCore.administration.can_manage_bases'),
    ('maintenance_control', 'mbhlCore.administration.can_manage_companies'),
    ('maintenance_control', 'mbhlCore.administration.can_manage_personnel'),
    ('maintenance_control', 'mbhlCore.administration.can_manage_permissions'),
    ('maintenance_control', 'mbhlCore.administration.can_manage_currencies'),
    ('maintenance_control', 'mbhlCore.administration.can_view_reliability'),

    -- gestionnaire_maintenance
    ('gestionnaire_maintenance', 'mbhlMaintenance.work_orders.can_view_wo'),
    ('gestionnaire_maintenance', 'mbhlMaintenance.work_orders.can_open_wo'),
    ('gestionnaire_maintenance', 'mbhlMaintenance.work_orders.can_stage_wo'),
    ('gestionnaire_maintenance', 'mbhlMaintenance.inspections.can_view_inspections'),
    ('gestionnaire_maintenance', 'mbhlMaintenance.inspections.can_create_inspection'),
    ('gestionnaire_maintenance', 'mbhlMaintenance.inspections.can_edit_inspection'),
    ('gestionnaire_maintenance', 'mbhlMaintenance.inspections.can_approve_extension'),
    ('gestionnaire_maintenance', 'mbhlMaintenance.inspections.can_manage_packages'),
    ('gestionnaire_maintenance', 'mbhlMagasin.inventory.can_view_inventory'),
    ('gestionnaire_maintenance', 'mbhlMagasin.inventory.can_view_costs'),
    ('gestionnaire_maintenance', 'mbhlMagasin.orders.can_create_rfq'),
    ('gestionnaire_maintenance', 'mbhlMagasin.orders.can_create_order'),
    ('gestionnaire_maintenance', 'mbhlMagasin.orders.can_send_order'),
    ('gestionnaire_maintenance', 'mbhlMagasin.inventory.can_adjust_inventory'),
    ('gestionnaire_maintenance', 'mbhlMagasin.inventory.can_manage_catalog'),
    ('gestionnaire_maintenance', 'mbhlComptable.accounting.can_view_acct_reports'),
    ('gestionnaire_maintenance', 'mbhlComptable.accounting.can_approve_invoice'),
    ('gestionnaire_maintenance', 'mbhlComptable.accounting.can_import_sage'),
    ('gestionnaire_maintenance', 'mbhlComptable.accounting.can_reconcile'),
    ('gestionnaire_maintenance', 'mbhlComptable.accounting.can_manage_asset_pools'),
    ('gestionnaire_maintenance', 'mbhlComptable.accounting.can_view_maintenance_costs'),
    ('gestionnaire_maintenance', 'mbhlCore.administration.can_manage_aircraft'),
    ('gestionnaire_maintenance', 'mbhlCore.administration.can_manage_bases'),
    ('gestionnaire_maintenance', 'mbhlCore.administration.can_manage_companies'),
    ('gestionnaire_maintenance', 'mbhlCore.administration.can_manage_personnel'),
    ('gestionnaire_maintenance', 'mbhlCore.administration.can_manage_permissions'),
    ('gestionnaire_maintenance', 'mbhlCore.administration.can_manage_currencies'),
    ('gestionnaire_maintenance', 'mbhlCore.administration.can_view_reliability'),

    -- magasinier_l1
    ('magasinier_l1', 'mbhlMagasin.inventory.can_view_inventory'),
    ('magasinier_l1', 'mbhlMagasin.inventory.can_view_costs'),
    ('magasinier_l1', 'mbhlMagasin.orders.can_create_rfq'),
    ('magasinier_l1', 'mbhlMagasin.orders.can_receive_order'),

    -- magasinier_l2
    ('magasinier_l2', 'mbhlMagasin.inventory.can_view_inventory'),
    ('magasinier_l2', 'mbhlMagasin.inventory.can_view_costs'),
    ('magasinier_l2', 'mbhlMagasin.orders.can_create_rfq'),
    ('magasinier_l2', 'mbhlMagasin.orders.can_create_order'),
    ('magasinier_l2', 'mbhlMagasin.orders.can_send_order'),
    ('magasinier_l2', 'mbhlMagasin.orders.can_receive_order'),
    ('magasinier_l2', 'mbhlMagasin.inventory.can_adjust_inventory'),
    ('magasinier_l2', 'mbhlMagasin.inventory.can_manage_catalog'),
    ('magasinier_l2', 'mbhlComptable.accounting.can_approve_invoice'),
    ('magasinier_l2', 'mbhlCore.administration.can_manage_companies'),

    -- flight_tech_dispatcher
    ('flight_tech_dispatcher', 'mbhlMaintenance.inspections.can_view_inspections'),
    ('flight_tech_dispatcher', 'mbhlMaintenance.inspections.can_approve_extension')

) AS p(group_name, permission_key) ON g.group_name = p.group_name
ON CONFLICT (group_id, permission_key) DO NOTHING;
